#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface AFCClient : NSObject
- (nullable instancetype)initWithSocketFD:(int)fd;
- (BOOL)fileOpen:(NSString *)path mode:(uint64_t)mode handle:(uint64_t *)outHandle error:(NSError **)err;
- (BOOL)fileWrite:(uint64_t)h data:(NSData *)data error:(NSError **)err;
- (BOOL)fileClose:(uint64_t)h error:(NSError **)err;
- (BOOL)removePath:(NSString *)path error:(NSError **)err;
- (BOOL)renamePath:(NSString *)from to:(NSString *)to error:(NSError **)err;
- (BOOL)makeDirectory:(NSString *)path error:(NSError **)err;
- (NSArray<NSString *> *_Nullable)readDirectory:(NSString *)path error:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
