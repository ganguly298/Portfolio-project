# Microsoft Entra ID Authentication Setup

This project uses the lowest-cost authentication shape for Azure for Students:

- Storage static website hosting stays public and cheap.
- The browser signs users in with MSAL.js.
- Azure Functions built-in Authentication blocks unauthenticated API calls.
- Managed Identity remains responsible for Function App access to Storage and Key Vault.

## Prerequisites

- Azure for Students subscription access.
- Permission to create Microsoft Entra app registrations.
- The deployed frontend URL, for example `https://<storage>.z29.web.core.windows.net`.
- Azure CLI signed in to the same tenant and subscription.

## App Registrations

Create two Microsoft Entra app registrations.

### 1. API app registration

Name: `portfolio-api`

Expose an API:

- Application ID URI: `api://<portfolio-api-client-id>`
- Scope name: `access_as_user`
- Who can consent: Admins and users, if your tenant allows user consent
- Display name: `Access portfolio API`

Record these values:

- Tenant ID
- API client ID
- API scope: `api://<portfolio-api-client-id>/access_as_user`

### 2. Frontend SPA app registration

Name: `portfolio-frontend-spa`

Authentication platform:

- Platform type: Single-page application
- Redirect URI: your Storage static website URL

API permissions:

- Add permission to `portfolio-api`
- Select delegated permission `access_as_user`

Record this value:

- Frontend client ID

## Deploy With Auth Enabled

```powershell
.\deploy.ps1 `
  -EnableEntraAuth `
  -EntraTenantId '<tenant-id>' `
  -EntraFrontendClientId '<frontend-spa-client-id>' `
  -EntraApiClientId '<api-client-id>'
```

If you use a custom API scope, pass it explicitly:

```powershell
.\deploy.ps1 `
  -EnableEntraAuth `
  -EntraTenantId '<tenant-id>' `
  -EntraFrontendClientId '<frontend-spa-client-id>' `
  -EntraApiClientId '<api-client-id>' `
  -EntraApiScope 'api://<api-client-id>/access_as_user'
```

The deploy script writes these values into the published `config.js`. They are public identifiers, not secrets.

You can also provide the same values through environment variables:

```powershell
$env:ENTRA_TENANT_ID = '<tenant-id>'
$env:ENTRA_FRONTEND_CLIENT_ID = '<frontend-spa-client-id>'
$env:ENTRA_API_CLIENT_ID = '<api-client-id>'
$env:ENTRA_API_SCOPE = 'api://<api-client-id>/access_as_user'
.\deploy.ps1 -EnableEntraAuth
```

## Cost View

Expected extra cost for this setup is `$0`:

- Microsoft Entra Free tenant: no extra charge.
- App registrations: no extra charge.
- MSAL.js: no extra charge.
- Function App built-in Authentication: no extra charge.
- Storage static website hosting remains the same low-cost/free-tier resource.

Avoid these unless you specifically need them, because they can add cost:

- Conditional Access, which usually needs Entra ID P1.
- Identity Protection, which needs Entra ID P2.
- Front Door, WAF, or API Management.
- Paid Static Web Apps Standard or App Service plans just to hide static files.

## Behavior After Deployment

- Opening the frontend still downloads static files anonymously.
- API calls return `401` unless the browser sends a valid Entra access token.
- The page shows a sign-in button and calls `/api/profile`, `/api/visitors`, and `/api/contact` only after sign-in.
- Direct `curl` calls need a bearer token for the configured API scope.