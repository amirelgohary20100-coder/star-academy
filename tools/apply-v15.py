import re,sys
p=sys.argv[1]; part=open(sys.argv[2],encoding="utf-8").read().strip()
h=open(p,encoding="utf-8").read()
h=re.sub(r"<!--v15z-start-->.*?<!--v15z-end-->\n?","",h,flags=re.S)
i=h.rfind("</body>"); assert i>0
h=h[:i]+part+"\n"+h[i:]
open(p,"w",encoding="utf-8").write(h)
print("ok",len(h))
