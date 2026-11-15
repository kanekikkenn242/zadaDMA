#import "MotorBridge.h"
@implementation MotorBridge
+ (BOOL)bootstrapWithError:(NSError **)err { return [AntiTamper verifyAndBlockIfNeeded:err]; }
+ (void)ensureSandbox:(void(^)(BOOL,NSError*))done {
    [[ExploitBootstrap shared] ensureSandboxForBundleID:@"com.dts.freefireth" completion:done];
}
+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID error:(NSError **)err {
    PatchPackage *pkg=[PatchPackageCodec decodeData:data passphrase:pass error:err];
    if(!pkg) return NO;
    return [DevicePatchService applyPatch:pkg toBundleID:bundleID error:err];
}
+ (NSArray<NSString *> *)appContainers {
    Class ws=NSClassFromString(@"LSApplicationWorkspace"); if(!ws) return @[];
    id workspace=[ws performSelector:@selector(defaultWorkspace)];
    NSMutableArray *out=[NSMutableArray array];
    for(id app in [workspace performSelector:@selector(allInstalledApplications)]){
        NSString *bid=[app performSelector:@selector(applicationIdentifier)];
        if(bid)[out addObject:bid];
    }
    return out;
}
@end
