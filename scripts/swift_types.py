import re, collections, sys

syms=[l.strip() for l in open('symbols.txt',encoding='utf-8')]
mods = {'X'}
types=collections.Counter()
methods=collections.defaultdict(list)

def parse_ident(s,i):
    j=i
    while j<len(s) and s[j].isdigit(): j+=1
    if j==i: return None,j
    n=int(s[i:j])
    name=s[j:j+n]
    if len(name)!=n or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name):
        return None,j
    return name,j+n

for s in syms:
    if not s.startswith('_$s'): continue
    body=s[3:]
    if not body or not body[0].isdigit(): continue
    # module
    j=0
    while j<len(body) and body[j].isdigit(): j+=1
    if j==0: continue
    n=int(body[:j]); mod=body[j:j+n]
    if mod!='X': continue
    i=j+n
    path=[]
    while True:
        name,k=parse_ident(body,i)
        if not name: break
        path.append(name); i=k
    if path:
        types['.'.join(path)]+=1
        methods['.'.join(path)].append(body[i:])

print("unique type paths:",len(types))
for t,c in types.most_common(400):
    print(f"{c:4d}  {t}")
