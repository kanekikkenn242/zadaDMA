#import "DevicePatchService.h"
#import "ContainerAccess.h"
#import "PatchTransaction.h"
#import "PatchPackageCodec.h"
#import "AirliftBridge.h"
#import <dlfcn.h>
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

+ (BOOL)applyPatch:(PatchPackage *)pkg toBundleID:(NSString *)bundleID error:(NSError **)err {
    [ContainerAccess note:[NSString stringWithFormat:@"apply:begin %@", bundleID]];

    NSMutableArray<NSString *> *diagnostics = [NSMutableArray array];
    NSMutableArray<NSString *> *reasons = [NSMutableArray array];

    // 1. Primary path: MobileContainerManager class-2 lease when the host
    //    bundle identifier is honoured by the daemon.
    NSError *containerError = nil;
    NSString *container = [self containerPathForBundleID:bundleID error:&containerError];
    if (container.length) {
        [ContainerAccess note:[NSString stringWithFormat:@"apply:container %@", container]];
        NSError *mcmError = nil;
        if ([PatchTransaction applyPackage:pkg container:container bundleID:bundleID error:&mcmError]) {
            [ContainerAccess note:@"apply:done-mcm"];
            return YES;
        }
        [ContainerAccess note:@"apply:mcm-failed"];
        NSString *reason = mcmError.localizedFailureReason ?: mcmError.localizedDescription;
        if (reason.length) [reasons addObject:[NSString stringWithFormat:@"MCM: %@", reason]];
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

@end
