# `monitoring.bicep` — The Story of Application Insights

> The CCTV Camera Above the Restaurant

You have a chef (Function App), an assistant (Logic App), filing cabinets (Storage), and a shop window (frontend). One thing is missing: **how do you know what actually happened yesterday at 3 a.m. when nobody was watching?**

Enter the **CCTV camera with a flight recorder** — **Application Insights** (often shortened to "App Insights" or just "AI").

It's the tiniest module in your project — barely 15 lines — but it turns *"my function is broken"* into *"my function is broken on line 42 because the table call timed out 7 times in the last 5 minutes."*

---

## Scene 1 — What is App Insights, really?

A camera + microphone + clock bolted to the ceiling of your restaurant. It silently records:

- **Every request** that walks in (URL, time taken, success/failure)
- **Every word the chef mutters** (`context.log`, `context.log.warn`, `console.error`)
- **How long each step took** (DB call: 12 ms, HTTP call to Logic App: 80 ms)
- **Every exception thrown**, with full stack trace
- **CPU, memory, instance count, cold-start time**

And stores it in a giant searchable database in Azure for 30 days. You query it with **KQL** (Kusto Query Language).

---

## Scene 2 — Buying the camera

```bicep
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    IngestionMode: 'ApplicationInsights'
  }
}
```

| Line | Story translation |
|---|---|
| `'Microsoft.Insights/components@2020-02-02'` | Official resource type. `2020-02-02` is the API version — pin the date to keep Bicep stable. |
| `kind: 'web'` | "I'm monitoring a web application." Covers Functions, Web Apps, frontends. Mostly affects default charts. |
| `Application_Type: 'web'` | Legacy property that mirrors `kind`. Always set them the same. |
| `RetentionInDays: 30` | "Keep footage 30 days, then auto-delete." Range 30-730. Free tier is 90. |
| `IngestionMode: 'ApplicationInsights'` | Classic ingestion endpoint. Alternative `LogAnalytics` routes everything into a Log Analytics workspace (modern recommended for big projects). Classic is simpler and fine here. |

That's the whole resource.

---

## Scene 3 — The instrumentation key (the only output that matters)

```bicep
output instrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsId       string = appInsights.id
```

- `instrumentationKey` → a **GUID**. The camera's Wi-Fi password. Anyone with it can push telemetry into your AI instance.
- `appInsightsId` → ARM resource ID, useful if another resource ever references this AI (dashboard, alert rule, workbook).

`main.bicep` pipes `instrumentationKey` into the Function App, which writes it as the app setting:

```bicep
{ name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsightsInstrumentationKey }
```

**That single setting turns on the CCTV.** The Functions runtime sees it at startup, auto-loads the AI SDK, hooks into every HTTP request / exception / `context.log` call, and streams telemetry to AI. **You write no logging code yourself.**

---

## Scene 4 — What you see in the portal

| Blade | Shows |
|---|---|
| **Live Metrics** | Real-time stream: requests/sec, failures/sec, response time. |
| **Application Map** | Auto-generated diagram of what calls what — Function App → Table Storage → Logic App. |
| **Failures** | All exceptions grouped by type; click for stack trace + offending request. |
| **Performance** | Slowest operations. Cold start vs. slow Table query. |
| **Logs (KQL)** | Free-form query window. |

---

## Scene 5 — KQL: speaking to the database

Paste in **Logs**:

```kql
requests
| where timestamp > ago(1h)
| summarize count(), avg(duration) by resultCode, name
| order by count_ desc
```

*"All HTTP requests in the last hour, grouped by status + endpoint."* Instant table:

| name | resultCode | count_ | avg_duration |
|---|---|---|---|
| GET /api/profile | 200 | 47 | 38 ms |
| POST /api/contact | 200 | 3 | 612 ms |
| GET /api/profile | 500 | 1 | 4200 ms |

Drill into the failure:

```kql
exceptions
| where timestamp > ago(1h)
| project timestamp, type, outerMessage, operation_Name
```

Every `context.log(...)` lands in `traces`:

```kql
traces
| where timestamp > ago(15m)
| where message contains "Contact saved"
```

This is **observability** — debug by querying a database of everything that ever happened, not SSH-ing into servers.

---

## Scene 6 — Why the module is so tiny

You might ask: *"Why not also create alerts, dashboards, action groups?"*

1. Student-tier projects don't need them.
2. Doubling module size for value you won't use is waste.
3. Easy to bolt on later as new modules (`alerts.bicep`, `actionGroup.bicep`) without touching this one. **Bicep modules should do one job well.**

---

## Scene 7 — Cost reality check

Free tier: **5 GB ingestion/month**. Your portfolio at handful-of-requests-a-day will ingest a few MB → effectively free. `RetentionInDays: 30` keeps storage minimal.

If scaling up: AI → **Usage and estimated costs** → set a **daily cap** (e.g., 0.1 GB/day). Ingestion drops new telemetry past the cap until midnight UTC. Safe.

---

## The 5-Second Mental Model

1. **App Insights = one `Microsoft.Insights/components` resource** — a CCTV with a 30-day flight recorder.
2. **Three properties matter:** `kind: 'web'`, `Application_Type: 'web'`, `RetentionInDays: 30`.
3. **One output matters:** `instrumentationKey` — a GUID that says *"send telemetry here."*
4. **One app setting in the Function App turns it on:** `APPINSIGHTS_INSTRUMENTATIONKEY`. Auto-loads the SDK. **Zero** logging code.
5. **Watch results in the portal** — Live Metrics now, Failures + KQL Logs for forensics. `requests`, `traces`, `exceptions`, `dependencies` = the four tables you'll query 90% of the time.
6. **Free at portfolio scale.** Smallest module, biggest debugging superpower.
