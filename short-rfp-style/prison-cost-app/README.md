# Contoso Constructions — Prison Cost Estimator

A single-page React app for the C-suite. Enter the planned prisoner capacity and
instantly generate an indicative capital cost plan, accommodation schedule,
programme and site area — ready to walk through with UK government or local
council executives.

## Model

Formulas and benchmark rates are lifted directly from the two sheets of
`Prison_Cost_Model_Combined.xlsx` (HMP Millsike reference case):

- **Houseblocks** = ⌈prisoners / 240⌉
- **Accommodation schedule** — fixed buildings plus per-houseblock scaling
  (Houseblock 5,072 m²/HB, Workshop 1,210 m²/HB) and per-6-HB CASU/OPU clusters
- **Required GIFA** = sum of the building schedule (reconciles to 56,706 m² at
  1,440 prisoners)
- **Programme** = 122 + (Houseblocks − 1) × 4 + 12 weeks
- **Site area** = 51 acres × (prisoners / 1,440)
- **Cost plan** = each Background £/m² rate × Required GIFA
  (reconciles to £467,852,285.94 at 1,440 prisoners)

The complete rate table lives in [src/model.ts](src/model.ts).

## Run

```powershell
cd prison-cost-app
npm install
npm run dev
```

Then open http://localhost:5173.

## Build

```powershell
npm run build
npm run preview
```

The static bundle in `dist/` can be dropped on any web host or SharePoint site.
