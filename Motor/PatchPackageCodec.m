#import "PatchPackageCodec.h"
#import <stdlib.h>
#import <string.h>
extern int zdma_sha256(const uint8_t *, size_t, uint8_t *);
extern int zdma_pbkdf2_sha256(const uint8_t *, size_t, const uint8_t *, size_t, uint32_t, uint8_t *, size_t);
extern int zdma_aes256gcm_encrypt(const uint8_t *, size_t, const uint8_t *, size_t, const uint8_t *, size_t, uint8_t *, uint8_t *);
extern int zdma_aes256gcm_decrypt(const uint8_t *, size_t, const uint8_t *, size_t, const uint8_t *, size_t, const uint8_t *, size_t, uint8_t *);
extern int zdma_random(uint8_t *, size_t);

static NSString *HexOf(NSData *d) {
    static const char *h="0123456789abcdef";
    NSMutableString *s=[NSMutableString stringWithCapacity:d.length*2];
    const uint8_t *b=d.bytes;
    for (NSUInteger i=0;i<d.length;i++) [s appendFormat:@"%c%c",h[b[i]>>4],h[b[i]&15]];
    return s;
}
static NSData *SHA256(NSData *d) { uint8_t o[32]; zdma_sha256(d.bytes,d.length,o); return [NSData dataWithBytes:o length:32]; }
@implementation PatchPackage @end
static const uint32_t kVer = 1;

@implementation PatchPackageCodec
+ (NSData *)deriveKEK:(NSString *)pw salt:(NSData *)salt iter:(uint32_t)iter {
    uint8_t kek[32];
    NSData *pwD=[pw dataUsingEncoding:NSUTF8StringEncoding];
    zdma_pbkdf2_sha256(pwD.bytes,pwD.length,salt.bytes,salt.length,iter,kek,32);
    return [NSData dataWithBytes:kek length:32];
}
+ (nullable PatchPackage *)decodeData:(NSData *)data passphrase:(NSString *)pass error:(NSError **)err {
    const uint8_t *p=data.bytes; NSUInteger n=data.length,o=0;
#define NEED(k) do{ if(o+(k)>n){ if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorTruncated userInfo:nil]; return nil;} }while(0)
    NEED(4); if(memcmp(p+o,"3105",4)){ if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorBadMagic userInfo:nil]; return nil;} o+=4;
    NEED(4); uint32_t ver; memcpy(&ver,p+o,4); o+=4; if(ver!=kVer){ if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorMalformed userInfo:nil]; return nil;}
    NEED(16); NSData *salt=[NSData dataWithBytes:p+o length:16]; o+=16;
    NEED(4); uint32_t iter; memcpy(&iter,p+o,4); o+=4;
    NEED(4); uint32_t wl; memcpy(&wl,p+o,4); o+=4;
    NEED(wl); NSData *wrap=[NSData dataWithBytes:p+o length:wl]; o+=wl;
    NEED(12); NSData *wn=[NSData dataWithBytes:p+o length:12]; o+=12;
    NEED(16); uint8_t wt[16]; memcpy(wt,p+o,16); o+=16;
    NSData *kek=[self deriveKEK:pass salt:salt iter:iter];
    NSMutableData *key=[NSMutableData dataWithLength:wrap.length];
    if(zdma_aes256gcm_decrypt(kek.bytes,32,wn.bytes,12,wrap.bytes,wrap.length,wt,16,key.mutableBytes)!=0){
        if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorUnwrap userInfo:nil]; return nil; }
    NEED(12); NSData *nonce=[NSData dataWithBytes:p+o length:12]; o+=12;
    NEED(16); NSData *tag=[NSData dataWithBytes:p+o length:16]; o+=16;
    NEED(8); uint64_t cl; memcpy(&cl,p+o,8); o+=8;
    NEED(cl); NSData *ct=[NSData dataWithBytes:p+o length:(NSUInteger)cl]; o+=cl;
    NSMutableData *plain=[NSMutableData dataWithLength:(NSUInteger)cl];
    if(zdma_aes256gcm_decrypt(key.bytes,32,nonce.bytes,12,ct.bytes,ct.length,tag.bytes,16,plain.mutableBytes)!=0){
        if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorAuthTag userInfo:nil]; return nil; }
    NSError *e=nil; NSDictionary *root=[NSJSONSerialization JSONObjectWithData:plain options:0 error:&e];
    if(!root){ if(err)*err=e; return nil; }
    PatchPackage *pkg=[PatchPackage new];
    NSMutableDictionary *files=[NSMutableDictionary dictionary];
    for(NSString *k in root[@"files"]) files[k]=[[NSData alloc] initWithBase64EncodedString:root[@"files"][k] options:0];
    pkg.files=files; pkg.rules=root[@"rules"]?:@[]; pkg.digests=root[@"digests"]?:@{}; pkg.metadata=root[@"meta"]?:@{};
#undef NEED
    return pkg;
}
+ (nullable NSData *)encodePackage:(PatchPackage *)pkg passphrase:(NSString *)pass error:(NSError **)err {
    NSMutableDictionary *files=[NSMutableDictionary dictionary];
    for(NSString *k in pkg.files) files[k]=[pkg.files[k] base64EncodedStringWithOptions:0];
    NSDictionary *root=@{@"files":files,@"rules":pkg.rules?:@[],@"digests":pkg.digests?:@{},@"meta":pkg.metadata?:@{}};
    NSData *plain=[NSJSONSerialization dataWithJSONObject:root options:0 error:err]; if(!plain) return nil;
    uint8_t salt[16]; zdma_random(salt,16);
    uint32_t iter=120000;
    NSData *kek=[self deriveKEK:pass salt:[NSData dataWithBytes:salt length:16] iter:iter];
    uint8_t kb[32]; zdma_random(kb,32); NSData *key=[NSData dataWithBytes:kb length:32];
    uint8_t wn[12]; zdma_random(wn,12); uint8_t wt[16]; NSMutableData *wrap=[NSMutableData dataWithLength:32];
    if(zdma_aes256gcm_encrypt(kek.bytes,32,wn,12,key.bytes,32,wrap.mutableBytes,wt)!=0){
        if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorRust userInfo:nil]; return nil; }
    uint8_t nonce[12]; zdma_random(nonce,12); uint8_t tag[16];
    NSMutableData *ct=[NSMutableData dataWithLength:plain.length];
    if(zdma_aes256gcm_encrypt(key.bytes,32,nonce,12,plain.bytes,plain.length,ct.mutableBytes,tag)!=0){
        if(err)*err=[NSError errorWithDomain:@"3105" code:PatchCodecErrorRust userInfo:nil]; return nil; }
    NSMutableData *out=[NSMutableData data];
    [out appendBytes:"3105" length:4];
    uint32_t v=kVer; [out appendBytes:&v length:4];
    [out appendBytes:salt length:16]; [out appendBytes:&iter length:4];
    uint32_t wl=(uint32_t)wrap.length; [out appendBytes:&wl length:4];
    [out appendData:wrap]; [out appendBytes:wn length:12]; [out appendBytes:wt length:16];
    [out appendBytes:nonce length:12]; [out appendBytes:tag length:16];
    uint64_t cl=ct.length; [out appendBytes:&cl length:8]; [out appendData:ct];
    return out;
}
+ (NSString *)sha256Hex:(NSData *)d { return HexOf(SHA256(d)); }
@end
