# send-email-letai

Minimal Node.js sample that sends an email carrying the custom `X-LetAI-Request-Id` Internet header through Microsoft Graph.

## How it works

Microsoft Graph only accepts custom `x-` prefixed Internet headers when a message is *created*. A one-step `sendMail` call cannot attach them. The sample therefore follows the create-draft-then-send pattern:

1. Create the message as a draft with `internetMessageHeaders` (`X-LetAI-Request-Id` and `X-LetAI-Delivery-Attempt-Id`).
2. Record the returned `id` and `internetMessageId` (the RFC `Message-ID`, used as the primary correlation key).
3. Send the draft.

## Prerequisites

- Node.js 18 or later (uses the built-in `fetch`; no `npm install` required).
- A Microsoft Entra app registration with the **`Mail.Send`** *application* permission granted (admin consent).
- A client secret for that app registration.

## Setup

```pwsh
cd samples/send-email-letai
Copy-Item .env.example .env
```

Edit `.env` and fill in the tenant, client, sender mailbox, and recipient values.

## Run

```pwsh
npm start
# or: node src/index.js
```

The command prints the Graph message id, the `internetMessageId`, and the correlation identifiers, then sends the draft.

## Notes

- The sample is dependency-free: it acquires an app-only token from the client-credentials endpoint and calls Graph directly with `fetch`. `Mail.Send` as an application permission lets the app send as any mailbox in the tenant, so scope it with an [application access policy](https://learn.microsoft.com/graph/auth-limit-mailbox-access) in production.
- Keep the client secret out of source control. The `.env` file is git-ignored.
