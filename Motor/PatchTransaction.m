#import "PatchTransaction.h"
#import "PatchPackageCodec.h"
#include <sys/statvfs.h>
#include <sys/stat.h>
#include <stdint.h>
#include <string.h>

extern int zdma_sha256(const uint8_t *, size_t, uint8_t *);

static NSString *SHA256Hex(NSData *d) { 
    uint8_t o[32]; 
    zdma_sha256(d.bytes, d.length, o);
    static const char*h="0123456789abcdef"; 
    NSMutableString*s=[NSMutableString stringWithCapacity:64];
    for(int i=0;i<32;i++)[s appendFormat:@"%c%c",h[o[i]>>4],h[o[i]&15]]; 
    return s; 
}

static BOOL UnderRoot(NSString *r, NSString *p) {
    NSString *c=[p stringByStandardizingPath]; 
    NSString *rr=[r stringByStandardizingPath];
    return [c isEqualToString:rr] || [c hasPrefix:[rr stringByAppendingString:@"/"]];
}

static BOOL IsDirectory(NSString *path) {
    BOOL isDir = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir;
}

// `.3105` rules carry paths relative to the *game's* data root, e.g.
// `Data/Raw/ios/...`. Free Fire keeps that tree inside `Documents`, while the
// MobileContainerManager lease returns the data-container root. Resolve the
// base from the filesystem so the write lands where the game reads it:
//   <container>/Documents/Data/...   (Free Fire, ATC/House Arrest view)
//   <container>/Library/...          (container-root packages)
static NSString *ResolveTarget(NSString *container, NSString *dst) {
    NSString *rel = [dst stringByStandardizingPath];
    while ([rel hasPrefix:@"/"]) rel = [rel substringFromIndex:1];
    NSString *documents = [container stringByAppendingPathComponent:@"Documents"];
    NSString *first = [rel pathComponents].firstObject ?: @"";

    if (![rel hasPrefix:@"Documents/"] && IsDirectory([documents stringByAppendingPathComponent:first])) {
        return [documents stringByAppendingPathComponent:rel];
    }
    if (IsDirectory([container stringByAppendingPathComponent:first])) {
        return [container stringByAppendingPathComponent:rel];
    }
    NSString *documentCandidate = [documents stringByAppendingPathComponent:rel];
    if (![rel hasPrefix:@"Documents/"] &&
        [[NSFileManager defaultManager] fileExistsAtPath:documentCandidate]) {
        return documentCandidate;
    }
    NSString *rootCandidate = [container stringByAppendingPathComponent:rel];
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootCandidate]) {
        return rootCandidate;
    }
    // Nothing exists yet: game asset trees live under Documents.
    if ([first isEqualToString:@"Data"] && ![rel hasPrefix:@"Documents/"]) {
        return documentCandidate;
    }
    return rootCandidate;
}

static BOOL RejectSymlink(NSString *root, NSString *dst) {
    NSFileManager *fm=[NSFileManager defaultManager]; 
    NSString *cur=dst;
    while(cur.length>root.length){
        NSDictionary *a=[fm attributesOfItemAtPath:cur error:nil];
        if(a && [a[NSFileType] isEqual:NSFileTypeSymbolicLink]) return YES;
        cur=[cur stringByDeletingLastPathComponent];
    }
    return NO;
}

static BOOL EnoughSpace(NSString *dir, uint64_t need, NSError **err) {
    struct statvfs v; 
    if(statvfs(dir.fileSystemRepresentation,&v)!=0) return YES;
    uint64_t free=(uint64_t)v.f_bavail * v.f_frsize;
    if(free<need) { 
        if(err)*err=[NSError errorWithDomain:@"patch" code:ENOSPC userInfo:@{NSLocalizedDescriptionKey:@"insufficient disk space"}]; 
        return NO; 
    }
    return YES;
}

@implementation PatchLedgerEntry @end

@implementation PatchTransaction
+ (NSString *)ledgerPath {
    NSArray *p=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);
    NSString *dir=[p.firstObject stringByAppendingPathComponent:@"ThreeOneOSFive"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"ledger.jsonl"];
}

+ (void)appendLedger:(PatchLedgerEntry *)e {
    NSDictionary *d=@{@"bundleID":e.bundleID?:@"",@"container":e.containerPath?:@"",@"entries":e.entries?:@[],@"at":@([[NSDate date] timeIntervalSince1970])};
    NSData *j=[NSJSONSerialization dataWithJSONObject:d options:0 error:nil]; 
    if(!j) return;
    NSMutableData *line=[NSMutableData dataWithData:j]; 
    [line appendBytes:"\n" length:1];
    NSString *p=[self ledgerPath];
    NSFileHandle *fh=[NSFileHandle fileHandleForWritingAtPath:p];
    if(!fh) { 
        [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
        fh=[NSFileHandle fileHandleForWritingAtPath:p]; 
    }
    [fh seekToEndOfFile]; 
    [fh writeData:line]; 
    [fh closeFile];
}

+ (BOOL)applyPackage:(PatchPackage *)pkg container:(NSString *)container bundleID:(NSString *)bundleID error:(NSError **)err {
    NSFileManager *fm=[NSFileManager defaultManager];
    if(![fm fileExistsAtPath:container]) { 
        if(err)*err=[NSError errorWithDomain:@"patch" code:ENOENT userInfo:@{NSLocalizedDescriptionKey:@"container missing"}]; 
        return NO; 
    }
    
    uint64_t total=0; 
    NSMutableArray<NSDictionary*> *plan=[NSMutableArray array];
    for(NSDictionary *r in pkg.rules){
        NSString *src=r[@"src"], *dst=r[@"dst"];
        if(!src||!dst){ if(err)*err=[NSError errorWithDomain:@"patch" code:EINVAL userInfo:nil]; return NO; }
        NSString *full=ResolveTarget(container,dst);
        if(!UnderRoot(container,full)){ if(err)*err=[NSError errorWithDomain:@"patch" code:EPERM userInfo:@{NSLocalizedDescriptionKey:@"path traversal"}]; return NO; }
        if(RejectSymlink(container,full)){ if(err)*err=[NSError errorWithDomain:@"patch" code:EPERM userInfo:@{NSLocalizedDescriptionKey:@"symlink"}]; return NO; }
        NSData *blob=pkg.files[src];
        if(!blob){ if(err)*err=[NSError errorWithDomain:@"patch" code:ENOENT userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"missing %@",src]}]; return NO; }
        NSString *want=pkg.digests[src];
        if(want && ![SHA256Hex(blob) isEqualToString:want]){ if(err)*err=[NSError errorWithDomain:@"patch" code:EINVAL userInfo:@{NSLocalizedDescriptionKey:@"pkg digest"}]; return NO; }
        total+=blob.length+4096;
        [plan addObject:@{@"src":src,@"dst":full,@"blob":blob,@"digest":want?:SHA256Hex(blob)}];
    }
    if(!EnoughSpace(container,total,err)) return NO;
    
    PatchLedgerEntry *ledger=[PatchLedgerEntry new];
    ledger.bundleID=bundleID; ledger.containerPath=container; ledger.at=[NSDate date];
    NSMutableArray *entries=[NSMutableArray array];
    
    for(NSDictionary *p in plan){
        NSString *dst=p[@"dst"]; NSData *blob=p[@"blob"]; NSString *dig=p[@"digest"];
        NSDictionary *a=[fm attributesOfItemAtPath:dst error:nil];
        NSString *backup=nil;
        if(a){
            backup=[dst stringByAppendingFormat:@".3105-displaced-%@",[[NSUUID UUID].UUIDString substringToIndex:8]];
            if(![fm copyItemAtPath:dst toPath:backup error:err]){ [self rollback:entries]; return NO; }
        }
        NSString *parent=[dst stringByDeletingLastPathComponent];
        if(![fm fileExistsAtPath:parent]){
            if(![fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:err]){
                if(backup)[fm removeItemAtPath:backup error:nil]; [self rollback:entries]; return NO; 
            }
        }
        if(![blob writeToFile:dst options:NSDataWritingAtomic error:err]){
            if(backup)[fm removeItemAtPath:backup error:nil]; [self rollback:entries]; return NO; 
        }
        
        NSData *got=[NSData dataWithContentsOfFile:dst options:0 error:nil];
        if(!got || ![SHA256Hex(got) isEqualToString:dig]){
            if(err)*err=[NSError errorWithDomain:@"patch" code:EIO userInfo:@{NSLocalizedDescriptionKey:@"readback digest"}];
            [fm removeItemAtPath:dst error:nil];
            if(backup)[fm moveItemAtPath:backup toPath:dst error:nil];
            [self rollback:entries]; return NO;
        }
        [entries addObject:@{@"dst":dst,@"backup":backup?:[NSNull null],@"sha256":dig,@"ok":@YES}];
    }
    ledger.entries=entries; [self appendLedger:ledger]; return YES;
}

+ (void)rollback:(NSArray<NSDictionary*> *)entries {
    NSFileManager *fm=[NSFileManager defaultManager];
    for(NSDictionary *e in entries.reverseObjectEnumerator){
        NSString *dst=e[@"dst"], *bk=e[@"backup"];
        if(bk==[NSNull null]){ [fm removeItemAtPath:dst error:nil]; continue; }
        [fm removeItemAtPath:dst error:nil]; [fm moveItemAtPath:bk toPath:dst error:nil];
    }
}

+ (BOOL)restoreLedger:(PatchLedgerEntry *)ledger error:(NSError **)err {
    NSFileManager *fm=[NSFileManager defaultManager];
    for(NSDictionary *e in ledger.entries.reverseObjectEnumerator){
        NSString *dst=e[@"dst"], *bk=e[@"backup"];
        if(bk==[NSNull null]){ [fm removeItemAtPath:dst error:nil]; continue; }
        if(![fm fileExistsAtPath:bk]) continue;
        [fm removeItemAtPath:dst error:nil]; [fm moveItemAtPath:bk toPath:dst error:err];
    }
    return YES;
}
@end
