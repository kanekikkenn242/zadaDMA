#pragma once
#import <Foundation/Foundation.h>
@class PatchPackage;
NS_ASSUME_NONNULL_BEGIN
@interface DevicePatchService : NSObject
+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID;
+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID error:(NSError **)error;
+ (BOOL)applyPatch:(PatchPackage *)pkg toBundleID:(NSString *)bundleID error:(NSError **)err;

/// Writes the original bytes captured before the first Airlift write of
/// `group` back to the device and verifies them. The pairing tunnel must be
/// available; this never touches NSFileManager for the remote target.
+ (BOOL)restoreGroup:(NSString *)group forBundleID:(NSString *)bundleID error:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
