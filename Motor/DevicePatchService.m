#import "DevicePatchService.h"
#import "ContainerAccess.h"
#import "PatchTransaction.h"
#import "PatchPackageCodec.h"
#import "AirliftBridge.h"
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#include <errno.h>

@implementation DevicePatchService

+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    return [self containerPathForBundleID:bundleID error:nil];
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID error:(NSError **)error {
    NSError *containerError = nil;
    NSString *path = [ContainerAccess containerPathForBundleID:bundleID error:&containerError];
    if (path.length) return path;

    if (error) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:
                                           @"Kontejneri i %@ nuk u gjet.", bundleID];
        NSArray<NSString *> *diagnostics = containerError.userInfo[@"ZDMADiagnostics"];
        if (diagnostics.count) {
            info[NSLocalizedFailureReasonErrorKey] = [diagnostics componentsJoinedByString:@" | "];
            info[@"ZDMADiagnostics"] = diagnostics;
        } else if (containerError) {
            info[NSLocalizedFailureReasonErrorKey] =
                containerError.localizedFailureReason ?: containerError.localizedDescription;
        }
        *error = [NSError errorWithDomain:@"zadaDMA.patch" code:ENOENT userInfo:info];
    }
    return nil;
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    __block NSString *path = nil;
    __block NSError *lookupError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        path = [self containerPathForBundleID:bundleID error:&lookupError];
        dispatch_semaphore_signal(semaphore);
    });

    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW,
                                             (int64_t)(timeout * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(semaphore, deadline) != 0) {
        [ContainerAccess note:@"apply:mcm-timeout"];
        if (error) {
            *error = [NSError errorWithDomain:@"zadaDMA.patch" code:ETIMEDOUT userInfo:@{
                NSLocalizedDescriptionKey: @"MCM nuk u përgjigj brenda 6 sekondave."}];
        }
        return nil;
    }
    if (error) *error = lookupError;
    return path;
}

+ (BOOL)applyPatch:(PatchPackage *)pkg toBundleID:(NSString *)bundleID error:(NSError **)err {
    [ContainerAccess note:[NSString stringWithFormat:@"apply:begin %@", bundleID]];

    NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    // 1. Primary path: MobileContainerManager class-2 lease when the host
    //    bundle identifier is honoured by the daemon. A stuck XPC transaction
    //    must not block the Airlift fallback, so cap it at six seconds.
    NSError *containerError = nil;
    NSString *container = [self containerPathForBundleID:bundleID
                                                 timeout:6.0
                                                   error:&containerError];
    if (container.length) {
        [ContainerAccess note:[NSString stringWithFormat:@"apply:container %@", container]];
        NSError *grantError = nil;
        int64_t grant = [ContainerAccess acquireAccessToPath:container error:&grantError];
        [ContainerAccess note:[NSString stringWithFormat:@"apply:grant=%lld", (long long)grant]];

        NSString *localBundle = [ContainerAccess applicationBundlePathForBundleID:bundleID error:nil];
        int64_t bundleGrant = -1;
        if (localBundle.length) {
            [ContainerAccess note:[NSString stringWithFormat:@"apply:local-bundle %@", localBundle]];
            bundleGrant = [ContainerAccess acquireAccessToPath:localBundle error:nil];
            [ContainerAccess note:[NSString stringWithFormat:@"apply:bundle-grant=%lld",
                                   (long long)bundleGrant]];
        } else {
            [ContainerAccess note:@"apply:no-local-bundle"];
        }

        NSError *mcmError = nil;
        BOOL applied = [PatchTransaction applyPackage:pkg
                                            container:container
                                           bundlePath:localBundle
                                             bundleID:bundleID
                                                error:&mcmError];
        if (bundleGrant >= 0) [ContainerAccess releaseAccess:bundleGrant];
        if (grant >= 0) [ContainerAccess releaseAccess:grant];
        if (applied) {
            [ContainerAccess note:@"apply:done-mcm"];
            return YES;
        }
        [ContainerAccess note:@"apply:mcm-failed"];
        NSString *reason = mcmError.localizedFailureReason ?: mcmError.localizedDescription;
        if (reason.length) [reasons addObject:[NSString stringWithFormat:@"MCM: %@", reason]];
        if (grant < 0) {
            NSString *grantDetail = grantError.localizedFailureReason ?: grantError.localizedDescription;
            if (grantDetail.length) {
                [diagnostics addObject:[NSString stringWithFormat:@"grant: %@", grantDetail]];
            }
        }
        for (NSString *line in mcmError.userInfo[@"ZDMADiagnostics"]) {
            [diagnostics addObject:[NSString stringWithFormat:@"MCM: %@", line]];
        }
    } else {
        [ContainerAccess note:@"apply:no-container"];
        NSString *reason = containerError.localizedFailureReason ?: containerError.localizedDescription;
        if (reason.length) [reasons addObject:[NSString stringWithFormat:@"MCM: %@", reason]];
        for (NSString *line in containerError.userInfo[@"ZDMADiagnostics"]) {
            [diagnostics addObject:[NSString stringWithFormat:@"MCM: %@", line]];
        }
    }

    // 2. Airlift: resolves the container through InstallationProxy and writes
    //    through the AirTraffic (com.apple.atc) sync escape. No MCM lease and
    //    no House Arrest involved.
    [ContainerAccess note:@"apply:airlift-lookup"];
    NSError *airliftError = nil;
    NSString *remoteContainer = [AirliftBridge containerForBundleID:bundleID
                                                               log:^(NSString *line) {
        [ContainerAccess note:[NSString stringWithFormat:@"airlift: %@", line]];
    }
                                                             error:&airliftError];
    if (remoteContainer.length) {
        [ContainerAccess note:[NSString stringWithFormat:@"apply:airlift-container %@", remoteContainer]];
        NSError *writeError = nil;
        if ([PatchTransaction applyPackage:pkg
                      viaAirliftToContainer:remoteContainer
                                  bundleID:bundleID
                                     error:&writeError]) {
            [ContainerAccess note:@"apply:done-airlift"];
            return YES;
        }
        [ContainerAccess note:@"apply:airlift-failed"];
        NSString *reason = writeError.localizedFailureReason ?: writeError.localizedDescription;
        if (reason.length) [reasons addObject:[NSString stringWithFormat:@"Airlift: %@", reason]];
        for (NSString *line in writeError.userInfo[@"ZDMADiagnostics"]) {
            [diagnostics addObject:[NSString stringWithFormat:@"Airlift: %@", line]];
        }
    } else {
        NSString *reason = airliftError.localizedFailureReason ?: airliftError.localizedDescription;
        if (reason.length) [reasons addObject:[NSString stringWithFormat:@"Airlift: %@", reason]];
        for (NSString *line in airliftError.userInfo[@"ZDMADiagnostics"]) {
            [diagnostics addObject:[NSString stringWithFormat:@"Airlift: %@", line]];
        }
    }

    for (NSString *line in [AirliftBridge lastLogLines]) {
        [diagnostics addObject:[NSString stringWithFormat:@"Airlift: %@", line]];
    }

    if (err) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:
                                           @"Injektimi i %@ dështoi (MCM + Airlift).", bundleID];
        if (reasons.count) info[NSLocalizedFailureReasonErrorKey] = [reasons componentsJoinedByString:@" | "];
        if (diagnostics.count) info[@"ZDMADiagnostics"] = diagnostics;
        *err = [NSError errorWithDomain:@"zadaDMA.patch" code:EIO userInfo:info];
    }
    [ContainerAccess note:@"apply:failed"];
    return NO;
}

+ (BOOL)restoreGroup:(NSString *)group forBundleID:(NSString *)bundleID error:(NSError **)err {
    [ContainerAccess note:[NSString stringWithFormat:@"restore:begin %@ %@", bundleID, group]];

    // 1. Local path first: MCM resolves the container, worse_query grants the
    //    sandbox extension. No pairing is required when this succeeds.
    NSError *containerError = nil;
    NSString *localContainer = [self containerPathForBundleID:bundleID
                                                      timeout:6.0
                                                        error:&containerError];
    int64_t localGrant = -1;
    if (localContainer.length) {
        localGrant = [ContainerAccess acquireAccessToPath:localContainer error:nil];
        [ContainerAccess note:[NSString stringWithFormat:@"restore:local-grant=%lld",
                               (long long)localGrant]];
    } else {
        [ContainerAccess note:@"restore:no-local-container"];
    }

    NSString *localBundle = [ContainerAccess applicationBundlePathForBundleID:bundleID error:nil];
    if (localBundle.length) {
        [ContainerAccess note:[NSString stringWithFormat:@"restore:local-bundle %@", localBundle]];
    } else {
        [ContainerAccess note:@"restore:no-local-bundle"];
    }

    NSString *remoteBundle = nil;
    NSError *bundleError = nil;
    if ([AirliftBridge isAvailable]) {
        remoteBundle = [AirliftBridge bundlePathForBundleID:bundleID
                                                        log:^(NSString *line) {
            [ContainerAccess note:[NSString stringWithFormat:@"restore-bundle: %@", line]];
        }
                                                      error:&bundleError];
        if (!remoteBundle.length) {
            [ContainerAccess note:[NSString stringWithFormat:@"restore:no-bundle %@",
                                   bundleError.localizedFailureReason ?: bundleError.localizedDescription ?: @""]];
        }
    }

    int64_t bundleGrant = -1;
    NSString *localBundleForRestore = localBundle.length ? localBundle : remoteBundle;
    if (localBundleForRestore.length && localGrant >= 0) {
        bundleGrant = [ContainerAccess acquireAccessToPath:localBundleForRestore error:nil];
        [ContainerAccess note:[NSString stringWithFormat:@"restore:bundle-grant=%lld",
                               (long long)bundleGrant]];
    }

    NSError *restoreError = nil;
    BOOL restored = NO;
    if (localGrant >= 0) {
        restored = [PatchTransaction restoreGroup:group
                                         bundleID:bundleID
                                        container:localContainer
                                       bundlePath:localBundleForRestore
                                      localAccess:YES
                                            error:&restoreError];
        if (restored) {
            [ContainerAccess note:@"restore:done-local"];
        } else {
            [ContainerAccess note:@"restore:local-failed"];
        }
    }
    if (bundleGrant >= 0) [ContainerAccess releaseAccess:bundleGrant];
    if (localGrant >= 0) [ContainerAccess releaseAccess:localGrant];
    if (restored) return YES;

    // 2. Airlift fallback: requires the RPPairing import.
    if (![AirliftBridge isAvailable]) {
        if (err) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            info[NSLocalizedDescriptionKey] = @"Origjinali nuk u kthye.";
            NSString *reason = restoreError.localizedFailureReason ?: restoreError.localizedDescription;
            info[NSLocalizedFailureReasonErrorKey] = reason.length
                ? reason
                : @"Sandbox grant dështoi dhe pairing-u mungon.";
            *err = [NSError errorWithDomain:@"zadaDMA.patch" code:EACCES userInfo:info];
        }
        [ContainerAccess note:@"restore:no-pairing"];
        return NO;
    }

    NSError *airliftContainerError = nil;
    NSString *remoteContainer = [AirliftBridge containerForBundleID:bundleID
                                                                log:^(NSString *line) {
        [ContainerAccess note:[NSString stringWithFormat:@"restore-airlift: %@", line]];
    }
                                                              error:&airliftContainerError];
    if (!remoteContainer.length) {
        [ContainerAccess note:[NSString stringWithFormat:@"restore:no-container %@",
                               airliftContainerError.localizedFailureReason ?: airliftContainerError.localizedDescription ?: @""]];
    }

    NSError *airliftError = nil;
    if ([PatchTransaction restoreGroup:group
                              bundleID:bundleID
                             container:remoteContainer
                            bundlePath:remoteBundle
                           localAccess:NO
                                 error:&airliftError]) {
        [ContainerAccess note:@"restore:done"];
        return YES;
    }

    NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];
    for (NSString *line in [AirliftBridge lastLogLines]) {
        [diagnostics addObject:[NSString stringWithFormat:@"Airlift: %@", line]];
    }

    if (err) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:
                                           @"Kthimi i origjinalit për %@ dështoi.", bundleID];
        NSString *reason = airliftError.localizedFailureReason
            ?: airliftError.localizedDescription
            ?: restoreError.localizedFailureReason
            ?: restoreError.localizedDescription;
        if (reason.length) info[NSLocalizedFailureReasonErrorKey] = reason;
        if (diagnostics.count) info[@"ZDMADiagnostics"] = diagnostics;
        *err = [NSError errorWithDomain:@"zadaDMA.patch" code:EIO userInfo:info];
    }
    [ContainerAccess note:@"restore:failed"];
    return NO;
}

@end
