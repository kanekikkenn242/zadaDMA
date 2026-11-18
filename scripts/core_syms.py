lines=[l.strip() for l in open('symbols.txt',encoding='utf-8')]
for t in ['PatchPackageCodec','PatchTransaction','LicenseGate','AuthorizationCoordinator','DevicePatchService','RemotePatchStore','PatchProjectStore','PatchDraftService','PatchRestorer','FileReplacementService','KernelExploit']:
    pre='_$s1X'+str(len(t))+t
    hits=[l for l in lines if l.startswith(pre)]
    print('====',t,len(hits))
    for h in hits:
        if 'SwiftUI' in h or 'TupleView' in h or 'ModifiedContent' in h: continue
        print('  ',h[len(pre):][:220])
