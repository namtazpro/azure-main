# Coding Agent Instructions

This project was built with the microsoft-foundry skill. Before working on or
answering questions about Foundry agents, read the microsoft-foundry skill
first.

## Architecture invariants

- `knowledge/travel-policies.json` is the source of truth for the Search index.
- The hosted agent uses the `travel-policy-full` toolbox (Foundry IQ + Work IQ).
- The web app uses the `knowledge-base` toolbox only.
- Authentication is keyless: managed identity for Azure resources and user
  Entra passthrough for Work IQ.
- Never commit `.env`, `.azure`, credentials, endpoints containing secrets, or
  app-registration secrets.

## Deployment lifecycle

Use `azd provision`, then `azd deploy`. Do not deploy with ad-hoc portal changes
that are not represented in Bicep or the post-provision hooks.