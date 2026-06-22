import json, glob, os, re
from collections import Counter

parts = sorted(glob.glob('_qcm_parts/ch*.json'), key=lambda p: int(re.search(r'ch(\d+)', p).group(1)))
all_q = []
for p in parts:
    with open(p, 'r', encoding='utf-8') as f:
        all_q.extend(json.load(f)['questions'])

os.makedirs('qcm', exist_ok=True)
out_path = 'qcm/questions_bank_m7_complet.json'
with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump({'questions': all_q}, f, ensure_ascii=False, indent=2)

c = Counter(q['correct'] for q in all_q)
print(f"Total: {len(all_q)} questions -> {out_path}")
print(f"A={c.get('A',0)}  B={c.get('B',0)}  C={c.get('C',0)}")
