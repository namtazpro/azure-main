---
title: Building the Evaluation Dataset (Golden / Ground-Truth)
description: Guidance for building the golden dataset needed to evaluate the scenario classification agent, including record schema, sourcing, labelling, sampling, splits, quality, and governance.
author: Vincent Rouet
ms.date: 2026-07-29
ms.topic: how-to
keywords:
  - golden dataset
  - ground truth
  - labelling
  - scenario classification
  - jsonl
  - foundry datasets
estimated_reading_time: 11
---

## Building the evaluation dataset

The evaluation strategy in [Foundry Evaluations](../foundry-evaluations.md) depends on a **golden (ground-truth) dataset**: a curated, versioned set of real logistics emails, each labelled with the **correct scenario**. This page explains how to build that dataset for the [scenario classification](4a-scenario-classification.md) use case.

The dataset is the **single source of truth** for measuring whether a prompt or model change improves or regresses classification. Without it, no meaningful evaluation is possible.

## What one record contains

Each record captures the **exact inputs production sends to the classifier** plus the correct label and useful metadata.

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Stable unique identifier (for traceability and de-duplication) |
| `subject` | Yes | Email subject (cleaned as in production) |
| `body` | Yes | Email body (signatures and noise removed by the same pre-processing) |
| `timestamp` | Yes | When the email was received |
| `sender` | Yes | Sender of the email |
| `ground_truth` | Yes | Correct scenario label: `scenario_1` ... `scenario_12` or `unknown` |
| `conversation_id` | Recommended | Microsoft Graph conversation ID - keep threads together across splits |
| `message_id` | Recommended | Microsoft Graph message ID |
| `bot_scenario` | Optional | Original bot prediction (for auditing agreement) |
| `specialist_scenario` | Optional | Specialist reclassification, if any |
| `correct_by_bot` | Optional | SME flag: was the bot right (`yes`/`no`) |
| `source_mailbox` | Optional | Mailbox the email was redirected from |

### JSONL example

Foundry Evaluations consume **JSONL** (one JSON object per line):

```json
{"id": "eml-00142", "subject": "Truck arrived at warehouse Sibiu for loading", "body": "The truck arrived in Warehouse Sibiu for loading with this reference ...", "timestamp": "2026-07-14T09:12:00Z", "sender": "carrier@example.com", "ground_truth": "unknown", "conversation_id": "AAQk...", "bot_scenario": "scenario_2", "specialist_scenario": "unknown", "correct_by_bot": "no"}
{"id": "eml-00143", "subject": "Where is my truck?", "body": "Please update me on consignment 998877 starting from Rotterdam ...", "timestamp": "2026-07-14T10:01:00Z", "sender": "ops@example.com", "ground_truth": "scenario_1", "conversation_id": "AAQk...", "bot_scenario": "scenario_1", "correct_by_bot": "yes"}
```

## Where the data comes from

From the current state described in [4.a](4a-scenario-classification.md):

- **~682 emails flagged incorrect** by the SME - the bot got them wrong, but the *correct* label is not yet recorded. These need correct labels before they are usable.
- **~1000 emails known to be correct** - already have a trusted label.
- **Preferred approach (agreed with product):** take a **random sample from the emails the bot classified as automated**, and have the SME provide the correct classification for that sample. This gives a balanced, representative snapshot rather than only the failure cases.

**Target size:** roughly **1000-1200 labelled emails** to begin, refreshed on a **periodic basis** so performance can be monitored over time.

The raw source is the conversation history already stored in **Cosmos DB** (message and conversation IDs), so records can be exported with their metadata intact.

## Labelling process and guidelines

Quality of labels determines the ceiling on evaluation quality. The transcript flagged that specialist reclassification quality is on a **downtrend** and that specialists sometimes pick **unknown** when unsure - so treat labelling deliberately:

- **Use SME labels as ground truth**, not raw specialist reclassifications. Route ambiguous cases to the SME for adjudication.
- **Constrain the label set** to the 13 categories (12 scenarios + `unknown`). No free text.
- **Define "unknown" tightly.** Because unknown has no clear boundary today, agree explicit rules for when a case is genuinely unknown versus a weakly-worded example of a known scenario. Capture the SME's **reasoning** for edge cases so it can later inform the prompt.
- **Measure agreement.** Have a second labeller review a subset and track inter-annotator agreement; investigate disagreements.
- **Avoid overlap traps.** For overlapping scenarios (for example loading reference vs unloading reference), document decisive cues so labels stay consistent.

## Sampling and class balance

- **Stratify** across all 12 scenarios plus unknown so every class - especially the weak **unknown** class - has enough examples to produce a stable recall estimate.
- Include a deliberate share of **hard / ambiguous** emails (overlapping wording, sparse "where is my truck?" messages), since these drive the current accuracy problem.
- Record the **class distribution** and revisit it at each refresh; do not let one scenario dominate.

## Splits and leakage

- **Keep whole conversation threads together.** A follow-up email inherits its parent's scenario, so splitting a thread across dataset partitions leaks information. Split by `conversation_id`, not by individual email.
- Maintain a **stable held-out test set** for the regression gate and a separate **development set** for prompt iteration, so you do not tune against the gate.
- Freeze and **version** each dataset revision (see governance) so results are comparable across runs.

## Data quality

- **De-duplicate** on `id` and near-duplicate bodies.
- **Apply the same pre-processing** used in production (clean subject/body, strip signatures) so the dataset matches what the model actually sees.
- **Handle PII / confidentiality.** This is real Contoso operational data. Minimise or mask personal data where possible, restrict access, and keep raw email exports out of source control - the repository already ignores the `transcipts/` folder for this reason; apply the same discipline to any raw email dumps or dataset files containing customer data.

## Governance and lifecycle

- **Version datasets in Foundry.** `project_client.datasets.upload_file(name=..., version=...)` versions each revision; reference a specific version in evaluation runs for reproducibility.
- **Refresh periodically.** Fold newly SME-labelled production samples into a new dataset version so the benchmark stays representative as email patterns drift.
- **Ownership.** The SME (and lead verifier) owns label correctness; the delivery team owns export, formatting, and upload. See stakeholders in [4.a](4a-scenario-classification.md).
- **Change log.** Track what changed between versions (new scenarios rolled out, relabelled cases, size) alongside the evaluation metrics for each version.

## From export to Foundry

1. Export labelled records from Cosmos DB with the fields above.
2. Apply production pre-processing to `subject` and `body`.
3. Split by `conversation_id` into dev and held-out test sets.
4. Write each split to **JSONL**.
5. Upload with a version tag:

```python
dataset = project_client.datasets.upload_file(
    name="scenario-golden-test",
    version="2026.07",
    file_path="golden_test.jsonl",
)
```

Then follow [Foundry Evaluations](../foundry-evaluations.md) to run the evaluation against it.

## Checklist

- [ ] Record schema agreed (inputs + `ground_truth` + metadata).
- [ ] Source sample selected (random sample of bot-automated emails, plus known-correct and relabelled incorrect cases).
- [ ] ~1000-1200 SME-labelled emails for the first version.
- [ ] "Unknown" definition and edge-case reasoning documented.
- [ ] Stratified across all 13 categories, hard cases included.
- [ ] Split by conversation to prevent leakage; stable held-out test set.
- [ ] De-duplicated, production pre-processing applied, PII handled.
- [ ] Versioned in Foundry with a change log; periodic refresh scheduled.
