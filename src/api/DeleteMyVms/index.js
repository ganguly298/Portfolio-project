/**
 * DeleteMyVms — DELETE /api/my-vms
 *
 * Deletes the caller's per-user resource group (and therefore all VMs,
 * NICs, NSGs, public IPs and VNets in it). The RG name is derived from
 * the signed-in user's UPN, so users can only delete their own RG.
 *
 * Defensive: refuses to delete unless the RG is tagged vmdemo=true.
 * Issues beginDelete and returns 202 immediately; actual teardown
 * runs server-side.
 */
const { DefaultAzureCredential } = require('@azure/identity');
const { ResourceManagementClient } = require('@azure/arm-resources');

const RG_SUFFIX = '-RG';

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

    const subscriptionId = process.env.SUBSCRIPTION_ID;
    if (!subscriptionId) {
        context.res = { status: 500, body: { error: 'SUBSCRIPTION_ID not configured' } };
        return;
    }

    const client = new ResourceManagementClient(new DefaultAzureCredential(), subscriptionId);
    const rgName = rgNameForUser(upn);

    let rg;
    try {
        rg = await client.resourceGroups.get(rgName);
    } catch (err) {
        if (err.statusCode === 404) {
            context.res = { status: 404, body: { error: 'No environment to delete', rgName } };
            return;
        }
        context.log.error('RG lookup failed:', err.message);
        context.res = { status: 500, body: { error: err.message } };
        return;
    }

    const tags = rg.tags || {};
    if (tags.vmdemo !== 'true') {
        context.res = { status: 403, body: { error: 'Refusing to delete: RG is not tagged vmdemo=true', rgName } };
        return;
    }

    try {
        await client.resourceGroups.beginDelete(rgName);
    } catch (err) {
        context.log.error('beginDelete failed:', err.message);
        context.res = { status: 502, body: { error: err.message, rgName } };
        return;
    }

    context.log(`Submitted delete for RG ${rgName} (owner=${upn})`);
    context.res = {
        status: 202,
        headers: { 'Content-Type': 'application/json' },
        body: { status: 'deleting', rgName }
    };
};
