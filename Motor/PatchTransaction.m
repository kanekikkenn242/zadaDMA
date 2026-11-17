#import "PatchTransaction.h"
#import "PatchPackageCodec.h"
#import "ContainerAccess.h"
#import "AirliftBridge.h"
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

// Free Fire names downloaded bundles by the URL-escaped Base64 of their gzip
// SHA-1 (`+` -> ~2B, `/` -> ~2F, `=` -> ~3D), so the leaf changes with every
// game version. Packages use `{gz}` as a placeholder and the fallback name is
// resolved at runtime from `Data/Raw/ios/fileinfo`.
static NSString *EscapeGzHash(NSString *hash) {
    NSMutableString *s = [hash mutableCopy];
    [s replaceOccurrencesOfString:@"+" withString:@"~2B" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"/" withString:@"~2F" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"=" withString:@"~3D" options:0 range:NSMakeRange(0, s.length)];
    return s;
}

// fileinfo line: key,rawSHA1B64,rawSize,0,gzSHA1B64,gzSize,True,0
static NSString *GzHashForKey(NSData *fileinfo, NSString *key) {
    if (!fileinfo.length || !key.length) return nil;
    NSString *text = [[NSString alloc] initWithData:fileinfo encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:fileinfo encoding:NSISOLatin1StringEncoding];
    if (!text) return nil;
    for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if (!line.length) continue;
        NSArray<NSString *> *fields = [line componentsSeparatedByString:@","];
        if (fields.count < 5) continue;
        if (![fields[0] isEqualToString:key]) continue;
        NSString *gz = fields[4];
        if (gz.length) return EscapeGzHash(gz);
    }
    return nil;
}

// Resolve a `.../gameassetbundles/<key>.{gz}` destination against fileinfo.
static NSString *ResolveGzDestination(NSString *dst, NSData *fileinfo) {
    NSRange marker = [dst rangeOfString:@"{gz}"];
    if (marker.location == NSNotFound) return dst;
    if (marker.location + marker.length != dst.length) return nil;

    NSString *stem = [dst substringToIndex:marker.location];
    static NSString *const prefix = @"Data/Raw/ios/gameassetbundles/";
    if (![stem hasSuffix:@"."] || ![stem hasPrefix:prefix]) return nil;
    stem = [stem substringToIndex:stem.length - 1];
    NSString *key = [stem substringFromIndex:prefix.length];
    NSString *gz = GzHashForKey(fileinfo, key);
    if (!gz.length) return nil;
    return [stem stringByAppendingFormat:@".%@", gz];
}

static NSData *LoadFileinfo(NSString *container, NSString *bundlePath) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    if (bundlePath.length) {
        [paths addObject:[bundlePath stringByAppendingPathComponent:@"Data/Raw/ios/fileinfo"]];
    }
    [paths addObject:[[container stringByAppendingPathComponent:@"Documents"]
                      stringByAppendingPathComponent:@"Data/Raw/ios/fileinfo"]];
    [paths addObject:[container stringByAppendingPathComponent:@"Data/Raw/ios/fileinfo"]];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (![fm isReadableFileAtPath:path]) continue;
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data.length) {
            [ContainerAccess note:[NSString stringWithFormat:@"fileinfo:local %@ (%lu B)",
                                   path, (unsigned long)data.length]];
            return data;
        }
    }

    // Not readable from the sandbox: export it through AirTraffic.
    for (NSString *path in paths) {
        NSError *readError = nil;
        NSData *data = [AirliftBridge readFileAtPath:path
                                                 log:^(NSString *line) {
            [ContainerAccess note:[NSString stringWithFormat:@"airlift-fileinfo: %@", line]];
        }
                                               error:&readError];
        if (data.length) {
            [ContainerAccess note:[NSString stringWithFormat:@"fileinfo:airlift %@ (%lu B)",
                                   path, (unsigned long)data.length]];
            return data;
        }
        if (readError) {
            [ContainerAccess note:[NSString stringWithFormat:@"fileinfo:airlift-failed %@: %@",
                                   path, readError.localizedFailureReason ?: readError.localizedDescription]];
        }
    }
    return nil;
}

static BOOL RejectSymlink(NSString *root, NSString *dst) {    NSFileManager *fm=[NSFileManager defaultManager]; 
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

NSString *const PatchTransactionAirliftContainerKey = @"zadaDMA.airlift.container";

@implementation PatchLedgerEntry @end

static NSMutableArray<NSString *> *gLastResolvedTargets;

@implementation PatchTransaction
+ (NSArray<NSString *> *)lastResolvedTargets {
    return gLastResolvedTargets ? [gLastResolvedTargets copy] : @[];
}
+ (void)resetResolvedTargets {
    gLastResolvedTargets = [NSMutableArray array];
}
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

    // `{gz}` leaves are version-dependent and resolved from the device's own
    // fileinfo through Airlift; the MCM path has no reader for it.
    for (NSDictionary *r in pkg.rules) {
        NSString *dst = r[@"dst"];
        if ([dst isKindOfClass:[NSString class]] && [dst containsString:@"{gz}"]) {
            [ContainerAccess note:@"tx:mcm-skip-gz"];
            if (err) *err = [NSError errorWithDomain:@"patch" code:ENOTSUP userInfo:@{
                NSLocalizedDescriptionKey: @"paketa kërkon fileinfo (Airlift)"}];
            return NO;
        }
    }
    
    uint64_t total=0; 
    NSMutableArray<NSDictionary*> *plan=[NSMutableArray array];
    if(!gLastResolvedTargets) gLastResolvedTargets=[NSMutableArray array];
    for(NSDictionary *r in pkg.rules){
        NSString *src=r[@"src"], *dst=r[@"dst"];
        if(!src||!dst){ if(err)*err=[NSError errorWithDomain:@"patch" code:EINVAL userInfo:nil]; return NO; }
        NSString *full=ResolveTarget(container,dst);
        [ContainerAccess note:[NSString stringWithFormat:@"tx:target %@", full]];
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
            [ContainerAccess note:@"tx:backup"];
            if(![fm copyItemAtPath:dst toPath:backup error:err]){ [self rollback:entries]; return NO; }
        }
        NSString *parent=[dst stringByDeletingLastPathComponent];
        if(![fm fileExistsAtPath:parent]){
            [ContainerAccess note:@"tx:mkdir"];
            if(![fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:err]){
                if(backup)[fm removeItemAtPath:backup error:nil]; [self rollback:entries]; return NO; 
            }
        }
        [ContainerAccess note:@"tx:writing"];
        if(![blob writeToFile:dst options:NSDataWritingAtomic error:err]){
            if(backup)[fm removeItemAtPath:backup error:nil]; [self rollback:entries]; return NO; 
        }
        
        [ContainerAccess note:@"tx:written"];
        NSData *got=[NSData dataWithContentsOfFile:dst options:0 error:nil];
        if(!got || ![SHA256Hex(got) isEqualToString:dig]){
            if(err)*err=[NSError errorWithDomain:@"patch" code:EIO userInfo:@{NSLocalizedDescriptionKey:@"readback digest"}];
            [fm removeItemAtPath:dst error:nil];
            if(backup)[fm moveItemAtPath:backup toPath:dst error:nil];
            [self rollback:entries]; return NO;
        }
        [entries addObject:@{@"dst":dst,@"backup":backup?:[NSNull null],@"sha256":dig,@"ok":@YES}];
        [gLastResolvedTargets addObject:dst];
        [ContainerAccess note:@"tx:verified"];
    }
    ledger.entries=entries; [self appendLedger:ledger]; return YES;
}

+ (BOOL)applyPackage:(PatchPackage *)pkg viaAirliftToContainer:(NSString *)container bundleID:(NSString *)bundleID error:(NSError **)err {
    if (container.length == 0) {
        if (err) *err = [NSError errorWithDomain:@"patch" code:EINVAL
                                           userInfo:@{NSLocalizedDescriptionKey: @"container i Airlift mungon"}];
        return NO;
    }

    // The shipped asset tree lives inside the installed `.app` bundle. Unity's
    // streamingAssetsPath on iOS resolves to `<App>.app/Data/Raw`, which is the
    // root the game reads without consulting any hot-update manifest.
    NSError *bundleLookupError = nil;
    NSString *bundlePath = [AirliftBridge bundlePathForBundleID:bundleID
                                                            log:^(NSString *line) {
        [ContainerAccess note:[NSString stringWithFormat:@"airlift-bundle: %@", line]];
    }
                                                          error:&bundleLookupError];
    if (bundlePath.length) {
        [ContainerAccess note:[NSString stringWithFormat:@"tx:bundle %@", bundlePath]];
    } else if (bundleLookupError) {
        [ContainerAccess note:[NSString stringWithFormat:@"tx:bundle-failed %@",
                               bundleLookupError.localizedFailureReason ?: bundleLookupError.localizedDescription]];
    }

    // Group by remote parent directory: al_exploit_write_dir writes a flat set
    // of files into one target directory, one AirTraffic sync per directory.
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSData *> *> *groups = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    if (!gLastResolvedTargets) gLastResolvedTargets = [NSMutableArray array];

    NSData *fileinfo = nil;
    BOOL fileinfoAttempted = NO;

    for (NSDictionary *r in pkg.rules) {
        NSString *src = r[@"src"], *dst = r[@"dst"];
        if (![src isKindOfClass:[NSString class]] || ![dst isKindOfClass:[NSString class]]) {
            if (err) *err = [NSError errorWithDomain:@"patch" code:EINVAL userInfo:nil];
            return NO;
        }
        if ([dst containsString:@"{gz}"]) {
            if (!fileinfoAttempted) {
                fileinfoAttempted = YES;
                fileinfo = LoadFileinfo(container, bundlePath);
                [ContainerAccess note:[NSString stringWithFormat:@"fileinfo:%@",
                                       fileinfo.length ? @"loaded" : @"missing"]];
            }
            NSString *resolved = ResolveGzDestination(dst, fileinfo);
            if (!resolved.length) {
                if (err) *err = [NSError errorWithDomain:@"patch" code:ENOENT userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"fileinfo nuk e zgjidhi dot %@", dst]}];
                return NO;
            }
            [ContainerAccess note:[NSString stringWithFormat:@"tx:gz %@ -> %@", dst, resolved]];
            dst = resolved;
        }
        NSData *blob = pkg.files[src];
        if (!blob.length) {
            if (err) *err = [NSError errorWithDomain:@"patch" code:ENOENT userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"missing %@", src]}];
            return NO;
        }
        NSString *want = pkg.digests[src];
        if (want && ![SHA256Hex(blob) isEqualToString:want]) {
            if (err) *err = [NSError errorWithDomain:@"patch" code:EINVAL
                                               userInfo:@{NSLocalizedDescriptionKey: @"pkg digest"}];
            return NO;
        }

        NSString *rel = [dst stringByStandardizingPath];
        while ([rel hasPrefix:@"/"]) rel = [rel substringFromIndex:1];
        if ([rel hasPrefix:@".."]) {
            if (err) *err = [NSError errorWithDomain:@"patch" code:EPERM
                                               userInfo:@{NSLocalizedDescriptionKey: @"path traversal"}];
            return NO;
        }
        // `.3105` paths are relative to the game data-container root, which is
        // exactly what the reference app resolves. A Documents fallback is
        // attempted below when the root write fails.
        NSString *remote = [container stringByAppendingPathComponent:rel];

        NSString *parent = [remote stringByDeletingLastPathComponent];
        NSString *leaf = [remote lastPathComponent];
        if (parent.length == 0 || leaf.length == 0) {
            if (err) *err = [NSError errorWithDomain:@"patch" code:EINVAL
                                               userInfo:@{NSLocalizedDescriptionKey: @"empty target"}];
            return NO;
        }
        NSMutableDictionary<NSString *, NSData *> *files = groups[parent];
        if (!files) {
            files = [NSMutableDictionary dictionary];
            groups[parent] = files;
        }
        files[leaf] = blob;
    }

    for (NSString *targetDirectory in groups) {
        NSDictionary<NSString *, NSData *> *files = groups[targetDirectory];

        // Free Fire keeps its hot-updated asset tree under <container>/Documents,
        // while the reference app resolves `.3105` paths from the data-container
        // root. Write to both so the game sees the patch on either layout.
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        NSString *rel = targetDirectory;
        if ([rel hasPrefix:container]) rel = [rel substringFromIndex:container.length];
        while ([rel hasPrefix:@"/"]) rel = [rel substringFromIndex:1];

        // Patch the shipped app-bundle copy first: the loader reads it through
        // streamingAssetsPath without checking any hot-update manifest.
        if (bundlePath.length) {
            [candidates addObject:[bundlePath stringByAppendingPathComponent:rel]];
        }

        // Hot-update overrides. Free Fire stores downloaded resources under
        // `<Documents>/streaming` and `<Documents>/optionallocres`, relative to
        // `Data/Raw/ios`, so mirror the file there as well.
        NSString *hotRel = rel;
        for (NSString *prefix in @[@"Data/Raw/ios/", @"Data/Raw/"]) {
            if ([hotRel hasPrefix:prefix]) {
                hotRel = [hotRel substringFromIndex:prefix.length];
                break;
            }
        }
        if (![hotRel isEqualToString:rel]) {
            [candidates addObject:[[container stringByAppendingPathComponent:@"Documents/streaming"]
                                   stringByAppendingPathComponent:hotRel]];
            [candidates addObject:[[container stringByAppendingPathComponent:@"Documents/optionallocres"]
                                   stringByAppendingPathComponent:hotRel]];
        }

        if (![rel hasPrefix:@"Documents/"] && ![rel hasPrefix:@"Library/"] && ![rel hasPrefix:@"tmp/"]) {
            NSString *documents = [[container stringByAppendingPathComponent:@"Documents"]
                                   stringByAppendingPathComponent:rel];
            if (documents.length) [candidates addObject:documents];
        }
        if (![candidates containsObject:targetDirectory]) {
            [candidates addObject:targetDirectory];
        }

        // Do not gate writes on a probe: a probe is a separate AirTraffic sync
        // and a transient probe failure must not hide the working root. Try
        // every candidate and keep whichever writes actually land.
        NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];
        NSError *lastError = nil;
        NSMutableArray<NSString *> *written = [NSMutableArray array];
        for (NSString *candidate in candidates) {
            [ContainerAccess note:[NSString stringWithFormat:@"tx:airlift %@", candidate]];
            NSError *writeError = nil;
            BOOL ok = [AirliftBridge writeFiles:files
                              toTargetDirectory:candidate
                                            log:^(NSString *line) {
                [ContainerAccess note:[NSString stringWithFormat:@"airlift: %@", line]];
            }
                                          error:&writeError];
            if (ok) {
                [written addObject:candidate];
                [ContainerAccess note:[NSString stringWithFormat:@"tx:airlift-ok %@", candidate]];
                continue;
            }
            lastError = writeError;
            NSString *reason = writeError.localizedFailureReason ?: writeError.localizedDescription;
            if (reason.length) {
                [diagnostics addObject:[NSString stringWithFormat:@"Airlift %@: %@", candidate, reason]];
            }
            for (NSString *line in writeError.userInfo[@"ZDMADiagnostics"]) {
                [diagnostics addObject:[NSString stringWithFormat:@"Airlift: %@", line]];
            }
            [ContainerAccess note:@"tx:airlift-failed"];
        }

        if (written.count == 0) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            info[NSLocalizedDescriptionKey] = @"Airlift write dështoi.";
            NSString *reason = lastError.localizedFailureReason ?: lastError.localizedDescription;
            if (reason.length) info[NSLocalizedFailureReasonErrorKey] = reason;
            if (diagnostics.count) info[@"ZDMADiagnostics"] = diagnostics;
            if (err) *err = [NSError errorWithDomain:@"patch" code:EIO userInfo:info];
            return NO;
        }

        for (NSString *dir in written) {
            for (NSString *leaf in files) {
                NSString *full = [dir stringByAppendingPathComponent:leaf];
                [gLastResolvedTargets addObject:full];
                [entries addObject:@{@"dst": full, @"backup": [NSNull null],
                                     @"sha256": SHA256Hex(files[leaf]), @"ok": @YES,
                                     @"via": @"airlift"}];
            }
        }
        [ContainerAccess note:@"tx:airlift-ok"];
    }

    PatchLedgerEntry *ledger = [PatchLedgerEntry new];
    ledger.bundleID = bundleID;
    ledger.containerPath = container;
    ledger.at = [NSDate date];
    ledger.entries = entries;

    [self appendLedger:ledger];
    return YES;
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
