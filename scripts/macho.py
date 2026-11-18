import struct, sys, json

path = sys.argv[1]
data = open(path,'rb').read()

CPU = {0x0100000c:'arm64', 0x01000007:'x86_64', 12:'arm', 7:'x86'}
FILETYPE = {1:'OBJECT',2:'EXECUTE',6:'DYLIB',8:'BUNDLE',11:'KEXT'}

def rd(fmt, off):
    return struct.unpack_from(fmt, data, off)

magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags, reserved = rd('<IiIIIII I', 0)
print(f"magic=0x{magic:08x} cpu={CPU.get(cputype,cputype)} subtype={cpusub} filetype={FILETYPE.get(filetype,filetype)} ncmds={ncmds} sizeofcmds={sizeofcmds} flags=0x{flags:08x}")

off = 32
lcs=[]
dylibs=[]
segs=[]
rpaths=[]
for i in range(ncmds):
    cmd, cmdsize = rd('<II', off)
    body = data[off:off+cmdsize]
    lcs.append((cmd,cmdsize,off))
    if cmd in (0x19,):  # LC_SEGMENT_64
        segname = body[8:24].split(b'\0')[0].decode()
        vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<QQQQ', body, 24)
        maxprot, initprot, nsects, sflags = struct.unpack_from('<IIII', body, 56)
        segs.append(dict(name=segname, vmaddr=vmaddr, vmsize=vmsize, fileoff=fileoff, filesize=filesize, maxprot=maxprot, initprot=initprot, nsects=nsects))
    elif cmd in (0xc, 0xd, 0x8000001f, 0x18f):  # load_dylib/id/rpath/upward
        nameoff = struct.unpack_from('<I', body, 8)[0]
        name = body[nameoff:].split(b'\0')[0].decode(errors='replace')
        if cmd == 0xc: dylibs.append(name)
        elif cmd == 0x8000001f or cmd == 0x18f: rpaths.append(name)
    off += cmdsize

print("\n== Load commands ==")
names={0x19:'LC_SEGMENT_64',0x2:'LC_SYMTAB',0xb:'LC_DYSYMTAB',0xc:'LC_LOAD_DYLIB',0xd:'LC_ID_DYLIB',
 0xe:'LC_LOAD_DYLINKER',0x1d:'LC_CODE_SIGNATURE',0x21:'LC_ENCRYPTION_INFO',0x2c:'LC_ENCRYPTION_INFO_64',
 0x22:'LC_DYLD_INFO',0x80000022:'LC_DYLD_INFO_ONLY',0x26:'LC_FUNCTION_STARTS',0x29:'LC_DATA_IN_CODE',
 0x32:'LC_BUILD_VERSION',0x24:'LC_VERSION_MIN_IPHONEOS',0x28:'LC_MAIN',0x1b:'LC_UUID',
 0x80000028:'LC_MAIN',0x80000034:'LC_DYLD_EXPORTS_TRIE',0x80000033:'LC_DYLD_CHAINED_FIXUPS',
 0x8000001f:'LC_RPATH',0x1c:'LC_LOAD_WEAK_DYLIB',0x80000018:'LC_LOAD_WEAK_DYLIB',0x1f:'LC_REEXPORT_DYLIB',
 0x8000001e:'LC_REEXPORT_DYLIB',0x2b:'LC_SOURCE_VERSION',0x2a:'LC_ENCRYPTION_INFO_64'}
for cmd,size,o in lcs:
    print(f"  {names.get(cmd,hex(cmd)):28s} size={size}")
    if cmd==0x32:
        plat,minos,sdk,ntools=struct.unpack_from('<IIII', data, o+8)
        print(f"      platform={plat} minos={minos>>16}.{(minos>>8)&255}.{minos&255} sdk={sdk>>16}.{(sdk>>8)&255}.{sdk&255} ntools={ntools}")
    if cmd==0x2c or cmd==0x21:
        cryptoff,cryptsize,cryptid=struct.unpack_from('<III', data, o+8)
        print(f"      cryptoff={cryptoff} cryptsize={cryptsize} cryptid={cryptid}")
    if cmd==0x28:
        entryoff,stacksize=struct.unpack_from('<QQ', data, o+8)
        print(f"      entryoff={entryoff} stacksize={stacksize}")
    if cmd==0x1b:
        print("      uuid="+data[o+8:o+24].hex())
    if cmd==0x2:
        symoff,nsyms,stroff,strsize=struct.unpack_from('<IIII', data, o+8)
        print(f"      symoff={symoff} nsyms={nsyms} stroff={stroff} strsize={strsize}")
    if cmd==0xb:
        vals=struct.unpack_from('<18I', data, o+8)
        print(f"      ilocalsym={vals[0]} nlocalsym={vals[1]} iextdefsym={vals[2]} nextdefsym={vals[3]} iundefsym={vals[4]} nundefsym={vals[5]}")
    if cmd==0x1d:
        dataoff,datasize=struct.unpack_from('<II', data, o+8)
        print(f"      dataoff={dataoff} datasize={datasize}")

print("\n== Segments ==")
for s in segs:
    print(f"  {s['name']:16s} vm=0x{s['vmaddr']:x} size=0x{s['vmsize']:x} off=0x{s['fileoff']:x} filesize=0x{s['filesize']:x} prot={s['initprot']} sects={s['nsects']}")

print("\n== Dylibs ==")
for d in dylibs: print("  "+d)
print("\n== Rpaths ==")
for d in rpaths: print("  "+d)

# sections
print("\n== Sections ==")
off=32
for i in range(ncmds):
    cmd,cmdsize=rd('<II',off)
    if cmd==0x19:
        body=data[off:off+cmdsize]
        segname=body[8:24].split(b'\0')[0].decode()
        nsects=struct.unpack_from('<I',body,64)[0]
        p=72
        for j in range(nsects):
            sectname=body[p:p+16].split(b'\0')[0].decode()
            sg=body[p+16:p+32].split(b'\0')[0].decode()
            addr,size=struct.unpack_from('<QQ',body,p+32)
            offset,align,reloff,nreloc,flags2=struct.unpack_from('<IIIII',body,p+48)
            print(f"  {segname},{sectname:22s} addr=0x{addr:x} size=0x{size:x} off=0x{offset:x} align={align} flags=0x{flags2:x}")
            p+=80
    off+=cmdsize
