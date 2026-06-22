import json
from collections import Counter

with open('qcm/questions_bank_m7_complet.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

errors = []
required = {'question', 'options', 'correct', 'explication', 'source', 'chapter', 'date'}
chapters = Counter()
sources = Counter()

for i, q in enumerate(data['questions']):
    missing = required - set(q.keys())
    if missing:
        errors.append(f"Q{i}: champs manquants {missing}")
    opts = q.get('options', {})
    if set(opts.keys()) != {'A', 'B', 'C'}:
        errors.append(f"Q{i}: options != A/B/C => {sorted(opts.keys())}")
    if q.get('correct') not in {'A', 'B', 'C'}:
        errors.append(f"Q{i}: correct invalide = {q.get('correct')}")
    for k in ('question', 'correct', 'explication', 'source', 'chapter', 'date'):
        if not str(q.get(k, '')).strip():
            errors.append(f"Q{i}: champ vide {k}")
    for k in ('A', 'B', 'C'):
        if not str(opts.get(k, '')).strip():
            errors.append(f"Q{i}: option {k} vide")
    chapters[q.get('chapter', '?')] += 1
    sources[q.get('source', '?')] += 1

print("=== VALIDATION ===")
print(f"Total questions : {len(data['questions'])}")
print(f"Erreurs schema  : {len(errors)}")
for e in errors[:20]:
    print("  -", e)

print()
print("=== Repartition par chapitre ===")
for ch, n in sorted(chapters.items()):
    print(f"  {n:>3}  {ch}")

print()
correct = Counter(q['correct'] for q in data['questions'])
n = len(data['questions'])
print("=== Equilibrage A/B/C ===")
for letter in ('A', 'B', 'C'):
    cnt = correct[letter]
    print(f"  {letter} = {cnt:>3} ({100*cnt/n:.1f}%)")
