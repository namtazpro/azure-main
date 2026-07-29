---
title: Issue 1 - Handling Non-Automated Email
description: How the email automation solution returns non-automated emails to business-users, why the current Microsoft Graph forward makes the business-user search for the original requester, and the options explored to ease that effort.
ms.topic: concept
keywords:
  - microsoft graph
  - create forward
  - eml attachment
  - non-automated email
  - business-user mailbox
estimated_reading_time: 6
---

## Issue 1 - Handling non-automated email

Some scenarios are, by design or by classification, **not automated**. For those, the bot hands the email back to a business-user. The ask is to make that hand-back easier for the business-user to action.

## How the flow works today

1. A requester emails a **business-user mailbox**.
2. That mailbox has a **redirection rule** that forwards the mail to the **bot ID**, so the bot receives every incoming request (see [Issue 2](issue-2-redirection-rules.md)).
3. On the automated path the bot selects a template for the business-user to review; the bot **never replies to the requester directly**.
4. When the bot determines the scenario is **non-automated**, it **forwards** the original mail to the business-user, who must then find the original request and send the final response to the requester.

The forward is performed with the Microsoft Graph **`createForward`** API, using the **bot's Graph token**. The system just forwards the captured message ID - it does not edit the body or add a comment.

## The problem

Because the mail is forwarded **from the bot**, the business-user has to reconstruct where it originally came from:

- They copy the **subject** and search their mailbox for the requester's thread.
- One requester can have **several mails with the same subject**, so the search is ambiguous.
- At scale this is real operational effort, and the value ask is to **reduce the manual work** and ease the business-user experience.

## Constraints

- **No sending on behalf of the requester.** Making the forward appear to come from the requester would need the requester's token / mailbox access - effectively hacking mailboxes. This is off the table.
- **Email is a standard protocol.** The email protocol is not customised; common mail clients behave the same way, so any solution has to work within standard mail behaviour.
- **External customers must not see internal detail.** The bot / audit thread history must not be exposed to external customers, which rules out simply replying on the existing thread.

## Options explored

- **Put the requester at the top of the forwarded body** - rejected: business-users search by subject in their own mailbox, and multiple same-subject mails make this unreliable; it also does not hide the bot/audit history.
- **Attach a ready-to-send `.eml` file** - a clean email (correct requester, body, no bot/audit history) attached to the forward, which the business-user opens and sends. Considered feasible and the most promising direction, but not yet implemented because the current design forwards a message ID rather than composing a new mail.
- **Explore a "forward on behalf of" option in the forward API** - the specific technical question to answer: does Graph's forward capability offer any supported way to present the bot's forward as being on behalf of the requester.

## Status and next steps

- The constraints above have already been hit during earlier iteration, so this is not a quick fix.
- Research whether Microsoft Graph offers any supported forward/send-on-behalf option that fits the constraints.
- If no on-behalf option exists, the `.eml` attachment approach is the leading candidate to pursue.

## Related

- [Issue 2 - Centralized Outlook re-direction rules](issue-2-redirection-rules.md) - the redirection rules that put mail on the bot in the first place.
