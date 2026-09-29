# Correlation Token Specification

## Purpose

The correlation token is the **primary key** for linking all milestones of a single
business activity instance across multiple agents, orchestrations, and time.

It replaces BizTalk BAM's ActivityID and continuation tokens with a single,
human-readable, composite identifier.

## Format

```
{Division}-{ObjectType}-{ObjectID}-{Timestamp}
```

### Components

| Component    | Description                              | Format               | Example      |
|-------------|------------------------------------------|----------------------|--------------|
| Division    | Business division acronym                | 2-6 uppercase chars  | `EMEA`       |
| ObjectType  | Business object type code                | 2-4 uppercase chars  | `SO`         |
| ObjectID    | Business object identifier               | Alphanumeric         | `4821`       |
| Timestamp   | Creation timestamp (UTC, compact ISO)    | `yyyyMMddTHHmmssZ`  | `20260714T140103Z` |

### Separator

Hyphen (`-`) separates components.

### Examples

```
EMEA-SO-4821-20260714T140103Z       # EMEA Sales Order 4821
APAC-SO-9012-20260714T083022Z       # APAC Sales Order 9012
AMER-CLM-7744-20260713T221500Z      # Americas Insurance Claim 7744
EMEA-ONB-E2041-20260710T090000Z     # EMEA Employee Onboarding E2041
```

## Rules

1. **Uniqueness** — The combination of all four components guarantees uniqueness
   globally. Even if the same ObjectID is reused across divisions, the Division
   and Timestamp differentiate them.

2. **Immutability** — Once a correlation token is minted at the first milestone,
   it never changes. All subsequent milestones reference it.

3. **Minting** — The token is minted by the BAM interceptor at the first milestone
   of an activity (typically "Received"). The interceptor extracts Division,
   ObjectType, and ObjectID from the agent output, and appends the current UTC
   timestamp.

4. **Propagation** — The token propagates as metadata through the agent orchestration
   context. Agents themselves don't need to be aware of it — the framework carries
   it as a context property (similar to OpenTelemetry baggage).

5. **Cross-activity linking** — When one activity spawns a related activity (e.g.,
   a Sales Order spawns a Shipment), the child activity's definition includes a
   `related_token` field pointing back to the parent correlation token.

## Correlation Across Orchestrations

When a business process spans multiple agent orchestrations (e.g., order processing
is one orchestration, fulfilment is another), the correlation token is the link:

```
Orchestration 1: Order Processing
  Milestone: Received   → token minted: EMEA-SO-4821-20260714T140103Z
  Milestone: Validated  → same token
  Milestone: Approved   → same token

Orchestration 2: Fulfilment (triggered asynchronously)
  Milestone: Picked     → looks up token via OrderID → EMEA-SO-4821-20260714T140103Z
  Milestone: Dispatched → same token
  Milestone: Delivered  → same token
```

The lookup at Orchestration 2's first milestone uses the `correlation.lookup` field
in the tracking profile, which queries the activity store for the existing token
matching the business object.

## Storage

The correlation token is stored as:
- Primary key in the activity table (indexed)
- A column in any related activity tables (foreign key relationship)
- Searchable via any component (Division, ObjectType, ObjectID)
