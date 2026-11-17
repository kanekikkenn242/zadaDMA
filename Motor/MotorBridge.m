#import "MotorBridge.h"
#import "ContainerAccess.h"
#import "SandboxEscape.h"
#import <dlfcn.h>

@implementation MotorBridge

+ (BOOL)bootstrap {
    // kfd nuk suportohet ne iOS 27; kontenjeret zgjidhen me MCM lease.
    return NO;
}

+ (void)ensureSandbox:(void(^)(BOOL ok, NSError * _Nullable err))done {
    NSError *error = nil;
    BOOL ok = [ContainerAccess grantAccessToPath:
               [self containerPathForBundleID:@"com.dts.freefireth"] error:&error];
    done(ok, error);
}

+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID {
    NSError *err = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data passphrase:pass error:&err];
    if (!pkg) return NO;
    return [DevicePatchService applyPatch:pkg toBundleID:bundleID error:&err];
}

+ (NSDictionary<NSString *, id> *)applyPatchFile:(NSString *)patchName
                                       bundleIDs:(NSArray<NSString *> *)bundleIDs {
    NSString *path = [[NSBundle mainBundle] pathForResource:patchName ofType:@"3105"];
    if (!path) {
        return @{@"patched": @[], @"errors": @[],
                 @"error": [NSString stringWithFormat:@"Skedari %@.3105 mungon në app.", patchName]};
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&readError];
    if (!data.length) {
        return @{@"patched": @[], @"errors": @[],
                 @"error": [NSString stringWithFormat:@"%@.3105 nuk lexohet: %@", patchName,
                            readError.localizedDescription ?: @"e panjohur"]};
    }

    NSError *decodeError = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data
                                           passphrase:@"shared-server-secret"
                                                error:&decodeError];
    if (!pkg) {
        return @{@"patched": @[], @"errors": @[],
                 @"error": [NSString stringWithFormat:@"%@.3105 nuk dekodohet: %@", patchName,
                            decodeError.localizedDescription ?: @"format i pavlefshëm"]};
    }

    NSMutableArray<NSString *> *patched = [NSMutableArray array];
    NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];

    for (NSString *bundleID in bundleIDs) {
        NSError *patchError = nil;
        if ([DevicePatchService applyPatch:pkg toBundleID:bundleID error:&patchError]) {
            [patched addObject:bundleID];
            continue;
        }
        NSString *message = patchError.localizedDescription ?: @"injektimi dështoi";
        [diagnostics addObject:[NSString stringWithFormat:@"%@: %@", bundleID, message]];
        NSArray<NSString *> *details = patchError.userInfo[@"ZDMADiagnostics"];
        for (NSString *detail in details) {
            [diagnostics addObject:[NSString stringWithFormat:@"  %@", detail]];
        }
    }

    if (patched.count == 0) {
        NSString *summary = [NSString stringWithFormat:
                             @"Asnjë lojë nuk u patch-ua (%@).",
                             [bundleIDs componentsJoinedByString:@", "]];
        return @{@"patched": @[], @"errors": diagnostics, @"error": summary};
    }
    return @{@"patched": patched, @"errors": diagnostics};
}

+ (NSArray<NSString *> *)appContainers {
    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    NSArray<NSString *> *mcm = [ContainerAccess enumerateAppContainerIdentifiers:nil];
    if (mcm.count) [identifiers addObjectsFromArray:mcm];

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        for (id app in [workspace performSelector:@selector(allInstalledApplications)]) {
            NSString *bundleID = [app performSelector:@selector(applicationIdentifier)];
            if (bundleID.length) [identifiers addObject:bundleID];
        }
    }
    return identifiers.array;
}

+ (BOOL)applyPatch:(NSString *)patchName {
    NSDictionary *result = [self applyPatchFile:patchName
                                      bundleIDs:@[@"com.dts.freefireth", @"com.dts.freefiremax"]];
    return [(NSArray *)result[@"patched"] count] > 0;
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    return [DevicePatchService containerPathForBundleID:bundleID] ?: @"";
}

@end
