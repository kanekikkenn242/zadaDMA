#import <Foundation/Foundation.h>
#import "PatchPackageCodec.h"
#import "DevicePatchService.h"

NS_ASSUME_NONNULL_BEGIN

@interface MotorBridge : NSObject
+ (BOOL)bootstrap;
+ (void)ensureSandbox:(void(^)(BOOL ok, NSError * _Nullable err))done;
+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID;
+ (nullable NSArray<NSString *> *)appContainers;
+ (BOOL)applyPatch:(NSString *)patchName;
+ (NSString *)containerPathForBundleID:(NSString *)bundleID;
@end

NS_ASSUME_NONNULL_END
