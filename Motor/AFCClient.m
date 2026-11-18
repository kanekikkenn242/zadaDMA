#import "AFCClient.h"
#import <sys/socket.h>
#import <unistd.h>
enum {
    AFC_OP_STATUS=0x1, AFC_OP_DATA=0x2, AFC_OP_NULL=0x3, AFC_OP_READ_DIR=0x3,
    AFC_OP_REMOVE_PATH=0x8, AFC_OP_MAKE_DIR=0x9, AFC_OP_FILE_OPEN=0xD,
    AFC_OP_FILE_OPEN_RESULT=0xE, AFC_OP_FILE_READ=0xF, AFC_OP_FILE_WRITE=0x10,
    AFC_OP_FILE_SEEK=0x13, AFC_OP_FILE_CLOSE=0x14, AFC_OP_RENAME_PATH=0x18,
};
static const char kAFC[]="CFA6LPAA";
@interface AFCClient () { int _fd; uint64_t _pkt; } @end
@implementation AFCClient
- (instancetype)initWithSocketFD:(int)fd { if((self=[super init])){_fd=fd;_pkt=0;} return self; }
static void AppendKV(NSMutableData *d, NSString *k, NSData *v){
    uint64_t kl=k.length; [d appendBytes:&kl length:8]; [d appendData:[k dataUsingEncoding:NSUTF8StringEncoding]];
    uint64_t vl=v.length; [d appendBytes:&vl length:8]; [d appendData:v];
}
static void AppendU64(NSMutableData *d, NSString *k, uint64_t v){ uint64_t b=v; AppendKV(d,k,[NSData dataWithBytes:&b length:8]); }
- (nullable NSData *)request:(uint64_t)op payload:(NSData *)payload op:(uint64_t*)outOp err:(NSError**)err {
    uint64_t thisLen=40+payload.length;
    NSMutableData *buf=[NSMutableData data];
    [buf appendBytes:kAFC length:8];
    uint64_t ent=thisLen,t=thisLen,n=_pkt++,o=op;
    [buf appendBytes:&ent length:8]; [buf appendBytes:&t length:8];
    [buf appendBytes:&n length:8]; [buf appendBytes:&o length:8];
    [buf appendData:payload];
    const uint8_t *p=buf.bytes; NSUInteger left=buf.length;
    while(left){ ssize_t r=send(_fd,p,left,0); if(r<=0){ if(err)*err=[NSError errorWithDomain:@"afc" code:r userInfo:nil]; return nil; } p+=r; left-=r; }
    uint8_t hdr[40]; size_t got=0;
    while(got<40){ ssize_t r=recv(_fd,hdr+got,40-got,0); if(r<=0){ if(err)*err=[NSError errorWithDomain:@"afc" code:r userInfo:nil]; return nil; } got+=r; }
    if(memcmp(hdr,kAFC,8)){ if(err)*err=[NSError errorWithDomain:@"afc" code:200 userInfo:nil]; return nil; }
    uint64_t tl; memcpy(&tl,hdr+16,8); uint64_t rop; memcpy(&rop,hdr+32,8);
    if(tl<40||tl>64*1024*1024){ if(err)*err=[NSError errorWithDomain:@"afc" code:201 userInfo:nil]; return nil; }
    NSMutableData *body=[NSMutableData dataWithLength:tl-40];
    got=0; while(got<body.length){ ssize_t r=recv(_fd,(uint8_t*)body.mutableBytes+got,body.length-got,0); if(r<=0){ if(err)*err=[NSError errorWithDomain:@"afc" code:r userInfo:nil]; return nil; } got+=r; }
    if(outOp)*outOp=rop; return body;
}
- (BOOL)fileOpen:(NSString *)path mode:(uint64_t)mode handle:(uint64_t *)outHandle error:(NSError **)err {
    NSMutableData *p=[NSMutableData data];
    AppendKV(p,@"path",[path dataUsingEncoding:NSUTF8StringEncoding]); AppendU64(p,@"mode",mode);
    uint64_t op; NSData *b=[self request:AFC_OP_FILE_OPEN payload:p op:&op err:err];
    if(!b) return NO;
    if(op!=AFC_OP_FILE_OPEN_RESULT){ if(err)*err=[NSError errorWithDomain:@"afc" code:(NSInteger)op userInfo:nil]; return NO; }
    if(b.length<8+5+8){ if(err)*err=[NSError errorWithDomain:@"afc" code:203 userInfo:nil]; return NO; }
    const uint8_t *bb=b.bytes; uint64_t kl; memcpy(&kl,bb,8); uint64_t h; memcpy(&h,bb+16+kl,8);
    if(outHandle)*outHandle=h; return YES;
}
- (BOOL)fileWrite:(uint64_t)h data:(NSData *)data error:(NSError **)err {
    NSMutableData *p=[NSMutableData data]; AppendU64(p,@"handle",h); AppendKV(p,@"data",data);
    uint64_t op; NSData *b=[self request:AFC_OP_FILE_WRITE payload:p op:&op err:err];
    return b && op==AFC_OP_STATUS;
}
- (BOOL)fileClose:(uint64_t)h error:(NSError **)err {
    NSMutableData *p=[NSMutableData data]; AppendU64(p,@"handle",h);
    uint64_t op; NSData *b=[self request:AFC_OP_FILE_CLOSE payload:p op:&op err:err];
    return b && op==AFC_OP_STATUS;
}
- (BOOL)removePath:(NSString *)path error:(NSError **)err {
    NSMutableData *p=[NSMutableData data]; AppendKV(p,@"path",[path dataUsingEncoding:NSUTF8StringEncoding]);
    uint64_t op; NSData *b=[self request:AFC_OP_REMOVE_PATH payload:p op:&op err:err];
    return b && op==AFC_OP_STATUS;
}
- (BOOL)makeDirectory:(NSString *)path error:(NSError **)err {
    NSMutableData *p=[NSMutableData data]; AppendKV(p,@"path",[path dataUsingEncoding:NSUTF8StringEncoding]);
    uint64_t op; NSData *b=[self request:AFC_OP_MAKE_DIR payload:p op:&op err:err];
    return b && op==AFC_OP_STATUS;
}
- (BOOL)renamePath:(NSString *)from to:(NSString *)to error:(NSError **)err {
    NSMutableData *p=[NSMutableData data];
    AppendKV(p,@"from",[from dataUsingEncoding:NSUTF8StringEncoding]);
    AppendKV(p,@"to",[to dataUsingEncoding:NSUTF8StringEncoding]);
    uint64_t op; NSData *b=[self request:AFC_OP_RENAME_PATH payload:p op:&op err:err];
    return b && op==AFC_OP_STATUS;
}
- (NSArray<NSString *> *)readDirectory:(NSString *)path error:(NSError **)err {
    NSMutableData *p=[NSMutableData data]; AppendKV(p,@"path",[path dataUsingEncoding:NSUTF8StringEncoding]);
    uint64_t op; NSData *b=[self request:AFC_OP_READ_DIR payload:p op:&op err:err];
    if(!b) return nil;
    NSMutableArray *out=[NSMutableArray array]; size_t o=0; const uint8_t *bb=b.bytes;
    while(o+8<=b.length){
        uint64_t kl; memcpy(&kl,bb+o,8); o+=8;
        if(o+kl+8>b.length) break;
        NSString *name=[[NSString alloc] initWithBytes:bb+o length:(NSUInteger)kl encoding:NSUTF8StringEncoding]; o+=kl;
        uint64_t vl; memcpy(&vl,bb+o,8); o+=8; if(o+vl>b.length) break; o+=vl;
        if(name)[out addObject:name];
    }
    return out;
}
@end
