#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Relocates the aim float slots from a `.3105` asset onto whatever build of
/// that asset is installed on the device.
///
/// Packages are authored against one game build. The float triples are stored
/// immediately before a length-prefixed `bone_*` name (for example
/// `00 00 40 40 00 00 40 40 00 00 40 40 09 00 00 00 bone_Head`). Those names
/// are stable across builds while the absolute offsets are not, so they are
/// used as anchors instead of a hard-coded base offset.
///
/// Both inputs may be raw `UnityFS` bytes or gzip-compressed `UnityFS` bytes.
/// The returned data uses the same container as `deviceAsset`, preserving the
/// device's own build byte-for-byte apart from the relocated floats. Returns
/// nil when no usable anchor is present in either asset.
@interface AssetSlotAnchor : NSObject
+ (nullable NSData *)patchedAssetFromPackage:(NSData *)packageAsset
                                      device:(NSData *)deviceAsset;
@end

NS_ASSUME_NONNULL_END
