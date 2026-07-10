Based on the screenshots and the workbook we reconstructed, this appears to be a **parametric prison estate cost model** used during the early business case / feasibility stage of a prison construction project.

## My interpretation of how it works

### 1. Start with prisoner capacity

The primary input is:

* **No. of prisoners = 1,440**

Everything else is derived from this.

The model uses a benchmark prison design (possibly based on HMP Millsike, as referenced in the notes) to estimate:

* Gross Internal Floor Area (GIFA)
* Number of houseblocks
* Site acreage
* Programme duration
* Construction cost

***

### 2. Calculate required floor area

The model calculates:

```
Required GIFA = Prisoners × Density Factor
```

In your example:

```
1,440 prisoners
→ 56,706 m² GIFA
```

This implies a density of roughly:

```
56,706 / 1,440
≈ 39.4 m² per prisoner
```

That matches the Background sheet value:

```
Area / prisoner = 39.4
```

***

### 3. Calculate required houseblocks

Background assumptions show:

```
Prisoners (per HB) = 240
```

Therefore:

```
1,440 / 240
= 6 Houseblocks
```

Which matches:

```
No. of Houseblocks req'd = 6
```

***

### 4. Build up the accommodation schedule

The Background sheet contains building components.

Some are:

* Fixed
* Scaled by prisoner numbers
* Scaled by houseblock numbers

Examples:

| Building   | Behaviour                     |
| ---------- | ----------------------------- |
| ERH Core   | Fixed                         |
| Support    | Fixed                         |
| Kitchen    | Fixed                         |
| Workshop   | Variable                      |
| Houseblock | Variable                      |
| CASU       | Fixed until threshold reached |
| OPU        | Fixed until threshold reached |

The notes indicate:

```
Workshop = per additional HB
CASU = 1 additional CASU per 6 HBs
OPU = 1 additional OPU per 6 HBs
```

which suggests scaling rules exist behind the scenes.

***

### 5. Recreate total GIFA

The building areas are added together:

| Building   | GIFA   |
| ---------- | ------ |
| ERH Core   | 3,059  |
| Support    | 770    |
| Kitchen    | 1,926  |
| Workshop   | 7,257  |
| Houseblock | 30,430 |
| etc        |        |

These combine to approximately:

```
56,706 m²
```

which equals the Required GIFA total.

This acts as a validation that the prison layout delivers the required floor area.

***

### 6. Determine programme

The Background sheet contains:

| Assumption                | Value     |
| ------------------------- | --------- |
| Programme (HBs)           | 122 weeks |
| Programme (Stagger)       | 4 weeks   |
| Programme (Commissioning) | 12 weeks  |

The Model sheet note states:

```
Houseblock Duration +
((Number Of Blocks - 1) × 4 Weeks) +
Commissioning
```

For 6 houseblocks:

```
122
+ ((6-1) × 4)
+ 12

= 154 weeks
```

Which exactly matches:

```
Programme (wks) = 154
```

So I'm reasonably confident this is the programme formula.

***

### 7. Calculate site acreage

The model outputs:

```
Required Acres = 51
```

The Background sheet contains:

```
Site area = 143.5
```

This looks like a density conversion based on the Millsike benchmark.

Potentially:

```
56,706 m² GIFA
→ 51 acres site requirement
```

Although without formulas I can't prove the exact calculation.

***

### 8. Calculate cost

The lower section is essentially a cost plan.

The Background sheet provides benchmark rates:

| Element            | £/m²      |
| ------------------ | --------- |
| Substructure       | £395.77   |
| Superstructure Env | £1,420.24 |
| M\&E               | £2,248.64 |
| External Works     | £1,691.68 |
| etc                |           |

The Model sheet converts those rates into actual cost values.

Example:

```
56,706 m² × £119.35
≈ £6.77m
```

Which matches:

```
Profit = £6,767,861
```

Similarly:

```
56,706 × £2,248.64
≈ £127.5m
```

Which matches:

```
M&E = £127,511,380
```

Therefore the cost formula seems to be:

```
Element Cost
=
Cost Rate (£/m²)
×
Required GIFA
```

***

### 9. Total project cost

All cost elements are summed:

```
Profit
+ OH
+ Risk
+ Fees
+ Substructure
+ Superstructure
+ Finishes
+ M&E
+ External Works
+ etc
```

leading to:

```
TOTAL
=
£467,852,285.94
```

***

## In one sentence

This workbook looks like a **benchmark-driven prison feasibility model** where the user enters a prisoner population and the model automatically derives:

1. Required GIFA
2. Number of houseblocks
3. Site acreage
4. Construction programme
5. Full capital cost estimate

using a library of building area assumptions and £/m² benchmark rates derived from a reference prison scheme (likely HMP Millsike). Based on the relationships visible in the screenshots, the model is essentially:

```
Prisoners
    ↓
Required GIFA
    ↓
Houseblocks
    ↓
Building Schedule
    ↓
Programme + Site Area
    ↓
Cost Plan (£/m²)
    ↓
Project Cost
```

using the data contained in the **Background** sheet and producing outputs on the **Model** sheet.
