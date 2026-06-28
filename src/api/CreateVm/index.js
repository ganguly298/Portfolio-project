/**
 * CreateVm — POST /api/vm
 *
 * Body: {
 *   vmName: string,
 *   region: 'centralindia' | 'uaenorth',
 *   adminPassword: string,           // 12-72 chars, Azure complexity rules
 *   createPublicIp?: boolean         // default false (use Bastion)
 * }
 *
 * The supplied admin password is forwarded to the ARM deployment (as a
 * securestring parameter) and ALSO stored in the existing portfolio Key
 * Vault by the inner vmSecret module, so the user can recover it later.
 */
const fs = require('fs');
const path = require('path');
const { DefaultAzureCredential } = require('@azure/identity');
const { ResourceManagementClient } = require('@azure/arm-resources');

const ALLOWED_REGIONS = ['malaysiawest', 'southeastasia', 'centralindia', 'uaenorth', 'austriaeast'];
const VM_LIFETIME_HOURS = 2;
const RG_SUFFIX = '-RG';

const template = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'template.json'), 'utf8')
);

function extractUpn(req) {
    // App Service Easy Auth injects the principal as a base64 JSON header.
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

function sanitiseVmLabel(raw) {
    const cleaned = (raw || '').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 12);
    return cleaned.length >= 2 ? cleaned : null;
}

// Azure VM password rules: 12-72 chars, must contain 3 of: upper, lower,
// digit, special. Reject the obvious reserved values too.
function validatePassword(pw) {
    if (typeof pw !== 'string') return 'adminPassword is required';
    if (pw.length < 12 || pw.length > 72) return 'adminPassword must be 12-72 characters';
    let classes = 0;
    if (/[a-z]/.test(pw)) classes++;
    if (/[A-Z]/.test(pw)) classes++;
    if (/\d/.test(pw)) classes++;
    if (/[^a-zA-Z0-9]/.test(pw)) classes++;
    if (classes < 3) return 'adminPassword must include 3 of: lowercase, uppercase, digit, special character';
    const banned = new Set(['password', 'P@ssw0rd', 'admin', 'administrator', 'demouser']);
    if (banned.has(pw)) return 'adminPassword is not allowed';
    return null;
}

module.exports = async function (context, req) {
    const upn = extractUpn(req);
    if (!upn) {
        context.res = { status: 401, body: { error: 'No authenticated user found' } };
        return;
    }

    const { vmName, region, adminPassword, createPublicIp } = req.body || {};
    const label = sanitiseVmLabel(vmName);
    if (!label) {
        context.res = { status: 400, body: { error: 'vmName must be 2-12 alphanumeric chars' } };
        return;
    }
    if (!ALLOWED_REGIONS.includes(region)) {
        context.res = { status: 400, body: { error: `region must be one of ${ALLOWED_REGIONS.join(', ')}` } };
        return;
    }
    const pwError = validatePassword(adminPassword);
    if (pwError) {
        context.res = { status: 400, body: { error: pwError } };
        return;
    }
    const wantPublicIp = createPublicIp === true || createPublicIp === 'true';

    const subscriptionId = process.env.SUBSCRIPTION_ID;
    const kvName = process.env.KV_NAME;
    const kvResourceGroup = process.env.KV_RESOURCE_GROUP;
    if (!subscriptionId || !kvName || !kvResourceGroup) {
        context.res = { status: 500, body: { error: 'Server misconfigured: missing env vars' } };
        return;
    }

    const client = new ResourceManagementClient(new DefaultAzureCredential(), subscriptionId);
    const rgName = rgNameForUser(upn);

    const exists = await client.resourceGroups.checkExistence(rgName);
    if (exists.body === true || exists === true) {
        context.res = {
            status: 409,
            body: { error: 'You already have an active VM. Wait for auto-delete or remove it manually.', rgName }
        };
        return;
    }

    const expiresAt = new Date(Date.now() + VM_LIFETIME_HOURS * 3600 * 1000).toISOString();
    await client.resourceGroups.createOrUpdate(rgName, {
        location: region,
        tags: {
            owner: upn,
            vmdemo: 'true',
            expiresAt: expiresAt,
            createdBy: 'portfolio-api'
        }
    });

    const deploymentName = `vm-${label}-${Date.now()}`;
    const deployment = {
        properties: {
            mode: 'Incremental',
            template: template,
            parameters: {
                name: { value: label },
                location: { value: region },
                kvName: { value: kvName },
                kvResourceGroup: { value: kvResourceGroup },
                createPublicIp: { value: wantPublicIp },
                adminPassword: { value: adminPassword }
            }
        }
    };

    // Await the initial submission so ARM accepts the deployment before we
    // return. The deployment itself continues running server-side; we don't
    // wait for it to finish. Without awaiting, the Node runtime tears down
    // the async context after the response is sent and the request is lost.
    try {
        await client.deployments.beginCreateOrUpdate(rgName, deploymentName, deployment);
    } catch (err) {
        context.log.error('Deployment start failed:', err.message);
        context.res = {
            status: 502,
            headers: { 'Content-Type': 'application/json' },
            body: { error: `Failed to submit deployment: ${err.message}`, rgName, deploymentId: deploymentName }
        };
        return;
    }

    context.log(`Submitted deployment ${deploymentName} in ${rgName} for ${upn}`);
    context.res = {
        status: 202,
        headers: { 'Content-Type': 'application/json' },
        body: {
            status: 'pending',
            deploymentId: deploymentName,
            rgName: rgName,
            expiresAt: expiresAt,
            pollUrl: `/api/vm/${deploymentName}?rg=${rgName}`
        }
    };
};
