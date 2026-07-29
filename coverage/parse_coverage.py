#!/usr/bin/env python3
# merged.dat -> gercek satir/dal/toggle coverage yuzdeleri (yalnizca rtl/ tasarim)
import re, collections, sys
S1='\x01'; S2='\x02'
path = sys.argv[1] if len(sys.argv)>1 else 'coverage/merged.dat'
lt=collections.Counter(); lc=collections.Counter()
bt=collections.Counter(); bc=collections.Counter()
tt=collections.Counter(); tc=collections.Counter()
for ln in open(path, encoding='latin-1'):
    if not ln.startswith('C '): continue
    m=re.match(r"C '(.*)' (\d+)\s*$", ln)
    if not m: continue
    body,cnt=m.group(1),int(m.group(2))
    fields=dict(x.split(S2,1) for x in body.split(S1) if S2 in x)
    f=fields.get('f',''); page=fields.get('page','')
    if not f.startswith('rtl/'): continue
    mod=f.split('/')[-1]
    if page.startswith('v_line'):   lt[mod]+=1; lc[mod]+=cnt>0
    elif page.startswith('v_branch'):bt[mod]+=1; bc[mod]+=cnt>0
    elif page.startswith('v_toggle'):tt[mod]+=1; tc[mod]+=cnt>0
mods=sorted(set(list(lt)+list(bt)))
def p(c,t): return f"{100*c/t:.1f}%" if t else "-"
rows=[]
Lc=Lt=Bc=Bt=0
for md in mods:
    Lc+=lc[md];Lt+=lt[md];Bc+=bc[md];Bt+=bt[md]
    rows.append(f"| {md} | {lc[md]}/{lt[md]} {p(lc[md],lt[md])} | {bc[md]}/{bt[md]} {p(bc[md],bt[md])} |")
Tc=sum(tc.values());Tt=sum(tt.values())
print("| Modül | Satır (line) | Dal (branch) |")
print("|---|---|---|")
print("\n".join(rows))
print(f"| **TOPLAM** | **{Lc}/{Lt} {p(Lc,Lt)}** | **{Bc}/{Bt} {p(Bc,Bt)}** |")
print(f"\nToggle toplam: {Tc}/{Tt} {p(Tc,Tt)}")
