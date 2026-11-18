import struct, sys, re, collections

path = sys.argv[1]
data = open(path,'rb').read()

# __cstring
cstr_off=0x653c60; cstr_size=0x20b9c
blob=data[cstr_off:cstr_off+cstr_size]
parts=[p.decode('utf-8','replace') for p in blob.split(b'\0') if len(p)>=4]
print("cstring entries:",len(parts))
open('cstrings.txt','w',encoding='utf-8').write('\n'.join(parts))

# whole file strings >=6 printable
res=[]
cur=bytearray()
for b in data:
    if 32<=b<127:
        cur.append(b)
    else:
        if len(cur)>=6: res.append(cur.decode())
        cur=bytearray()
if len(cur)>=6: res.append(cur.decode())
print("ascii strings:",len(res))
open('allstrings.txt','w',encoding='utf-8').write('\n'.join(res))

# swift module names
syms=[l.strip() for l in open('symbols.txt',encoding='utf-8')]
mods=collections.Counter()
pat=re.compile(r'^_\$s(\d+)')
for s in syms:
    m=pat.match(s)
    if not m: continue
    n=int(m.group(1)); i=m.end()
    mod=s[i:i+n]
    if len(mod)==n and mod.isascii() and mod.isidentifier():
        mods[mod]+=1
print("swift modules:", mods.most_common(40))
