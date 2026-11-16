#import "IdeviceBridge.h"
#import "zdma_pairing.h"

#import <arpa/inet.h>
#import <netinet/in.h>

static NSData *ZDMATXTData(NSDictionary<NSString *, NSString *> *values) {
    NSMutableData *data = [NSMutableData data];
    [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *entry = [NSString stringWithFormat:@"%@=%@", key, value];
        NSData *utf8 = [entry dataUsingEncoding:NSUTF8StringEncoding];
        if (utf8.length == 0 || utf8.length > 255) { return; }
        uint8_t length = (uint8_t)utf8.length;
        [data appendBytes:&length length:1];
        [data appendData:utf8];
    }];
    return data;
}

static NSDictionary<NSString *, NSString *> *ZDMAParseTXT(NSData *data) {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    const uint8_t *bytes = data.bytes;
    NSUInteger total = data.length;
    NSUInteger offset = 0;
    while (offset < total) {
        uint8_t length = bytes[offset++];
        if (length == 0 || offset + length > total) { break; }
        NSString *entry = [[NSString alloc] initWithBytes:bytes + offset
                                                   length:length
                                                 encoding:NSUTF8StringEncoding];
        offset += length;
        if (!entry) { continue; }
        NSRange separator = [entry rangeOfString:@"="];
        if (separator.location == NSNotFound) { continue; }
        values[[entry substringToIndex:separator.location]] =
            [entry substringFromIndex:separator.location + 1];
    }
    return values;
}

@interface IdeviceBridge () <NSNetServiceDelegate, NSNetServiceBrowserDelegate>
@property (nonatomic, strong) NSNetService *hostService;
@property (nonatomic, strong) NSNetServiceBrowser *browser;
@property (nonatomic, strong) NSMutableArray<NSNetService *> *resolvingServices;
@property (nonatomic, strong) NSTimer *browseTimer;
@property (nonatomic, strong) NSTimer *fallbackTimer;

@property (nonatomic, copy, nullable) void (^hostCompletion)(BOOL, NSString *);
@property (nonatomic, copy, nullable) void (^pinBlock)(NSString *);
@property (nonatomic, copy, nullable) void (^readyBlock)(NSString *, uint16_t);
@property (nonatomic, assign) BOOL hostRunning;

@property (nonatomic, copy, nullable) void (^writeCompletion)(BOOL, NSString *);
@property (nonatomic, copy, nullable) NSString *writeLocalPath;
@property (nonatomic, copy, nullable) NSString *writeBundleID;
@property (nonatomic, copy, nullable) NSString *writeRemotePath;
@property (nonatomic, copy, nullable) NSString *writePairingPath;
@property (nonatomic, copy, nullable) NSString *writeHostname;
@property (nonatomic, strong, nullable) NSDictionary *fallbackCandidate;

@property (nonatomic, strong) dispatch_queue_t hostQueue;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@end

@implementation IdeviceBridge

+ (instancetype)shared {
    static IdeviceBridge *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IdeviceBridge alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hostQueue = dispatch_queue_create("com.zadaDMA.idevice.host", DISPATCH_QUEUE_SERIAL);
        _ioQueue = dispatch_queue_create("com.zadaDMA.idevice.io", DISPATCH_QUEUE_SERIAL);
        _resolvingServices = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Pairable host

static void ZDMAReadyTrampoline(const char *identifier,
                                const char *name,
                                const char *model,
                                const char *authTag,
                                const char *flags,
                                const char *ver,
                                const char *minVer,
                                uint16_t port,
                                void *ctx) {
    IdeviceBridge *bridge = (__bridge IdeviceBridge *)ctx;
    NSString *sIdentifier = identifier ? [NSString stringWithUTF8String:identifier] : @"";
    NSString *sName = name ? [NSString stringWithUTF8String:name] : @"zadaDMA";
    NSString *sModel = model ? [NSString stringWithUTF8String:model] : @"Mac17,7";
    NSString *sAuth = authTag ? [NSString stringWithUTF8String:authTag] : @"";
    NSString *sFlags = flags ? [NSString stringWithUTF8String:flags] : @"1";
    NSString *sVer = ver ? [NSString stringWithUTF8String:ver] : @"26";
    NSString *sMin = minVer ? [NSString stringWithUTF8String:minVer] : @"17";
    [bridge publishHostWithIdentifier:sIdentifier
                                 name:sName
                                model:sModel
                              authTag:sAuth
                                flags:sFlags
                                  ver:sVer
                               minVer:sMin
                                 port:port];
}

static void ZDMAPinTrampoline(const char *pin, void *ctx) {
    IdeviceBridge *bridge = (__bridge IdeviceBridge *)ctx;
    NSString *value = pin ? [NSString stringWithUTF8String:pin] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        if (bridge.pinBlock) { bridge.pinBlock(value); }
    });
}

- (void)publishHostWithIdentifier:(NSString *)identifier
                             name:(NSString *)name
                            model:(NSString *)model
                          authTag:(NSString *)authTag
                            flags:(NSString *)flags
                              ver:(NSString *)ver
                           minVer:(NSString *)minVer
                             port:(uint16_t)port {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.hostRunning) { return; }
        [self.hostService stop];
        self.hostService = [[NSNetService alloc] initWithDomain:@"local."
                                                          type:@"_remotepairing-pairable-host._tcp."
                                                          name:identifier
                                                          port:(NSInteger)port];
        self.hostService.delegate = self;
        NSDictionary<NSString *, NSString *> *txt = @{
            @"name": name,
            @"identifier": identifier,
            @"authTag": authTag,
            @"model": model,
            @"flags": flags,
            @"ver": ver,
            @"minVer": minVer,
        };
        if (![self.hostService setTXTRecordData:ZDMATXTData(txt)]) {
            NSLog(@"[IdeviceBridge] setTXTRecordData failed");
        }
        [self.hostService scheduleInRunLoop:[NSRunLoop mainRunLoop]
                                   forMode:NSRunLoopCommonModes];
        [self.hostService publish];
        NSLog(@"[IdeviceBridge] advertising pairable host %@ port %u", name, port);
        if (self.readyBlock) { self.readyBlock(identifier, port); }
    });
}

- (void)startPairableHostWithName:(NSString *)name
                            model:(NSString *)model
                             port:(uint16_t)port
                  pairingFilePath:(NSString *)pairingFilePath
                       readyBlock:(void (^)(NSString *, uint16_t))readyBlock
                         pinBlock:(void (^)(NSString *))pinBlock
                       completion:(void (^)(BOOL, NSString *))completion {
    if (self.hostRunning) {
        completion(NO, @"Pairing already running");
        return;
    }
    self.hostRunning = YES;
    self.hostCompletion = completion;
    self.readyBlock = readyBlock;
    self.pinBlock = pinBlock;

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.hostQueue, ^{
        char err[2048] = {0};
        int rc = zdma_pairing_host_accept(name.UTF8String,
                                          model.UTF8String,
                                          port,
                                          ZDMAReadyTrampoline,
                                          ZDMAPinTrampoline,
                                          (__bridge void *)weakSelf,
                                          pairingFilePath.UTF8String,
                                          err,
                                          sizeof(err));
        NSString *message = err[0] ? [NSString stringWithUTF8String:err] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            IdeviceBridge *strongSelf = weakSelf;
            if (!strongSelf) { return; }
            strongSelf.hostRunning = NO;
            [strongSelf.hostService stop];
            strongSelf.hostService = nil;
            void (^done)(BOOL, NSString *) = strongSelf.hostCompletion;
            strongSelf.hostCompletion = nil;
            strongSelf.readyBlock = nil;
            strongSelf.pinBlock = nil;
            if (done) {
                done(rc == 0, message.length ? message : (rc == 0 ? @"Paired" : @"Pairing failed"));
            }
        });
    });
}

- (void)cancelPairableHost {
    zdma_pairing_host_cancel();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hostService stop];
        self.hostService = nil;
    });
}

#pragma mark - NSNetService delegate (pairable host)

- (void)netServiceDidPublish:(NSNetService *)sender {
    NSLog(@"[IdeviceBridge] pairable host published: %@", sender.name);
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"[IdeviceBridge] pairable host publish failed: %@", errorDict);
    zdma_pairing_host_cancel();
}

#pragma mark - AFC write

- (void)writeFileAtPath:(NSString *)localPath
               bundleID:(NSString *)bundleID
             remotePath:(NSString *)remotePath
        pairingFilePath:(NSString *)pairingFilePath
               hostname:(NSString *)hostname
             completion:(void (^)(BOOL, NSString *))completion {
    if (self.writeCompletion) {
        completion(NO, @"Another write is already running");
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:pairingFilePath]) {
        completion(NO, @"Pairing file mungon. Bëj Start Pairing së pari.");
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        completion(NO, @"Skedari .3105 mungon në app.");
        return;
    }

    self.writeCompletion = completion;
    self.writeLocalPath = localPath;
    self.writeBundleID = bundleID;
    self.writeRemotePath = remotePath;
    self.writePairingPath = pairingFilePath;
    self.writeHostname = hostname;
    self.fallbackCandidate = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self startBrowsing];
    });
}

- (void)startBrowsing {
    [self stopBrowsing];
    self.browser = [[NSNetServiceBrowser alloc] init];
    self.browser.delegate = self;
    [self.browser scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.browser searchForServicesOfType:@"_remotepairing._tcp." inDomain:@"local."];
    NSLog(@"[IdeviceBridge] browsing _remotepairing._tcp");

    __weak typeof(self) weakSelf = self;
    self.browseTimer = [NSTimer scheduledTimerWithTimeInterval:12.0
                                                       repeats:NO
                                                         block:^(NSTimer *timer) {
        IdeviceBridge *strongSelf = weakSelf;
        if (!strongSelf) { return; }
        if (strongSelf.fallbackCandidate) {
            [strongSelf performWriteWithCandidate:strongSelf.fallbackCandidate];
        } else {
            [strongSelf finishWrite:NO
                            message:@"Nuk u gjet _remotepairing._tcp. Kontrollo: Developer Mode ON, i njëjti Wi-Fi, Local Network permission, VPN OFF."];
        }
    }];
}

- (void)stopBrowsing {
    [self.browser stop];
    self.browser.delegate = nil;
    self.browser = nil;
    [self.browseTimer invalidate];
    self.browseTimer = nil;
    [self.fallbackTimer invalidate];
    self.fallbackTimer = nil;
    for (NSNetService *service in self.resolvingServices) {
        service.delegate = nil;
        [service stop];
    }
    [self.resolvingServices removeAllObjects];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    NSLog(@"[IdeviceBridge] found %@", service.name);
    service.delegate = self;
    [service scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.resolvingServices addObject:service];
    [service resolveWithTimeout:5.0];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
         didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"[IdeviceBridge] browse failed: %@", errorDict);
    [self finishWrite:NO message:@"Bonjour browse dështoi. Kontrollo Local Network permission."];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSString *ip = nil;
    uint16_t port = (uint16_t)sender.port;
    for (NSData *address in sender.addresses) {
        const struct sockaddr *sa = address.bytes;
        if (!sa) { continue; }
        if (sa->sa_family == AF_INET) {
            const struct sockaddr_in *sin = (const struct sockaddr_in *)sa;
            char buffer[INET_ADDRSTRLEN] = {0};
            if (inet_ntop(AF_INET, &sin->sin_addr, buffer, sizeof(buffer))) {
                ip = [NSString stringWithUTF8String:buffer];
                if (ntohs(sin->sin_port) != 0) { port = ntohs(sin->sin_port); }
                break;
            }
        }
    }
    if (!ip) {
        NSLog(@"[IdeviceBridge] %@ has no IPv4 address", sender.name);
        return;
    }

    NSDictionary<NSString *, NSString *> *txt = ZDMAParseTXT(sender.TXTRecordData ?: [NSData data]);
    NSDictionary *candidate = @{
        @"ip": ip,
        @"port": @(port),
        @"identifier": txt[@"identifier"] ?: @"",
        @"authTag": txt[@"authTag"] ?: @"",
    };
    NSLog(@"[IdeviceBridge] resolved %@ -> %@:%u txt=%@", sender.name, ip, port, txt);

    int match = 0;
    if (self.writePairingPath.length && [candidate[@"identifier"] length] && [candidate[@"authTag"] length]) {
        match = zdma_pairing_file_validate(self.writePairingPath.UTF8String,
                                           [candidate[@"identifier"] UTF8String],
                                           [candidate[@"authTag"] UTF8String]);
    }
    if (match == 1) {
        [self performWriteWithCandidate:candidate];
        return;
    }

    if (!self.fallbackCandidate) {
        self.fallbackCandidate = candidate;
        __weak typeof(self) weakSelf = self;
        self.fallbackTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                            repeats:NO
                                                              block:^(NSTimer *timer) {
            IdeviceBridge *strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.fallbackCandidate) { return; }
            [strongSelf performWriteWithCandidate:strongSelf.fallbackCandidate];
        }];
    }
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"[IdeviceBridge] resolve failed %@: %@", sender.name, errorDict);
}

- (void)performWriteWithCandidate:(NSDictionary *)candidate {
    if (!self.writeCompletion) { return; }
    NSString *ip = candidate[@"ip"];
    uint16_t port = (uint16_t)[candidate[@"port"] unsignedShortValue];
    NSString *localPath = self.writeLocalPath;
    NSString *bundleID = self.writeBundleID;
    NSString *remotePath = self.writeRemotePath;
    NSString *pairingPath = self.writePairingPath;
    NSString *hostname = self.writeHostname;
    void (^done)(BOOL, NSString *) = self.writeCompletion;

    // Stop browsing before clearing state.
    [self stopBrowsing];
    self.writeCompletion = nil;
    self.writeLocalPath = nil;
    self.writeBundleID = nil;
    self.writeRemotePath = nil;
    self.writePairingPath = nil;
    self.writeHostname = nil;
    self.fallbackCandidate = nil;

    NSLog(@"[IdeviceBridge] writing via %@:%u", ip, port);
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        char err[4096] = {0};
        char out[2048] = {0};
        int rc = zdma_tunnel_write_file(ip.UTF8String,
                                        port,
                                        hostname.UTF8String,
                                        pairingPath.UTF8String,
                                        bundleID.UTF8String,
                                        remotePath.UTF8String,
                                        localPath.UTF8String,
                                        err,
                                        sizeof(err),
                                        out,
                                        sizeof(out));
        NSString *message = rc == 0
            ? (out[0] ? [NSString stringWithUTF8String:out] : @"OK")
            : (err[0] ? [NSString stringWithUTF8String:err] : @"AFC write failed");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) { weakSelf.fallbackCandidate = nil; }
            if (done) { done(rc == 0, message); }
        });
    });
}

- (void)finishWrite:(BOOL)success message:(NSString *)message {
    if (!self.writeCompletion) { return; }
    void (^done)(BOOL, NSString *) = self.writeCompletion;
    self.writeCompletion = nil;
    self.writeLocalPath = nil;
    self.writeBundleID = nil;
    self.writeRemotePath = nil;
    self.writePairingPath = nil;
    self.writeHostname = nil;
    self.fallbackCandidate = nil;
    [self stopBrowsing];
    if (done) { done(success, message); }
}

@end
