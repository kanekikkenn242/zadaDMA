lines=[l.strip() for l in open('symbols.txt',encoding='utf-8')]
hits=[l for l in lines if 'CryptoKit' in l and l.startswith('_$s1X')]
print("count",len(hits))
for h in hits[:120]: print(h)
