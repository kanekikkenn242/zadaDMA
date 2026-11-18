#pragma once
#import <Foundation/Foundation.h>
#import "AFCClient.h"
NS_ASSUME_NONNULL_BEGIN
@interface PairingController : NSObject
- (nullable instancetype)initWithPairingFileURL:(NSURL *)url error:(NSError **)err;
- (BOOL)connectWithError:(NSError **)err;
- (nullable AFCClient *)openAFCWithError:(NSError **)err;
- (BOOL)closeWithError:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
