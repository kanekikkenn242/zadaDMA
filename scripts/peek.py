import sys,re
lines=[l.strip() for l in open('symbols.txt',encoding='utf-8')]
needle=sys.argv[1]
hits=[l for l in lines if needle in l]
print("count",len(hits))
def dec(s):
    # take after _$s and print length-prefixed identifiers
    out=[];i=3
    while i<len(s):
        if s[i].isdigit():
            j=i
            while j<len(s) and s[j].isdigit(): j+=1
            n=int(s[i:j]); name=s[j:j+n]
            if len(name)==n and re.fullmatch(r'[A-Za-z_$0-9]+',name):
                out.append(name); i=j+n; continue
        # operator chars
        if s[i] in 'OPFVC': out.append(s[i]); i+=1; continue
        i+=1
    return ' · '.join(out)
seen=set()
for h in hits:
    d=dec(h)
    if d not in seen:
        seen.add(d); print(d)
