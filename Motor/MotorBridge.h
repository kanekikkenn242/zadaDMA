#import <Foundation/Foundation.h>
#import "PatchPackageCodec.h"
#import "DevicePatchService.h"
#import "IdeviceBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface MotorBridge : NSObject
+ (BOOL)bootstrap;
+ (void)ensureSandbox:(void(^)(BOOL ok, NSError * _Nullable err))done;
+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID;
/**
 * Decodes a bundled .3105 and writes it into every installed target in
 * `bundleIDs` through the on-device MobileContainerManager lease.
 *
 * Result keys:
 *   patched : NSArray<NSString *>  bundle IDs that were patched
 *   errors  : NSArray<NSString *>  per-bundle diagnostics
 *   error   : NSString             only when the package itself is unusable
 */
+ (NSDictionary<NSString *, id> *)applyPatchFile:(NSString *)patchName
                                       bundleIDs:(NSArray<NSString *> *)bundleIDs;
/**
 * Restores the originals captured before the first write of every destination
 * group used by `patchName`. The package may be any variant of the group
 * (e.g. `aimneck_cache` or `aimneck_torso_cache` share `cache_res`).
 *
 * Result keys:
 *   restored : NSArray<NSString *>  bundle IDs whose originals are back
 *   errors   : NSArray<NSString *>  per-bundle diagnostics
 *   groups   : NSArray<NSString *>  destination groups derived from the package
 *   error    : NSString             only when the package itself is unusable
 */
+ (NSDictionary<NSString *, id> *)restorePatchFile:(NSString *)patchName
                                         bundleIDs:(NSArray<NSString *> *)bundleIDs;
+ (nullable NSArray<NSString *> *)appContainers;
/**
 * Free Fire variants that are actually installed on this device.
 *
 * The store ships two distinct apps (`com.dts.freefireth` and
 * `com.dts.freefiremax`); a device normally has only one of them. Attempting
 * the missing one produces a confusing "apply failed" log even when the
 * installed game was patched, so callers must only target what is present.
 * Falls back to both identifiers when the sandbox hides the app catalogue.
 */
+ (NSArray<NSString *> *)installedFreeFireBundleIDs;
+ (BOOL)applyPatch:(NSString *)patchName;
+ (NSString *)containerPathForBundleID:(NSString *)bundleID;
+ (void)resetInjectionTrace;
+ (NSString *)injectionTrace;
@end

NS_ASSUME_NONNULL_END
