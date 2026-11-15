#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface SandboxEscape : NSObject
@property (atomic, readonly) BOOL escaped;
@property (atomic, readonly) int64_t sandboxHandle;
+ (nullable instancetype)escapeForBundleID:(NSString *)bundleID error:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
