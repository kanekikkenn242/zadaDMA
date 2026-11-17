#import "MotorBridge.h"
#import "ContainerAccess.h"
#import "PatchTransaction.h"
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
    [ContainerAccess note:[NSString stringWithFormat:@"mb:apply %@", patchName]];
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
    [PatchTransaction resetResolvedTargets];

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
    return @{@"patched": patched, @"errors": diagnostics,
             @"paths": [PatchTransaction lastResolvedTargets] ?: @[]};
}

+ (NSDictionary<NSString *, id> *)restorePatchFile:(NSString *)patchName
                                         bundleIDs:(NSArray<NSString *> *)bundleIDs {
    [ContainerAccess note:[NSString stringWithFormat:@"mb:restore %@", patchName]];
    NSString *path = [[NSBundle mainBundle] pathForResource:patchName ofType:@"3105"];
    if (!path) {
        return @{@"restored": @[], @"errors": @[],
                 @"error": [NSString stringWithFormat:@"Skedari %@.3105 mungon në app.", patchName]};
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&readError];
    if (!data.length) {
        return @{@"restored": @[], @"errors": @[],
                 @"error": [NSString stringWithFormat:@"%@.3105 nuk lexohet: %@", patchName,
                            readError.localizedDescription ?: @"e panjohur"]};
    }

    NSError *decodeError = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data
                                           passphrase:@"shared-server-secret"
                                                error:&decodeError];
    if (!pkg) {
        return @{@"restored": @[], @"errors": @[],
                 @"error": [NSString stringWithFormat:@"%@.3105 nuk dekodohet: %@", patchName,
                            decodeError.localizedDescription ?: @"format i pavlefshëm"]};
    }

    NSArray<NSString *> *groups = [PatchTransaction groupsForPackage:pkg];
    if (groups.count == 0) {
        return @{@"restored": @[], @"errors": @[], @"groups": @[],
                 @"error": [NSString stringWithFormat:
                            @"%@.3105 nuk ka destinacione të lexueshme.", patchName]};
    }

    NSMutableArray<NSString *> *restored = [NSMutableArray array];
    NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];

    for (NSString *bundleID in bundleIDs) {
        BOOL allGroupsOK = YES;
        for (NSString *group in groups) {
            NSError *restoreError = nil;
            if ([DevicePatchService restoreGroup:group forBundleID:bundleID error:&restoreError]) {
                continue;
            }
            allGroupsOK = NO;
            NSString *message = restoreError.localizedFailureReason
                ?: restoreError.localizedDescription ?: @"kthimi dështoi";
            [diagnostics addObject:[NSString stringWithFormat:@"%@: %@", bundleID, message]];
            for (NSString *detail in restoreError.userInfo[@"ZDMADiagnostics"]) {
                [diagnostics addObject:[NSString stringWithFormat:@"  %@", detail]];
            }
            break;
        }
        if (allGroupsOK) [restored addObject:bundleID];
    }

    if (restored.count == 0) {
        NSString *summary = [NSString stringWithFormat:
                             @"Asnjë kopje origjinale nuk u kthye (%@).",
                             [bundleIDs componentsJoinedByString:@", "]];
        return @{@"restored": @[], @"errors": diagnostics, @"groups": groups,
                 @"error": summary};
    }
    return @{@"restored": restored, @"errors": diagnostics, @"groups": groups};
}

+ (NSArray<NSString *> *)appContainers {
    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    NSArray<NSString *> *mcm = [ContainerAccess enumerateAppContainerIdentifiers:nil];
    if (mcm.count) [identifiers addObjectsFromArray:mcm];

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass && [workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        if ([workspace respondsToSelector:@selector(allInstalledApplications)]) {
            for (id app in [workspace performSelector:@selector(allInstalledApplications)]) {
                if (![app respondsToSelector:@selector(applicationIdentifier)]) continue;
                NSString *bundleID = [app performSelector:@selector(applicationIdentifier)];
                if (bundleID.length) [identifiers addObject:bundleID];
            }
        }
    }
    return identifiers.array;
}

+ (NSArray<NSString *> *)installedFreeFireBundleIDs {
    NSArray<NSString *> *all = @[@"com.dts.freefireth", @"com.dts.freefiremax"];
    NSArray<NSString *> *installed = [self appContainers];
    if (installed.count == 0) return all;

    NSSet<NSString *> *present = [NSSet setWithArray:installed];
    NSMutableArray<NSString *> *matched = [NSMutableArray array];
    for (NSString *bundleID in all) {
        if ([present containsObject:bundleID]) [matched addObject:bundleID];
    }
    // The sandbox can hide LaunchServices data; only trust the intersection
    // when it actually names a Free Fire variant.
    return matched.count ? matched : all;
}

+ (BOOL)applyPatch:(NSString *)patchName {
    NSDictionary *result = [self applyPatchFile:patchName
                                      bundleIDs:[self installedFreeFireBundleIDs]];
    return [(NSArray *)result[@"patched"] count] > 0;
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    return [DevicePatchService containerPathForBundleID:bundleID] ?: @"";
}

+ (void)resetInjectionTrace {
    [ContainerAccess resetTrace];
}

+ (NSString *)injectionTrace {
    return [ContainerAccess traceTail];
}

@end
