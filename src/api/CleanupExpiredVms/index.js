/**
 * CleanupExpiredVms — runs at the top of every hour.
 *
 * Lists all resource groups tagged `vmdemo=true`. If their `expiresAt`
 * tag is in the past, deletes the resource group (which removes the
 * VM, NIC, NSG, VNet, PIP — everything).
 *
 * The KV secret in rg-portfolio-dev is NOT deleted here; secrets are
 * cheap and a left-over secret causes no problems. Could be added later.
 */
const { DefaultAzureCredential } = require('@azure/identity');
const { ResourceManagementClient } = require('@azure/arm-resources');

module.exports = async function (context, timer) {
    const subscriptionId = process.env.SUBSCRIPTION_ID;
    if (!subscriptionId) {
        context.log.warn('SUBSCRIPTION_ID not configured; cleanup skipped');
        return;
    }

    const client = new ResourceManagementClient(new DefaultAzureCredential(), subscriptionId);
    const now = Date.now();
    let scanned = 0;
    let deleted = 0;

    for await (const rg of client.resourceGroups.list()) {
        const tags = rg.tags || {};
        if (tags.vmdemo !== 'true') continue;
        scanned++;

        const expiresAt = Date.parse(tags.expiresAt || '');
        if (!expiresAt || expiresAt > now) continue;

        try {
            await client.resourceGroups.beginDelete(rg.name);
            context.log(`Deleted expired RG ${rg.name} (owner=${tags.owner})`);
            deleted++;
        } catch (err) {
            context.log.error(`Failed to delete ${rg.name}: ${err.message}`);
        }
    }

    context.log(`Cleanup complete. Scanned ${scanned} vmdemo RGs, deleted ${deleted}.`);
};
