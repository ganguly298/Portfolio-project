/**
 * GetVmStatus — GET /api/vm/{deploymentId}?rg=<rgName>
 *
 * Returns the current state of an ARM deployment.
 * When status === 'Succeeded', the body includes the deployment outputs
 * (vmName, adminUsername, kvSecretReference). Connect via Azure Bastion.
 */
const { DefaultAzureCredential } = require('@azure/identity');
const { ResourceManagementClient } = require('@azure/arm-resources');

module.exports = async function (context, req) {
    const deploymentId = context.bindingData.deploymentId;
    const rgName = (req.query && req.query.rg) || '';

    if (!deploymentId || !rgName) {
        context.res = { status: 400, body: { error: 'Missing deploymentId or ?rg= query param' } };
        return;
    }

    const subscriptionId = process.env.SUBSCRIPTION_ID;
    if (!subscriptionId) {
        context.res = { status: 500, body: { error: 'SUBSCRIPTION_ID not configured' } };
        return;
    }

    const client = new ResourceManagementClient(new DefaultAzureCredential(), subscriptionId);

    try {
        const result = await client.deployments.get(rgName, deploymentId);
        const state = result.properties && result.properties.provisioningState;
        const body = {
            deploymentId,
            rgName,
            status: state || 'Unknown'
        };

        if (state === 'Succeeded') {
            const outputs = (result.properties && result.properties.outputs) || {};
            const kvSecretRef = outputs.kvSecretReference && outputs.kvSecretReference.value;
            let kvSecretPortalUrl = '';
            if (kvSecretRef) {
                // kvSecretRef looks like https://<vault>.vault.azure.net/secrets/<name>
                const m = kvSecretRef.match(/^https:\/\/([^.]+)\.vault\.azure\.net\/secrets\/([^/?]+)/i);
                const tenantId = process.env.TENANT_ID || '';
                const kvRg = process.env.KV_RESOURCE_GROUP || rgName;
                if (m) {
                    const vaultName = m[1];
                    const secretName = m[2];
                    const armId = `/subscriptions/${subscriptionId}/resourceGroups/${kvRg}/providers/Microsoft.KeyVault/vaults/${vaultName}/secrets/${secretName}`;
                    const tenantSeg = tenantId ? `@${tenantId}` : '';
                    kvSecretPortalUrl = `https://portal.azure.com/#${tenantSeg}/resource${armId}`;
                }
            }
            body.outputs = {
                vmName: outputs.vmName && outputs.vmName.value,
                adminUsername: outputs.adminUsername && outputs.adminUsername.value,
                publicIp: (outputs.publicIp && outputs.publicIp.value) || '',
                kvSecretReference: kvSecretRef,
                kvSecretPortalUrl
            };
        } else if (state === 'Failed') {
            body.error = (result.properties && result.properties.error) || 'Deployment failed';
        }

        context.res = { status: 200, headers: { 'Content-Type': 'application/json' }, body };
    } catch (err) {
        if (err.statusCode === 404) {
            context.res = { status: 404, body: { error: 'Deployment not found' } };
        } else {
            context.log.error('GetVmStatus error:', err.message);
            context.res = { status: 500, body: { error: err.message } };
        }
    }
};
