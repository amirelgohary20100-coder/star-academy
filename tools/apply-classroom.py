import re,sys
# Re-apply the v20 Classroom-with-Baba block onto any newer index.html. Idempotent. Must sit AFTER the v15 and v16isl blocks.
p=sys.argv[1]; part=open(sys.argv[2],encoding="utf-8").read().strip()
h=open(p,encoding="utf-8").read()
h=re.sub(r"<!--v20cls-start-->.*?<!--v20cls-end-->\n?","",h,flags=re.S)
i=h.rfind("</body>"); assert i>0
h=h[:i]+part+"\n"+h[i:]
open(p,"w",encoding="utf-8").write(h)
print("ok",len(h))
