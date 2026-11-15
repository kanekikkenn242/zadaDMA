#import "AntiTamper.h"
#import <sys/sysctl.h>
#import <sys/types.h>
extern int zdma_sha256(const uint8_t *, size_t, uint8_t *);
static NSString *SHA256File(NSString *p){
    NSData *d=[NSData dataWithContentsOfFile:p options:0 error:nil]; if(!d) return @"";
    uint8_t o[32]; zdma_sha256(d.bytes,d.length,o);
    static const char*h="0123456789abcdef"; NSMutableString*s=[NSMutableString stringWithCapacity:64];
    for(int i=0;i<32;i++)[s appendFormat:@"%c%c",h[o[i]>>4],h[o[i]&15]]; return s;
}
@implementation AntiTamper
+ (BOOL)isSimulator {
#if TARGET_OS_SIMULATOR
    return YES;
#else
    return NO;
#endif
}
+ (BOOL)isDebuggerAttached {
    int mib[4]={CTL_KERN,KERN_PROC,KERN_PROC_PID,getpid()};
    struct kinfo_proc info; size_t sz=sizeof info;
    if(sysctl(mib,4,NULL,&sz,NULL,0)!=0) return NO;
    if(sysctl(mib,4,&info,&sz,NULL,0)!=0) return NO;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}
+ (NSString *)sha256OfFile:(NSString *)path { return SHA256File(path); }
+ (BOOL)verifyAndBlockIfNeeded:(NSError **)err {
    NSBundle *b=[NSBundle mainBundle];
    NSString *bid  = b.bundleIdentifier ?: @"";
    NSString *exec = b.executablePath.lastPathComponent ?: @"";
    NSString *disp = [b objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"";
    NSString *ver  = [b objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *build= [b objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    NSString *wantBID=@"com.apple.mobile.MobileHouseArrest";
    NSString *wantExec=@"zadaDMA";
    NSString *wantDisp=@"zadaDMA";
    NSString *wantVer=@"5.2.0";
    NSString *wantBuild=@"124";
    NSMutableArray *fail=[NSMutableArray array];
    if(![bid isEqualToString:wantBID]) [fail addObject:@"bundle_id"];
    if(![exec isEqualToString:wantExec]) [fail addObject:@"exec_name"];
    if(![disp isEqualToString:wantDisp]) [fail addObject:@"display_name"];
    if(![ver isEqualToString:wantVer]) [fail addObject:@"version"];
    if(![build isEqualToString:wantBuild]) [fail addObject:@"build"];
    if([self isSimulator]) [fail addObject:@"simulator"];
    if([self isDebuggerAttached]) [fail addObject:@"debugger"];
    NSDictionary *wav=@{
        @"Welcome.wav":@"571cea7fd9eec0b53e4c26b93ee5db9e41bda8916c50ae6317d94832d25b42d4",
        @"activar.wav":@"19650380eeb8a9f3a5dda148eb8694bd65558cbbb7fe89a53673b5a4909e4db2",
        @"desactivar.wav":@"0aa8dd3756a36e19b99a5a3d2b65e4bbb92137f6aaf2e8166336236b26b67295",
    };
    for(NSString *k in wav){
        NSString *p=[b pathForResource:k.stringByDeletingPathExtension ofType:k.pathExtension];
        if(!p || ![SHA256File(p) isEqualToString:wav[k]]) [fail addObject:k];
    }
    if(fail.count){ if(err)*err=[NSError errorWithDomain:@"anti" code:1 userInfo:@{NSLocalizedDescriptionKey:[fail componentsJoinedByString:@","]}]; return NO; }
    return YES;
}
@end
