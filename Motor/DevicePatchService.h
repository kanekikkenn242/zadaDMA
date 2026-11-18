#pragma once
#import <Foundation/Foundation.h>
@class PatchPackage;
NS_ASSUME_NONNULL_BEGIN
@interface DevicePatchService : NSObject
+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID;
+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID error:(NSError **)error;
+ (BOOL)applyPatch:(PatchPackage *)pkg toBundleID:(NSString *)bundleID error:(NSError **)err;

/// Writes the original bytes captured before the first write of `group` back
/// to the device and verifies them. Tries the local MCM/worse_query path first
/// (no pairing), then falls back to Airlift when pairing is available.
+ (BOOL)restoreGroup:(NSString *)group forBundleID:(NSString *)bundleID error:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
