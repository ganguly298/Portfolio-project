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
            body.outputs = {
                vmName: outputs.vmName && outputs.vmName.value,
                adminUsername: outputs.adminUsername && outputs.adminUsername.value,
                publicIp: (outputs.publicIp && outputs.publicIp.value) || '',
                kvSecretReference: outputs.kvSecretReference && outputs.kvSecretReference.value
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
