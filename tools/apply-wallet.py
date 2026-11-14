"""v19.1 wallet fix: top counter shows stars left to spend, two-tap buy, spent self-repair.
Usage: python3 tools/apply-wallet.py index.html   (idempotent)"""
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
if "/*wallet-fix*/" in s: print("already applied"); sys.exit()
R = [
 ("const wallet = () => S.stars - S.spent;",
  """/*wallet-fix*/const wallet = () => Math.max(0, (S.stars||0) - (S.spent||0));
function ownedCost(){ let t=0; try{
  for(const id of Object.keys(S.base.owned||{})) if(S.base.owned[id]) for(const c of Object.values(HITEMS)){ const it=c[1].find(x=>x[0]===id); if(it){ t+=it[2]; break; } }
  for(const k of Object.keys(S.owned||{})) if(S.owned[k]){ const i=k.indexOf(":"), g=WARDROBE[k.slice(0,i)], it=g&&g.items.find(x=>x[0]===k.slice(i+1)); if(it) t+=it[2]; }
 }catch(e){} return t; }
function fixWallet(){ const oc=ownedCost(); if(!(S.spent>=0) || S.spent>oc) S.spent=oc; }
let buyAsk=null, buyAskT=0;
function askBuy(id,cost){ if(buyAsk===id){ buyAsk=null; return true; } buyAsk=id; clearTimeout(buyAskT); buyAskT=setTimeout(()=>{buyAsk=null;},6000); sfx.tap(); speak(`Tap again to buy it for ${cost} stars.`); toast(`Tap again to buy for ★ ${cost} (you have ★ ${wallet()})`); return false; }"""),
 ('$("#dockStars").textContent = S.stars;', 'fixWallet(); $("#dockStars").textContent = wallet();'),
 ('<span class="pill" title="Stars">', '<span class="pill" title="Stars to spend">'),
 ("S.spent+=cost; B.owned[id]=true;", "if(!askBuy(id,cost)) return; S.spent+=cost; B.owned[id]=true;"),
 ("S.spent+=cost; S.owned[key]=true;", "if(!askBuy(key,cost)) return; S.spent+=cost; S.owned[key]=true;"),
 ("stars to spend.${next!==undefined?", "stars to spend. You earned ★ ${S.stars} and used ★ ${S.spent} on your home and clothes.${next!==undefined?"),
 ("Total stars: <b>${S.stars}</b>", "Total stars earned: <b>${S.stars}</b> · Used in My Home and Dress up: <b>${S.spent}</b> · Left to spend: <b>${wallet()}</b>"),
]
for a,b in R:
    n = s.count(a)
    if n != 1: sys.exit(f"pattern found {n} times: {a[:60]}")
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s); print("applied")
