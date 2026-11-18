import struct
p=r'extracted\Payload\X.app\X'
d=open(p,'rb').read()
def sec(name):
    # hardcoded from earlier
    return {'objc_classname':(0x708c60,0x4f0),'objc_methname':(0x706be0,0x2075),'objc_methtype':(0x709150,0x698),
            'classlist':(0x8454f0,0xc0),'protolist':(0x8455b0,0x30),'selrefs':(0x849ba8,0x928),'classrefs':(0x84a500,0x218)}[name]
o,s=sec('objc_classname'); print("== ObjC class names ==")
print('\n'.join(x.decode() for x in d[o:o+s].split(b'\0') if x))
o,s=sec('objc_methname'); print("\n== ObjC method names ==")
print('\n'.join(x.decode() for x in d[o:o+s].split(b'\0') if x))
o,s=sec('objc_methtype'); print("\n== ObjC method types ==")
print('\n'.join(x.decode() for x in d[o:o+s].split(b'\0') if x))
