# `logicApp.bicep` — The Story of the Logic App

> The Office Assistant Who Reads Mail

The Function App is a busy chef. Picture a **quiet office assistant** sitting at a desk with a mailbox. The chef doesn't have time to write thank-you notes — so whenever a contact form is filled out, the chef drops a sticky note ("Hey, someone named Riya messaged us") into the assistant's mailbox and walks away.

That assistant is your **Logic App**. It wakes up, reads the note, stamps a log entry, sends a polite *"Got it!"* reply back to the chef, and goes back to sleep. No code. Just a recipe of clicks-and-arrows that runs on Azure's servers.

---

## Scene 1 — Hiring the assistant

```bicep
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  properties: {
    state: 'Enabled'
    ...
  }
}
```

- `Microsoft.Logic/workflows` → the resource type for a Logic App workflow.
- `state: 'Enabled'` → "Assistant, you're on duty." (`Disabled` = exists but never fires.)
- No SKU, no plan — **Consumption-tier Logic App**: pay per action executed (fractions of a paisa each). Zero cost when idle.

---

## Scene 2 — The recipe book (`definition`)

Every Logic App is one giant JSON document called a **workflow definition**:

```bicep
definition: {
  '$schema': '...workflowdefinition.json#'
  contentVersion: '1.0.0.0'
  triggers: { ... }   // when do I wake up?
  actions:  { ... }   // what do I do once awake?
  outputs:  {}        // what do I return to the caller?
}
```

A **flowchart written in JSON** — exactly what you see in the Logic App Designer, just expressed as text so Bicep can deploy it.

---

## Scene 3 — The doorbell (`triggers`)

```bicep
triggers: {
  manual: {
    type: 'Request'
    kind: 'Http'
    inputs: { schema: { ... required fields ... } }
  }
}
```

A Logic App has **only one trigger** — the doorbell.

- Trigger is *named* `manual` (you could call it `start` or `whenContactSubmitted` — just an identifier).
- `type: 'Request'` + `kind: 'Http'` → "Wake me up via an HTTPS POST." This is what makes Logic Apps quietly generate a **public callback URL** (with `sig=` token) that the Function App POSTs to.
- `schema` → JSON Schema describing the POST body. The Designer uses it to show `triggerBody().name`, `.email`, `.message` as drag-and-drop tokens. Required fields are validated on entry.

---

## Scene 4 — Step one: stamp a log entry (`Log_Contact_Received`)

```bicep
Log_Contact_Received: {
  type: 'Compose'
  inputs: {
    timestamp:      '@{utcNow()}'
    contactName:    '@{coalesce(triggerBody()?[\'name\'], \'(missing)\')}'
    ...
  }
  runAfter: {}
}
```

- **Actions are named keys** in the `actions` object. The key (`Log_Contact_Received`) is the identifier — pick anything descriptive (no spaces).
- `type: 'Compose'` = the cheapest action. Assembles a JSON object you can see in Run history. Doesn't send mail, doesn't call APIs — just **assembles and remembers**.
- `@{...}` is the **Logic App expression language**. Common verbs:
  - `@{utcNow()}` → current UTC time
  - `@{triggerBody()}` → whole incoming body
  - `@{triggerBody()?['name']}` → safe field read (`?` = "don't crash if missing")
  - `@{coalesce(a, b)}` → if `a` is null, use `b`
- `runAfter: {}` = "I run first." Logic Apps don't run actions top-to-bottom — they run them by the dependency graph in `runAfter`.

---

## Scene 5 — Step two: reply to the caller (`Response`)

```bicep
Response: {
  type: 'Response'
  kind: 'Http'
  inputs: { statusCode: 200; body: { ... } }
  runAfter: { Log_Contact_Received: [ 'Succeeded' ] }
}
```

- `type: 'Response'` + `kind: 'Http'` → "Send an HTTP response back to whoever called me."
- `runAfter: { Log_Contact_Received: [ 'Succeeded' ] }` → **the heart of Logic App control flow**: "Run me only after `Log_Contact_Received` finished, and only if its status was Succeeded." Valid statuses: `Succeeded`, `Failed`, `Skipped`, `TimedOut`. That's how you build branches and error handling.

Flow:

```
trigger (HTTP POST)
  → Log_Contact_Received (Compose)
  → Response (HTTP 200 to caller)
```

---

## Scene 6 — The two sticky notes at the bottom (`output`s)

```bicep
output logicAppEndpoint    string = logicApp.properties.accessEndpoint
output logicAppCallbackUrl string = listCallbackUrl('${logicApp.id}/triggers/manual', '2019-05-01').value
```

- `logicAppEndpoint` → the bare ARM resource address (gives `MissingApiVersionParameter` if you open it in a browser — that's expected).
- `logicAppCallbackUrl` → **the actual POST URL** with the `sig=` token embedded.

The `listCallbackUrl(...)` call is a Bicep helper function: *"At deploy time, call the Azure REST API and give me the callback URL."*

**You never type it. You never copy-paste it. Bicep fetches it during deployment** and plumbs it through `main.bicep` → Function App → `LOGIC_APP_CALLBACK_URL` app setting. Zero hard-coded URLs.

> Tip — the trigger name in `listCallbackUrl('.../triggers/manual', ...)` **must match the trigger key** in the workflow definition.

---

## The 5-Second Mental Model

1. **One workflow = one big JSON document** with `triggers`, `actions`, `outputs`.
2. **Exactly one trigger** decides when to wake up. `Request`/`Http` = "wake on POST to my secret callback URL."
3. **Actions are named keys**; each has a `type` (`Compose`, `Response`, `Http`, `SendEmail`...) and `inputs`.
4. **`runAfter` builds the flowchart.** Empty = runs first. `{ PreviousAction: [ 'Succeeded' ] }` = conditional chaining.
5. **`@{...}` is the expression language** — `utcNow()`, `triggerBody()`, `coalesce()`.
6. **`listCallbackUrl(...)`** hands the secret POST URL to the Function App at deploy time, no manual copy-paste.
