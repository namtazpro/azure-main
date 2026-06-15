# GSA lifecycle — batch analysis & result extraction

Automation for **Oasys GSA** (structural / FEA software) that opens models,
runs the solver, and extracts results — designed for unattended batch and CI
use.

> Oasys GSA is a **licensed Windows desktop engine**. There is no cloud REST
> API: integration means driving the locally installed application. This
> project uses the **GSA COM API** through `pywin32`, exactly as in the
> [official Oasys Python sample](https://github.com/arup-group/oasys-api-samples/tree/main/GSA/COM%20API/Python).

## Requirements

- Windows (x64)
- Oasys GSA installed **and licensed** (default target: 10.2)
- Python 3.9+ with `pip install -r requirements.txt`

The COM ProgID is version-bound (`Gsa_10_2.ComAuto`); pass `--gsa-version` to
target another installed version.

## Usage

```powershell
# Analyse every .gwb in a folder, write CSV results to .\out
python -m gsa_batch.cli --input models --out out

# Specific files, JSON output, GSA 10.1
python -m gsa_batch.cli a.gwb b.gwb --out out --format json --gsa-version 10.1
```

Exit code is non-zero if any model fails, so it gates a CI pipeline.

### As a library

```python
from pathlib import Path
from gsa_batch import run_batch
from gsa_batch.results import ResultSpec

results = run_batch(
    models=list(Path("models").glob("*.gwb")),
    out_dir="out",
    specs=(ResultSpec(name="elem_force", entity_type="ELEM", result_header=18,
                      columns=("fx", "fy", "fz", "mxx", "myy", "mzz")),),
)
for r in results:
    print(r.model.name, "OK" if r.ok else r.error)
```

## How it works

The verbs below are the verified COM pipeline (`Gsa_10_2.ComAuto`):

| Step              | COM call                          |
|-------------------|-----------------------------------|
| Open model        | `Open(path)`                      |
| Clear old results | `Delete("RESULTS")`               |
| Run all tasks     | `Analyse()`                       |
| Save analysed     | `SaveAs(path)`                    |
| Extract results   | `Output_Init(...)` + `Output_Extract(...)` |
| Close             | `Close()`                         |

The COM object is **not** thread-safe, so models are processed sequentially in
a single session.

> ⚠️ **Result header codes** in `gsa_batch/results.py` (e.g. node displacement,
> element force) vary by GSA version. Confirm the exact codes for your install
> in the [GSA COM reference](https://docs.oasys-software.com/structural/gsa/references/com-api/)
> and adjust `ResultSpec.result_header` accordingly.

## CI

`.github/workflows/gsa-batch.yml` (at the repo root) runs this on a
**self-hosted Windows runner** labelled `gsa` that has GSA installed and
licensed. GitHub-hosted runners cannot run GSA (no install, no licence).

## Layout

```
gsa-lifecycle/
├── gsa_batch/
│   ├── com_session.py   # context-managed COM wrapper (open/analyse/save/close)
│   ├── results.py       # Output_Init/Output_Extract -> CSV/JSON
│   ├── runner.py        # batch orchestration over many models
│   └── cli.py           # `python -m gsa_batch.cli`
├── requirements.txt
└── models/              # put your .gwb files here (create as needed)
```

## Alternative integration paths (not used here)

- **.NET `GsaAPI.dll`** — runs GSA *headless* (.NET Framework 4.8, x64). Richer
  results API; best for a C# service wrapping GSA.
- **Grasshopper (GSA-GH)** — parametric Rhino/Grasshopper ↔ GSA workflows.
- **GWA text files** — import/export model data without the COM object.
