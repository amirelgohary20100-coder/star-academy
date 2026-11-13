import re,sys
# Re-apply the Islamic studies block (v16) onto any newer index.html. Idempotent. Must sit AFTER the v15 block.
p=sys.argv[1]; part=open(sys.argv[2],encoding="utf-8").read().strip()
h=open(p,encoding="utf-8").read()
h=re.sub(r"<!--v16isl-start-->.*?<!--v16isl-end-->\n?","",h,flags=re.S)
i=h.rfind("</body>"); assert i>0
h=h[:i]+part+"\n"+h[i:]
open(p,"w",encoding="utf-8").write(h)
print("ok",len(h))
