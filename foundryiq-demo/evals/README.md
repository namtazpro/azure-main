# Evaluation dataset

`data.jsonl` contains deterministic policy facts for smoke and regression
evaluation. Each response should contain every `required_facts` value for the
question. Use the deployed-agent evaluation workflow after deployment:

```powershell
azd ai agent eval generate --dataset .\evals\data.jsonl --no-wait --no-prompt
azd ai agent eval run
```
