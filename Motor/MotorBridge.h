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
+ (nullable NSArray<NSString *> *)appContainers;
+ (BOOL)applyPatch:(NSString *)patchName;
+ (NSString *)containerPathForBundleID:(NSString *)bundleID;
+ (void)resetInjectionTrace;
+ (NSString *)injectionTrace;
@end

NS_ASSUME_NONNULL_END
