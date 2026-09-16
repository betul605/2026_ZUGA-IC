import sys
b,o,n=sys.argv[1],sys.argv[2],int(sys.argv[3])
d=open(b,'rb').read()
out=[('%08x'%int.from_bytes(d[i*4:i*4+4],'little')) if i*4<len(d) else '00000000' for i in range(n)]
open(o,'w').write('\n'.join(out)+'\n')
print('%s: %d word (%d byte)'%(o,(len(d)+3)//4,len(d)))
