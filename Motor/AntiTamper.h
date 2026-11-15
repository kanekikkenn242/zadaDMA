#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AntiTamper : NSObject
+ (BOOL)verifyAndBlockIfNeeded:(NSError **)err;
+ (BOOL)isDebuggerAttached;
+ (BOOL)isSimulator;
+ (NSString *)sha256OfFile:(NSString *)path;
@end
NS_ASSUME_NONNULL_END
