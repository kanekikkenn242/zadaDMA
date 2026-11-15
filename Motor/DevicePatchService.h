#pragma once
#import <Foundation/Foundation.h>
@class PatchPackage;
NS_ASSUME_NONNULL_BEGIN
@interface DevicePatchService : NSObject
+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID;
+ (BOOL)applyPatch:(PatchPackage *)pkg toBundleID:(NSString *)bundleID error:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
