/**
 * GetVmCredential — GET /api/vm/{deploymentId}/credential?rg=<rgName>
 *
 * Returns the admin password for a previously created VM. The function
 * MI reads the secret from Key Vault on behalf of the user, so the user
 * never needs KV data-plane RBAC.
 *
 * Authorisation: the caller's UPN (from Easy Auth) must own the RG —
 * i.e. rgName must equal rgNameForUser(upn). Without this check, any
 * signed-in user could read any other user's password by guessing the
 * deployment id and RG name.
 */
const { DefaultAzureCredential } = require('@azure/identity');
const { ResourceManagementClient } = require('@azure/arm-resources');

const RG_SUFFIX = '-RG';
const KV_API_VERSION = '7.4';

function extractUpn(req) {
    const header = req.headers['x-ms-client-principal'];
    if (!header) return null;
    try {
        const decoded = JSON.parse(Buffer.from(header, 'base64').toString('utf8'));
        const upnClaim = (decoded.claims || []).find(
            c => c.typ === 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn'
                || c.typ === 'preferred_username'
                || c.typ === 'upn'
        );
        return upnClaim ? upnClaim.val : decoded.userPrincipalName || null;
    } catch {
        return null;
    }
}

function rgNameForUser(upn) {
    const local = upn.split('@')[0].toLowerCase().replace(/[^a-z0-9]/g, '');
    return local.slice(0, 20) + RG_SUFFIX;
}

module.exports = async function (context, req) {
    const upn = extractUpn(req);
    if (!upn) {
        context.res = { status: 401, body: { error: 'No authenticated user found' } };
        return;
    }

    const deploymentId = context.bindingData.deploymentId;
    const rgName = (req.query && req.query.rg) || '';
    if (!deploymentId || !rgName) {
        context.res = { status: 400, body: { error: 'Missing deploymentId or ?rg= query param' } };
        return;
    }

    const expectedRg = rgNameForUser(upn);
    if (rgName.toLowerCase() !== expectedRg.toLowerCase()) {
        context.res = { status: 403, body: { error: 'You do not own this resource group' } };
        return;
    }

    const subscriptionId = process.env.SUBSCRIPTION_ID;
    if (!subscriptionId) {
        context.res = { status: 500, body: { error: 'SUBSCRIPTION_ID not configured' } };
        return;
    }

    const credential = new DefaultAzureCredential();
    const client = new ResourceManagementClient(credential, subscriptionId);

    let secretRef = '';
    try {
        const result = await client.deployments.get(rgName, deploymentId);
        const state = result.properties && result.properties.provisioningState;
        if (state !== 'Succeeded') {
            context.res = { status: 409, body: { error: `Deployment is in state '${state}', no password available yet` } };
            return;
        }
        const outputs = (result.properties && result.properties.outputs) || {};
        secretRef = (outputs.kvSecretReference && outputs.kvSecretReference.value) || '';
    } catch (err) {
        if (err.statusCode === 404) {
            context.res = { status: 404, body: { error: 'Deployment not found' } };
            return;
        }
        context.log.error('Deployment lookup failed:', err.message);
        context.res = { status: 500, body: { error: err.message } };
        return;
    }

    if (!secretRef) {
        context.res = { status: 404, body: { error: 'Deployment has no kvSecretReference output' } };
        return;
    }

    // secretRef looks like https://<vault>.vault.azure.net/secrets/<name>[/<version>]
    const m = secretRef.match(/^https:\/\/([^/]+)\/secrets\/([^/?]+)(?:\/([^/?]+))?/i);
    if (!m) {
        context.res = { status: 500, body: { error: 'kvSecretReference is not a valid Key Vault URL' } };
        return;
    }
    const vaultHost = m[1];
    const secretName = m[2];
    const version = m[3] || '';

    try {
        const token = await credential.getToken('https://vault.azure.net/.default');
        if (!token || !token.token) throw new Error('Failed to acquire KV token');

        const url = `https://${vaultHost}/secrets/${encodeURIComponent(secretName)}${version ? '/' + encodeURIComponent(version) : ''}?api-version=${KV_API_VERSION}`;
        const r = await fetch(url, { headers: { Authorization: `Bearer ${token.token}` } });
        if (!r.ok) {
            const text = await r.text();
            context.log.error(`KV fetch failed ${r.status}: ${text}`);
            context.res = { status: 502, body: { error: `Key Vault returned ${r.status}` } };
            return;
        }
        const payload = await r.json();
        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
            body: { password: payload.value }
        };
    } catch (err) {
        context.log.error('Secret retrieval failed:', err.message);
        context.res = { status: 500, body: { error: err.message } };
    }
};
