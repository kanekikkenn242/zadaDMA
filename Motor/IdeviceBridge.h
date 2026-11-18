#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge to the real idevice RPPairing / RSD / House Arrest / AFC stack.
///
/// Pairing flow (iOS 27 device-initiated pairing):
///   1. startPairableHost... advertises _remotepairing-pairable-host._tcp
///      and shows the PIN the user types on the iPhone.
///   2. iOS persists an RPPairing file in Documents/rppairing.plist.
///   3. writeFile... browses _remotepairing._tcp, opens the TLS-PSK tunnel,
///      connects House Arrest over RSD and writes the file with AFC.
@interface IdeviceBridge : NSObject

+ (instancetype)shared;

- (void)startPairableHostWithName:(NSString *)name
                            model:(NSString *)model
                             port:(uint16_t)port
                  pairingFilePath:(NSString *)pairingFilePath
                       readyBlock:(void (^)(NSString *identifier, uint16_t port))readyBlock
                         pinBlock:(void (^)(NSString *pin))pinBlock
                       completion:(void (^)(BOOL success, NSString *message))completion;

- (void)cancelPairableHost;

- (void)writeFileAtPath:(NSString *)localPath
               bundleID:(NSString *)bundleID
             remotePath:(NSString *)remotePath
        pairingFilePath:(NSString *)pairingFilePath
               hostname:(NSString *)hostname
             completion:(void (^)(BOOL success, NSString *message))completion;

@end

NS_ASSUME_NONNULL_END
