/**
 * ListMyVms — GET /api/my-vms
 *
 * Returns the list of VMs in the signed-in user's per-user RG, with power state.
 * Response: { rgName, vms: [{ name, location, powerState, provisioningState }] }
 */
const { DefaultAzureCredential } = require('@azure/identity');
const { ResourceManagementClient } = require('@azure/arm-resources');
const { ComputeManagementClient } = require('@azure/arm-compute');

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

function pickPowerState(instanceView) {
    const statuses = (instanceView && instanceView.statuses) || [];
    const power = statuses.find(s => s.code && s.code.startsWith('PowerState/'));
    if (!power) return 'unknown';
    return power.code.replace('PowerState/', '');
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

    const credential = new DefaultAzureCredential();
    const resourceClient = new ResourceManagementClient(credential, subscriptionId);
    const rgName = rgNameForUser(upn);

    const exists = await resourceClient.resourceGroups.checkExistence(rgName);
    const rgExists = exists.body === true || exists === true;
    if (!rgExists) {
        context.res = { status: 200, body: { rgName, vms: [] } };
        return;
    }

    const computeClient = new ComputeManagementClient(credential, subscriptionId);

    // Build a map of public IP resource name → ipAddress by scanning the RG.
    const pipAddresses = {};
    try {
        for await (const res of resourceClient.resources.listByResourceGroup(rgName)) {
            if (res.type === 'Microsoft.Network/publicIPAddresses') {
                try {
                    const full = await resourceClient.resources.getById(res.id, '2023-09-01');
                    const ip = full && full.properties && full.properties.ipAddress;
                    if (ip) pipAddresses[res.name] = ip;
                } catch (e) {
                    context.log.warn(`pip getById failed for ${res.name}: ${e.message}`);
                }
            }
        }
    } catch (e) {
        context.log.warn(`listByResourceGroup failed: ${e.message}`);
    }

    // bicep names pips as `pip-<label>-<suffix>` and vms as `vm-<label>`.
    function publicIpForVm(vmName) {
        const label = vmName.replace(/^vm-/, '');
        const prefix = `pip-${label}-`;
        const match = Object.keys(pipAddresses).find(n => n.startsWith(prefix));
        return match ? pipAddresses[match] : '';
    }

    const vms = [];
    try {
        for await (const vm of computeClient.virtualMachines.list(rgName)) {
            let powerState = 'unknown';
            try {
                const iv = await computeClient.virtualMachines.instanceView(rgName, vm.name);
                powerState = pickPowerState(iv);
            } catch (err) {
                context.log.warn(`instanceView failed for ${vm.name}: ${err.message}`);
            }
            vms.push({
                name: vm.name,
                location: vm.location,
                provisioningState: vm.provisioningState,
                powerState,
                publicIp: publicIpForVm(vm.name)
            });
        }
    } catch (err) {
        context.log.error('Listing VMs failed:', err.message);
        context.res = { status: 500, body: { error: err.message, rgName } };
        return;
    }

    context.res = {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: { rgName, vms }
    };
};
