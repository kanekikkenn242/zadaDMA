#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, PatchCodecError) {
    PatchCodecErrorBadMagic = 1, PatchCodecErrorTruncated, PatchCodecErrorKDF,
    PatchCodecErrorUnwrap, PatchCodecErrorAuthTag, PatchCodecErrorMalformed,
    PatchCodecErrorRust,
};
@interface PatchPackage : NSObject
@property (nonatomic, copy) NSArray<NSDictionary *> *rules;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *files;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *digests;
@property (nonatomic, copy) NSDictionary<NSString *, id> *metadata;
@end
@interface PatchPackageCodec : NSObject
+ (nullable PatchPackage *)decodeData:(NSData *)data passphrase:(NSString *)passphrase error:(NSError **)err;
+ (nullable NSData *)encodePackage:(PatchPackage *)pkg passphrase:(NSString *)passphrase error:(NSError **)err;
+ (NSString *)sha256Hex:(NSData *)d;
@end
NS_ASSUME_NONNULL_END
