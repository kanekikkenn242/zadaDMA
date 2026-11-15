#import "MotorBridge.h"

@implementation MotorBridge

+ (BOOL)bootstrap {
    NSError *err = nil;
    BOOL ok = [AntiTamper verifyAndBlockIfNeeded:&err];
    if (!ok && err) NSLog(@"[MotorBridge] Anti-tamper failed: %@", err.localizedDescription);
    return ok;
}

+ (void)ensureSandbox:(void(^)(BOOL,NSError*))done {
    [[ExploitBootstrap shared] ensureSandboxForBundleID:@"com.dts.freefireth" completion:done];
}

+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID {
    NSError *err = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data passphrase:pass error:&err];
    if (!pkg) {
        NSLog(@"[MotorBridge] Decode failed: %@", err.localizedDescription);
        return NO;
    }
    BOOL ok = [DevicePatchService applyPatch:pkg toBundleID:bundleID error:&err];
    if (!ok && err) NSLog(@"[MotorBridge] Apply failed: %@", err.localizedDescription);
    return ok;
}

+ (NSArray<NSString *> *)appContainers {
    Class ws = NSClassFromString(@"LSApplicationWorkspace"); 
    if (!ws) return @[];
    id workspace = [ws performSelector:@selector(defaultWorkspace)];
    NSMutableArray *out = [NSMutableArray array];
    for (id app in [workspace performSelector:@selector(allInstalledApplications)]) {
        NSString *bid = [app performSelector:@selector(applicationIdentifier)];
        if (bid) [out addObject:bid];
    }
    return out;
}
@end
