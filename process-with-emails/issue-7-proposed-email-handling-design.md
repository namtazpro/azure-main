---
title: Issue 7 - Proposed Email Handling Design
description: Proposed email handling design addressing non-automated email hand-off and centralized email redirection.
author: Vincent Rouet
ms.date: 2026-09-30
ms.topic: concept
keywords:
  - email handling
  - non-automated email
  - email redirection
  - solution design
estimated_reading_time: 1
---

## Issue 7 -  New email handling design - 29th Sept 2026

Questions

# ***-AI Architecture Revision for email handling: Microsoft Guidance

**Date:** 30 September 2026  
**Scope:** This page is based on the responses and options discussed in the two call transcripts.  
**Business requirement confirmed:** ***-AI must send automated follow-up questions and responses **from the dedicated Bot mailbox** to the requester. The reply must remain associated with the existing business conversation as far as the mail clients allow. Sending as the Specialist mailbox is not the target design.


## Context agreed during the calls

The proposed architecture removes mailbox redirection rules and the existing Logic App ingestion step. A common Microsoft Graph notification mechanism and Azure Function would identify the affected Specialist mailbox, retrieve message metadata, store or update the conversation history in Cosmos DB, and place the result on Service Bus for downstream processing.

The second call confirmed the key business requirement:

- The customer initially sends the email to a Specialist mailbox.
- ***-AI processes the email.
- If more information is needed, the follow-up must be sent **from the Bot mailbox**.
- The business wants this exchange to remain in the same visible email thread.
- Specialists normally interact through the ***-AI web application rather than replying directly from their mailbox.

---

## 1. Conversation preservation across mailboxes

### Question

Our initial customer email is received in a Specialist mailbox, while ***-AI may send automated responses using a dedicated Bot mailbox. What is the Microsoft-recommended approach to preserve the same Outlook conversation/thread when the source message and subsequent automated response are handled by different mailboxes?

### Responses and options discussed

The first conclusion was that an email sent directly from the Bot mailbox would ordinarily be coming from a different mailbox and could therefore appear as a different thread. Simply copying the Specialist mailbox on the Bot response was not considered sufficient by itself to establish that the Bot message was part of the original thread.

Three options were discussed:

1. **Programmatically add the Bot mailbox to the stored incoming message**

   The development team proposed modifying the message metadata associated with the incoming Specialist-mailbox message to add the Bot address to CC. The intention was to make the Bot appear to be part of the exchange before it sends the follow-up. The team believed this was achievable using the message ID and planned to store the updated From, To and CC information in Cosmos DB.

2. **Send the Bot response to the requester and copy the Specialist mailbox**

   Under the proposed sequence, the outgoing message would be sent from the Bot mailbox to the requester, with the Specialist mailbox copied. The team expected that subsequent replies from the requester would then include the Bot and reduce the need for additional mailbox mapping.

3. **Maintain an application-owned conversation in Cosmos DB**

   The stronger agreement was that ***-AI should maintain its own complete mail history. The initial Specialist message, the Bot response and subsequent requester replies would all be appended to the corresponding Cosmos DB record. This was described during the call as creating ***-AI's "own graph" of the conversation.

### Transcript-based guidance

The calls did **not conclusively establish** that adding the Bot to the stored message's CC field would preserve the Outlook thread. That remained a proposal from the development team.

The agreed direction was to:

- test the CC/Bot participation approach;
- keep the subject unchanged;
- maintain the authoritative conversation history in Cosmos DB;
- supplement the mail conversation with a ***-AI correlation mechanism;
- perform a POC covering several back-and-forth messages.

**Status:** Proposed approach requiring validation.

---

## 2. Conversation correlation across mailboxes

### Question

Can `conversationId` be reliably used to correlate messages when the same conversation involves multiple mailboxes, for example, Specialist mailbox, Bot mailbox and Customer? If not, which combination of Microsoft Graph properties or RFC email headers, such as `InternetMessageId`, `In-Reply-To` and `References`, is recommended for reliable cross-mailbox thread correlation?

### Responses and options discussed

The first call did not produce a definitive answer about whether `conversationId` alone would remain reliable across the Specialist, Bot and requester mailboxes. The initial suggestion was that Graph's built-in correlation might not be sufficient and that ***-AI would probably need its own tracking mechanism.

The options discussed were:

1. **Use an application-owned correlation ID**

   A ***-AI identifier could be included in the email, allowing subsequent messages to be mapped back to the same request. A visible identifier in the subject was compared with a Microsoft Support case number.

2. **Create a composite key**

   The development team proposed combining:

   - Graph `conversationId`; and
   - the existing auto-generated ***-AI request ID.

   The proposed structure was:

   `conversationId + requestId`

   This composite value would be stored in Cosmos DB and used as the ***-AI correlation ID.

3. **Use multiple mail attributes**

   The guidance during the second call was not to depend on one property alone. The team should use as many relevant message attributes as possible when composing the correlation key, including `conversationId` and information identifying where the message came from.

4. **Add a custom identifier to the email header**

   A custom email-header attribute had previously been considered for NDR correlation. The same option was raised here because it would not be visible to the user and could help diagnose an orphan email by inspecting its headers. It was positioned as an additional or nice-to-have safeguard rather than the primary mechanism.

5. **Keep the full message sequence in Cosmos DB**

   For every step, the application would append the incoming or outgoing message information to its Cosmos DB mail-history array.

### Further guidance about correlation attribute (post calls):

The correlation can be an envelope for every message containing at least:

- ***-AI request/case ID.
- Tenant and mailbox identifier.
- Graph message ID, requested with `Prefer: IdType="ImmutableId"`.
- `internetMessageId`.
- `conversationId`.
- Parent `internetMessageId` derived from `In-Reply-To`, where available.
- `References`, where available.
- Sender, recipients, normalised subject and `receivedDateTime`.
- Processing state and idempotency status.

Microsoft documents that normal Outlook item IDs can change when items move. Immutable IDs remain stable while the item remains in the same mailbox, although they are not cross-mailbox identifiers. This makes the immutable Graph ID appropriate for locating a message within one mailbox, while `internetMessageId` and RFC reply headers are stronger evidence for relationships between copies crossing mailboxes.

The custom ***-AI ID is valuable for application observability and orphan-message investigation, but the team should test whether it survives every external mail hop and reply path. It must therefore complement, not replace, native message identifiers.

### Transcript-based guidance

The most complete option discussed was to:

- maintain a custom conversation model in Cosmos DB;
- use a composite key based on `conversationId`, the ***-AI request ID and other available message attributes;
- optionally add a custom correlation attribute to the email header;
- not assume that `conversationId` alone is sufficient until the multi-mailbox behaviour has been tested.

**Status:** Direction agreed, but the exact property combination still requires a POC.

---

## 3. Graph Reply / ReplyAll across mailboxes

### Question

Can an application use Microsoft Graph to reply to a message residing in a Specialist mailbox while sending the response using a different Bot mailbox? If not, what is the Microsoft-recommended implementation pattern for maintaining reply and conversation continuity in this scenario?

### Responses and options discussed

The scenario was initially interpreted as sending on behalf of the Specialist mailbox. The team clarified that this was not the requirement: the reply must be sent **from the Bot mailbox**, while appearing in the same exchange initiated through the Specialist mailbox.

The following options were discussed:

1. **Send on behalf of the Specialist mailbox**

   This was raised as a technical alternative, but it did not satisfy the stated business requirement because the team wanted the response to come from the Bot mailbox.

2. **Send directly from the Bot mailbox**

   This satisfies the sender requirement, but the concern raised in the calls was that it could create a separate mail thread unless ***-AI establishes some form of correlation.

3. **Add the Bot address to the original message's CC metadata**

   The development team proposed adding the Bot mailbox programmatically when ***-AI first processes the Specialist message. The Bot would then send the follow-up to the requester, while the Specialist mailbox would remain copied. The development team considered this to resolve question three, subject to validation that the Bot address is added only when it is not already present.

4. **Maintain continuity inside Cosmos DB**

   Regardless of Outlook's presentation, ***-AI would associate the original Specialist message, Bot follow-up and requester response in its Cosmos DB conversation record.

### Further guidance for this questions (post calls)

Microsoft Graph does support sending mail from another user, but this depends on the Graph permission model and Exchange `Send As` or `Send on Behalf` permissions. That feature is intended to make mail appear from another mailbox; it does not change the fact that a reply action is anchored to the mailbox/message addressed by the API call.

For ***-AI, the business requirement is explicitly to send from the Bot mailbox. The possible implementation is therefore:

1. Read the original message and correlation metadata from the Specialist mailbox.
2. Build the response as a new Bot-mailbox draft or MIME message.
3. Address the requester and preserve the required Specialist recipients according to the business rule.
4. Preserve RFC reply relationships where possible and maintain the authoritative ***-AI link in Cosmos DB.
5. Send through the Bot mailbox.

### Transcript-based guidance


The development team's selected option was to:

- detect the incoming message in the Specialist mailbox;
- add or represent the Bot address in the CC information;
- send the follow-up from the Bot mailbox to the requester;
- copy the Specialist mailbox;
- preserve the subject;
- use ***-AI's Cosmos DB correlation to maintain application-level continuity.

**Status:** Development-team proposal judged worth pursuing, but not technically validated during the calls.

---

## 4. Change Notification reliability

### Question

For approximately 40–60 Specialist mailboxes monitored through Microsoft Graph Change Notifications, what are the expected delivery guarantees for notifications? How should missed, delayed or duplicate notifications be handled in a production-grade implementation?

### Responses and options discussed

The discussion identified the following behaviours:

- Graph considers the notification delivered when the webhook returns a successful response within three seconds.
- If Graph does not receive the acknowledgement, it retries the notification.
- The retry period discussed was up to four hours.
- The webhook listener was expected to be an Azure Function.
- The retry of the webhook notification was described as Graph behaviour, not something the development team had to reproduce as its own webhook-delivery mechanism.

For duplicate delivery, the guidance was that ***-AI must check whether the notification or message has already been handled. Options discussed included:

- creating a hash from the email or notification information;
- storing that hash and its acknowledgement or processing state in the database;
- checking Cosmos DB before processing;
- marking an event as duplicate or skipping it when it has already been processed;
- checking whether the corresponding `conversationId` or composite key already exists.

### Transcript-based guidance

The proposed production behaviour was:

1. Receive the notification through the Azure Function webhook.
2. Return the expected acknowledgement quickly.
3. Track whether the notification or message has already been handled.
4. Use a stored hash, conversation identifier or composite key for duplicate detection.
5. Skip or mark duplicate events rather than processing them again.


### Further guidance on reliability and SLA (post calls)


Microsoft Graph does **not** provide a documented delivery SLA or guaranteed delivery model for Outlook Change Notifications.

Microsoft documentation explicitly states that:

- Notifications may be delayed, retried, or dropped.
- Slow or unresponsive endpoints can be throttled.
- Notifications can be permanently dropped if delivery conditions are not met.
- Dropped notifications cannot be recovered through the webhook channel itself.

Microsoft provides lifecycle events specifically because notification loss is a recognised scenario. These lifecycle events include:

- `reauthorizationRequired`
- `subscriptionRemoved`
- `missed`

For Outlook messages, a `missed` lifecycle event indicates that notifications may have been lost and that the application should perform a full resynchronisation of the mailbox state, for example using a delta query https://learn.microsoft.com/en-us/graph/change-notifications-delivery-webhooks?tabs=http



Microsoft's guidance architecture should be viewed as:

```text
Change Notification
        +
Delta Query
```

rather than:

```text
Change Notification
        only
```

Notifications should be treated as a low-latency signal that a mailbox may have changed, while Delta Queries provide authoritative reconciliation and recovery.

---

Delta Query Recovery:

Each Specialist Mailbox should maintain:

- Subscription ID
- Subscription Expiry Time
- Last Successful Notification Timestamp
- Delta Token (`deltaLink`)
- Last Reconciliation Timestamp

If:

- A notification is not received
- A subscription is removed
- A `missed` lifecycle event is received

then ***-AI should:

1. Recreate or renew the subscription if required.
2. Execute a Delta Query from the last stored `deltaLink`.
3. Process any newly discovered messages.
4. Update the stored checkpoint.

Microsoft documentation specifically recommends performing a full data resynchronisation (such as via Delta Query) when a `missed` lifecycle notification is received.

---

Design Recommendation :

The ***-AI design should assume:

- Notifications can be duplicated.
- Notifications can be delayed.
- Notifications can be delivered out of order.
- Notifications can be missed.

Therefore:

> Graph Change Notifications provide latency optimisation, while Delta Queries provide completeness and recovery.

The authoritative source of mailbox state should be Microsoft Graph message retrieval and Delta Query reconciliation, not the notification stream itself.

---

Conclusion

Microsoft Graph Change Notifications should be treated as a **best-effort notification mechanism**, not a guaranteed delivery service.

For production-grade processing of approximately 40–60 Specialist Mailboxes, Microsoft documentation recommends combining:

- Graph Change Notifications for fast detection
- Delta Queries for recovery and reconciliation
- Lifecycle Notifications for subscription health monitoring
- Idempotent processing to handle duplicates and retries

This approach provides a resilient and recoverable architecture even when notifications are delayed, duplicated, or missed. 

**Status:** Retry and acknowledgement behaviour discussed;

---

## 5. Subscription lifecycle management

### Question

What is the Microsoft-recommended production approach for creating, renewing, monitoring and recovering Microsoft Graph Change Notification subscriptions for approximately 40–60 mailboxes using a single Entra application?

### Responses and options discussed

This question was not fully resolved during the calls.

The discussion focused mainly on delayed notifications and preserving the original email time:

- The team wanted to know whether a notification received later would still expose the actual time the email arrived in the Specialist mailbox.
- The existing solution generated its own timestamp using Python date/time and timezone modules.
- The suggestion was to use the message metadata or message headers to obtain the date/time associated with the email landing in the mailbox, instead of relying only on the time ***-AI processed the notification.
- It was assumed that the mailbox-received time would be available, but this was explicitly marked as something requiring verification.

No detailed process was agreed for:

- creating subscriptions;
- renewing subscriptions before expiration;
- monitoring subscription health;
- recreating failed or expired subscriptions;
- recovering a gap after subscription failure.

### Transcript-based guidance

The only concrete direction from the call was to:

- preserve the email's actual mailbox arrival timestamp in Cosmos DB;
- not rely solely on a timestamp created when ***-AI processes the notification;
- verify what timestamp attributes are returned by Graph;
- perform additional checking on subscription monitoring and lifecycle behaviour.

### Further guidance (post calls)

Refer to "Further Guidance" in response to question 4

**Status:** Refer to "Further Guidance" in response to question 4.

---

## 6. Duplicate or same email across multiple mailboxes

### Question

If the same email is delivered to multiple Specialist mailboxes, how does Microsoft recommend identifying and deduplicating the underlying email event? Can `InternetMessageId` be reliably used as the message-level correlation key across different mailboxes?

### Responses and options discussed

The development team described a case in which a requester includes two Specialist mailboxes on the same email. This generates separate processing paths that ***-AI must recognise as copies of the same underlying message.

The options discussed were:

1. **Use `InternetMessageId`**

   During the call, `InternetMessageId` was described as the strongest cross-mailbox candidate for identifying copies of the same message.

2. **Use a hash**

   A hash of the email or notification information could be generated and stored in Cosmos DB. Each new event would be checked against the stored hash, and an existing match would be marked as duplicate or not processed.

3. **Check `conversationId` or the composite correlation key**

   The application could check whether a corresponding conversation or composite key already exists before inserting or processing the event. However, the conversation explicitly noted uncertainty about whether copies received in different Specialist mailboxes would have the same `conversationId`.

4. **Add a custom correlation ID**

   A ***-AI-owned correlation identifier could provide an additional check alongside `InternetMessageId`.

### Transcript-based guidance

The resulting direction was to:

- use `InternetMessageId` as the primary cross-mailbox candidate;
- add a ***-AI correlation ID or composite key as an additional verification mechanism;
- optionally use a stored hash for duplicate-processing detection;
- keep the duplicate check in the application and Cosmos DB;
- mark an identified duplicate or skip further processing.

### Further Guidance (Post calls)

`internetMessageId` is the strongest native candidate for recognising copies of the same Internet email across mailboxes, but the implementation should not use it as an unqualified global primary key.

Use two levels of identity:

1. **Physical mailbox item:** mailbox ID + immutable Graph message ID.
2. **Logical email event:** normalised `internetMessageId`, supported by sender, sent/received time, subject and recipient information where needed.

For retry duplicates affecting the same mailbox item, prefer the mailbox ID plus immutable message ID. For the same original email delivered independently to two Specialist mailboxes, use `internetMessageId` as the first cross-mailbox deduplication signal and verify the business rule before suppressing processing.

This distinction matters because two Specialist mailboxes may legitimately represent different operational responsibilities. Technical duplication does not automatically mean that one business work item should be discarded. The deduplication record should therefore retain all mailbox deliveries and elect one canonical ***-AI case only when the routing rules say they represent the same work.

A content hash can be used as a fallback diagnostic signal, but it is weaker than native IDs because transport systems can modify headers, body formatting or signatures. A hash should not replace `internetMessageId` and mailbox-specific identity.

**Relevant Microsoft documentation**

- [Microsoft Graph message resource](https://learn.microsoft.com/en-us/graph/api/resources/message?view=graph-rest-1.0)
- [Obtain immutable identifiers for Outlook resources](https://learn.microsoft.com/en-us/graph/outlook-immutable-id)

---
Suggested implementation action:

Test one message addressed simultaneously to two or more Specialist mailboxes and capture `internetMessageId`, `conversationId`, immutable Graph ID and headers in each mailbox. Define whether ***-AI creates one case with multiple mailbox deliveries or separate cases based on the business routing model.

**Status:** General direction agreed; actual equality of identifiers across the targeted mailboxes still needed testing.

---

## 7. Graph throttling and concurrent processing

### Question

For an application processing messages and attachments across approximately 40–60 mailboxes, what Graph throttling, concurrency and retry considerations should be accounted for, and what retry/backoff pattern is recommended for this scenario?

### Responses and options discussed

The key architectural guidance from the second call was to separate rapid notification ingestion from later processing:

1. The Azure Function receiving the notification must be able to scale.
2. It should ingest the incoming notification promptly.
3. The event should then be placed onto a queue.
4. Message and attachment processing can be performed asynchronously by pulling from that queue.
5. The design should avoid slow processing in the webhook path because failure to respond within the expected interval would cause Graph to retry.

The existing Function App was described as using Elastic Premium EP1. The response was that EP1 should scale, but the team needed to perform its own benchmarking.

The workload examples discussed were:

- approximately 40–60 Specialist mailboxes;
- potentially 40–60 emails arriving at the same time;
- prior observations of roughly 2–13 emails per minute for one or two mailboxes;
- larger attachments increasing processing time.

The sizing options discussed were:

- begin with EP1;
- measure how many Function executions can be completed per second;
- observe whether throttling occurs;
- scale higher if required;
- avoid assuming that Graph retries are a substitute for sufficient Function capacity;
- use the queue to absorb bursts and process the backlog asynchronously.

The transcript also contains an informal statement that 60 requests per second on EP1 "seems reasonable", but this was not based on a demonstrated benchmark or formal documentation during the call. It should therefore be treated as an initial sizing hypothesis rather than a confirmed capacity figure.

### Transcript-based guidance

The agreed recommendation was to:

- start with EP1;
- ensure the notification receiver can scale;
- acknowledge notifications quickly;
- queue work for asynchronous processing;
- benchmark the actual workload;
- include realistic attachment sizes and burst scenarios;
- scale beyond EP1 if the benchmark shows throttling or insufficient throughput.

**Status:** Architectural pattern agreed; final sizing requires benchmark results.

---

# Consolidated outcome from the calls

## Agreed direction

- Remove Specialist-mailbox redirection rules.
- Use Graph notifications and an Azure Function for ingestion.
- Store message metadata and conversation history in Cosmos DB.
- Pass work to Service Bus for downstream asynchronous processing.
- Send additional questions and final communications from the Bot mailbox.
- Keep the subject unchanged.
- Build an application-owned cross-mailbox correlation model.
- Use several attributes rather than relying on `conversationId` alone.
- Use `InternetMessageId` as the strongest candidate for recognising the same message across mailboxes.
- Implement duplicate detection in ***-AI. Idempotent processing.
- Implement a reliability mechanism for Delta Queries, management of Lifecycle Notifications of subscriptions.
- Start with EP1 and benchmark the realistic workload.

## Options to validate through a POC

- Programmatically adding the Bot address to CC on the Specialist-mailbox message.
- Whether this addition actually helps preserve the visible Outlook thread.
- A composite correlation key based on `conversationId` and the ***-AI request ID.
- A hidden custom correlation attribute in the email header.
- Whether that custom attribute survives repeated back-and-forth messages.
- Whether `conversationId` remains the same across copies in different Specialist mailboxes.
- Whether `InternetMessageId` remains the same in all targeted duplication scenarios.

## Items not answered by the transcripts

- Confirmed timestamp fields available in the notification or retrieved message.

The `receivedDateTime` and `sentDateTime` field in the email are important because the send datetime is when the email was sent. The received datetime is when the email was received. It is the datetime when it entered the Specialist mailbox and therefore when ***-AI became responsible for it.

```
{
  "internetMessageId": "<abc123@customer.com>",
  "sentDateTime": "2026-10-01T09:01:00Z",
  "receivedDateTime": "2026-10-01T09:02:17Z"
}
```

