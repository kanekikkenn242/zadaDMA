import struct, sys, re, collections

path = sys.argv[1]
data = open(path,'rb').read()
symoff=9004912; nsyms=74969; stroff=10216376; strsize=5763744
strtab = data[stroff:stroff+strsize]

def s(idx):
    e = strtab.find(b'\0', idx)
    return strtab[idx:e].decode(errors='replace')

syms=[]
for i in range(nsyms):
    o=symoff+i*16
    n_strx,n_type,n_sect,n_desc,n_value=struct.unpack_from('<IBBHQ',data,o)
    syms.append((s(n_strx),n_type,n_sect,n_value))

open(sys.argv[2],'w',encoding='utf-8').write('\n'.join(x[0] for x in syms))
print("symbols:",len(syms))

# categorize
mods=collections.Counter()
for name,t,sec,v in syms:
    if name.startswith('_$s'):
        m=re.match(r'_\$s(\d+)', name)
        mods['swift:'+(m.group(1) if m else '?')]+=1
    elif name.startswith('_$S'):
        pass
    elif name.startswith('_OBJC_'):
        mods['objc-meta']+=1
    elif name.startswith('_swift_'):
        mods['swift-runtime']+=1
    elif name.startswith('_objc_'):
        mods['objc-runtime']+=1
    elif name.startswith('___'):
        mods['c-runtime']+=1
    elif name.startswith('_'):
        mods['c/other']+=1
    else:
        mods['none']+=1
print(mods.most_common(20))

# print non-stdlib-ish symbols
filtered=[x[0] for x in syms if not x[0].startswith(('_$s','_$S','_swift_','_objc_','___','_OBJC_'))]
print("non-swift-stdlib symbols:", len(filtered))
open(sys.argv[3],'w',encoding='utf-8').write('\n'.join(filtered))
