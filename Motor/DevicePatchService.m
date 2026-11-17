#import "DevicePatchService.h"
#import "ContainerAccess.h"
#import "PatchTransaction.h"
#import "PatchPackageCodec.h"
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
    NSError *containerError = nil;
    NSString *container = [self containerPathForBundleID:bundleID error:&containerError];
    if (!container) {
        [ContainerAccess note:@"apply:no-container"];
        if (err) *err = containerError;
        return NO;
    }
    [ContainerAccess note:[NSString stringWithFormat:@"apply:container %@", container]];
    BOOL ok = [PatchTransaction applyPackage:pkg container:container bundleID:bundleID error:err];
    [ContainerAccess note:ok ? @"apply:done" : @"apply:failed"];
    return ok;
}

@end
