#import "MotorBridge.h"
#import "SandboxEscape.h"

@implementation MotorBridge

+ (BOOL)bootstrap {
    // Ne iOS 27 kfd nuk punon, prandaj kthejme NO qe te kaloje te Airlift
    NSLog(@"[MotorBridge] Kernel Exploit nuk suportohet ne iOS 27. Duke kaluar te Airlift.");
    return NO;
}

+ (void)ensureSandbox:(void(^)(BOOL ok, NSError * _Nullable err))done {
    BOOL ok = escape_sandbox_bad_query(@"com.dts.freefireth");
    done(ok, nil);
}

+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID {
    NSError *err = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data passphrase:pass error:&err];
    if (!pkg) {
        NSLog(@"[MotorBridge] Decode failed: %@", err.localizedDescription);
        return NO;
    }
    BOOL ok = [DevicePatchService applyPatch:pkg toBundleID:bundleID error:&err];
    if (!ok && err) {
        NSLog(@"[MotorBridge] Apply failed: %@", err.localizedDescription);
    }
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

+ (BOOL)applyPatch:(NSString *)patchName {
    NSString *path = [[NSBundle mainBundle] pathForResource:patchName ofType:@"3105"];
    if (!path) return NO;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return NO;
    return [self applyPackageData:data passphrase:@"shared-server-secret" bundleID:@"com.dts.freefireth"];
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    Class ws = NSClassFromString(@"LSApplicationWorkspace");
    if (!ws) return @"";
    id workspace = [ws performSelector:@selector(defaultWorkspace)];
    for (id app in [workspace performSelector:@selector(allInstalledApplications)]) {
        NSString *bid = [app performSelector:@selector(applicationIdentifier)];
        if ([bid isEqualToString:bundleID]) {
            NSURL *url = [app performSelector:@selector(dataContainerURL)];
            if (!url) url = [app performSelector:@selector(bundleContainerURL)];
            if (url) return url.path;
        }
    }
    return @"";
}

@end
