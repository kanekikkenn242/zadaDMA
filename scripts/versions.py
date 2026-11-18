import re,collections
lines=[l.rstrip('\n') for l in open('allstrings.txt',encoding='utf-8',errors='replace')]
ver=collections.Counter()
build=collections.Counter()
for l in lines:
    if re.fullmatch(r'\d{2}\.\d{1,2}(\.\d{1,2})?', l): ver[l]+=1
    if re.fullmatch(r'\d{2}[A-Z]\d{2,4}[a-z]?', l): build[l]+=1
print("VERSIONS:", sorted(ver.items(), key=lambda x:[int(p) for p in x[0].split('.')]))
print("BUILDS:", sorted(build.items()))
# lines containing supported / version lists
for l in lines:
    if ('supported' in l.lower() or 'verified' in l.lower()) and len(l)<200:
        print("TXT:",l)
