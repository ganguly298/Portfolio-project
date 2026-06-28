const config = window.PORTFOLIO_CONFIG || {};
const apiBaseUrl = (config.apiBaseUrl || '').replace(/\/$/, '');
const authConfig = config.auth || {};
const authEnabled = Boolean(authConfig.enabled);

const authBar = document.getElementById('auth-bar');
const authStatus = document.getElementById('auth-status');
const loginButton = document.getElementById('login-button');
const logoutButton = document.getElementById('logout-button');
const visitorCount = document.getElementById('visitor-count');

const contactForm = document.getElementById('contact-form');
const formStatus = document.getElementById('form-status');

const vmForm = document.getElementById('vm-form');
const vmStatus = document.getElementById('vm-status');
const vmResult = document.getElementById('vm-result');
const vmPasswordInput = document.getElementById('vm-password-input');
const vmPublicIpCheckbox = document.getElementById('vm-public-ip');
const vmCredentials = document.getElementById('vm-credentials');
const vmCredName = document.getElementById('vm-cred-name');
const vmCredUser = document.getElementById('vm-cred-user');
const vmCredIp = document.getElementById('vm-cred-ip');
const vmCredKv = document.getElementById('vm-cred-kv');
const vmCredHint = document.getElementById('vm-cred-hint');

const myVmsSection = document.getElementById('my-vms-section');
const myVmsList = document.getElementById('my-vms-list');
const myVmsEmpty = document.getElementById('my-vms-empty');
const myVmsRefresh = document.getElementById('my-vms-refresh');

let msalClient = null;
let activeAccount = null;
let myVmsTimer = null;

initializeApp();

loginButton?.addEventListener('click', signIn);
logoutButton?.addEventListener('click', signOut);
myVmsRefresh?.addEventListener('click', () => refreshMyVms());

async function initializeApp() {
    if (!apiBaseUrl) {
        setVmStatus('Missing API base URL — config.js was not generated during deployment.', true);
        return;
    }

    if (authEnabled) {
        const ready = await initializeAuth();
        if (!ready || !activeAccount) {
            setSignedOutState();
            return;
        }
    }

    await bumpVisitorCount();
    setSignedInState();
}

async function initializeAuth() {
    authBar.hidden = false;

    if (!window.msal || !authConfig.tenantId || !authConfig.clientId || !authConfig.apiScope) {
        setVmStatus('Authentication config missing (tenantId, clientId, apiScope).', true);
        return false;
    }

    msalClient = new msal.PublicClientApplication({
        auth: {
            clientId: authConfig.clientId,
            authority: `https://login.microsoftonline.com/${authConfig.tenantId}`,
            redirectUri: window.location.href.split('#')[0]
        },
        cache: { cacheLocation: 'sessionStorage' }
    });

    const redirectResult = await msalClient.handleRedirectPromise();
    activeAccount = redirectResult?.account || msalClient.getAllAccounts()[0] || null;
    if (activeAccount) msalClient.setActiveAccount(activeAccount);

    updateAuthUi();
    return true;
}

async function signIn() {
    try {
        const result = await msalClient.loginPopup({ scopes: [authConfig.apiScope] });
        activeAccount = result.account;
        msalClient.setActiveAccount(activeAccount);
        setSignedInState();
        await bumpVisitorCount();
    } catch (error) {
        setVmStatus(`Sign-in failed: ${error.message}`, true);
    }
}

function signOut() {
    msalClient.logoutPopup({ account: activeAccount }).catch(() => {});
    activeAccount = null;
    setSignedOutState();
}

function setSignedOutState() {
    updateAuthUi();
    visitorCount.textContent = 'Visitors: sign in to count';
    formStatus.textContent = 'Sign in to enable the form.';
    formStatus.classList.remove('error');
    setFormEnabled(contactForm, false);
    setFormEnabled(vmForm, false);
    setVmStatus('Sign in to provision an environment.', false);
    stopMyVmsPolling();
    if (myVmsSection) myVmsSection.hidden = true;
}

function setSignedInState() {
    updateAuthUi();
    formStatus.textContent = 'Submit the form to test POST /api/contact.';
    formStatus.classList.remove('error');
    setFormEnabled(contactForm, true);
    setFormEnabled(vmForm, true);
    setVmStatus('Ready. Pick a name and region above.', false);
    if (myVmsSection) myVmsSection.hidden = false;
    refreshMyVms();
    startMyVmsPolling();
}

function updateAuthUi() {
    if (!authEnabled || !authBar) return;
    const signedIn = Boolean(activeAccount);
    authStatus.textContent = signedIn ? `Signed in as ${activeAccount.username}` : 'Not signed in';
    loginButton.hidden = signedIn;
    logoutButton.hidden = !signedIn;
}

function setFormEnabled(formEl, enabled) {
    if (!formEl) return;
    formEl.querySelectorAll('input, select, textarea, button').forEach(el => { el.disabled = !enabled; });
}

function setVmStatus(text, isError) {
    if (!vmStatus) return;
    vmStatus.textContent = text;
    vmStatus.classList.toggle('error', Boolean(isError));
}

async function apiFetch(path, options = {}) {
    const headers = new Headers(options.headers || {});
    if (authEnabled) {
        const token = await getAccessToken();
        headers.set('Authorization', `Bearer ${token}`);
    }
    return fetch(`${apiBaseUrl}${path}`, { ...options, headers });
}

async function getAccessToken() {
    const request = { account: activeAccount, scopes: [authConfig.apiScope] };
    try {
        const result = await msalClient.acquireTokenSilent(request);
        return result.accessToken;
    } catch {
        const result = await msalClient.acquireTokenPopup(request);
        return result.accessToken;
    }
}

async function bumpVisitorCount() {
    if (!visitorCount) return;
    try {
        const response = await apiFetch('/api/visitors', { method: 'POST' });
        const data = await response.json();
        if (data && typeof data.count === 'number') {
            visitorCount.textContent = `Visitors: ${data.count.toLocaleString()}`;
        } else {
            visitorCount.textContent = 'Visitors: unavailable';
        }
    } catch {
        visitorCount.textContent = 'Visitors: unavailable';
    }
}

// -------- Contact form --------

contactForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const payload = Object.fromEntries(new FormData(contactForm).entries());
    formStatus.textContent = 'Sending message...';
    formStatus.classList.remove('error');
    try {
        const response = await apiFetch('/api/contact', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Contact submission failed');
        contactForm.reset();
        formStatus.textContent = data.message || 'Message sent.';
    } catch (error) {
        formStatus.textContent = error.message;
        formStatus.classList.add('error');
    }
});

// -------- VM provisioning --------

vmForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!authEnabled || !activeAccount) {
        setVmStatus('Sign in first.', true);
        return;
    }
    const formData = new FormData(vmForm);
    const payload = {
        vmName: formData.get('vmName'),
        region: formData.get('region'),
        adminPassword: formData.get('adminPassword'),
        createPublicIp: vmPublicIpCheckbox?.checked === true
    };
    if (!payload.adminPassword || payload.adminPassword.length < 12) {
        setVmStatus('Password must be at least 12 characters.', true);
        return;
    }
    setFormEnabled(vmForm, false);
    vmResult.hidden = true;
    if (vmCredentials) vmCredentials.hidden = true;
    setVmStatus('Submitting deployment...', false);
    try {
        const response = await apiFetch('/api/vm', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
        setVmStatus(`Started deployment ${data.deploymentId} in RG ${data.rgName}. Polling status...`, false);
        await pollVmStatus(data.deploymentId, data.rgName, payload.createPublicIp);
    } catch (err) {
        setVmStatus(`Failed: ${err.message}`, true);
    } finally {
        setFormEnabled(vmForm, true);
        if (vmPasswordInput) vmPasswordInput.value = '';
    }
});

async function pollVmStatus(deploymentId, rgName, wantPublicIp) {
    const start = Date.now();
    const maxMs = 15 * 60 * 1000;
    while (Date.now() - start < maxMs) {
        await new Promise(r => setTimeout(r, 7000));
        try {
            const r = await apiFetch(`/api/vm/${encodeURIComponent(deploymentId)}?rg=${encodeURIComponent(rgName)}`);
            const data = await r.json();
            const elapsed = Math.round((Date.now() - start) / 1000);
            setVmStatus(`Status: ${data.status} (elapsed ${elapsed}s)`, false);
            refreshMyVms();
            if (data.status === 'Succeeded') {
                const connectVia = wantPublicIp && data.outputs?.publicIp
                    ? `RDP to ${data.outputs.publicIp} on port 3389`
                    : 'Azure Bastion (no public IP)';
                setVmStatus(`Done in ${elapsed}s. Connect via ${connectVia}.`, false);
                renderCredentials(data.outputs || {});
                refreshMyVms();
                return;
            }
            if (data.status === 'Failed' || data.status === 'Canceled') {
                setVmStatus(`Deployment ${data.status}`, true);
                vmResult.hidden = false;
                vmResult.textContent = JSON.stringify(data.error || data, null, 2);
                return;
            }
        } catch {
            // transient — keep polling
        }
    }
    setVmStatus('Timed out waiting for deployment.', true);
}

function renderCredentials(outputs) {
    if (!vmCredentials) return;
    vmCredentials.hidden = false;
    vmCredName.textContent = outputs.vmName || '—';
    vmCredUser.textContent = outputs.adminUsername || '—';
    if (outputs.publicIp) {
        vmCredIp.innerHTML = `<code>${escapeHtml(outputs.publicIp)}</code>`;
    } else {
        vmCredIp.textContent = 'none (use Azure Bastion)';
    }
    if (outputs.kvSecretReference) {
        const tenant = authConfig.tenantId || 'common';
        const portalUrl = `https://portal.azure.com/#@${encodeURIComponent(tenant)}/asset/Microsoft_KeyVault/Secret/${outputs.kvSecretReference}`;
        vmCredKv.innerHTML = `<a href="${escapeHtml(portalUrl)}" target="_blank" rel="noopener">open in portal ↗</a>`;
    } else {
        vmCredKv.textContent = '—';
    }
    vmCredHint.textContent = outputs.publicIp
        ? 'RDP from your machine using the username and the password you set. The password is also saved in Key Vault.'
        : 'Open the VM in the Azure Portal and click Connect → Bastion. Use the username and the password you set (also stored in Key Vault).';
}

// -------- My environments --------

async function refreshMyVms() {
    if (!authEnabled || !activeAccount || !myVmsList) return;
    try {
        const response = await apiFetch('/api/my-vms');
        if (!response.ok) {
            renderMyVms([]);
            return;
        }
        const data = await response.json();
        renderMyVms(data.vms || []);
    } catch {
        renderMyVms([]);
    }
}

function renderMyVms(vms) {
    if (!myVmsList) return;
    myVmsList.innerHTML = '';
    if (!vms.length) {
        myVmsEmpty.hidden = false;
        return;
    }
    myVmsEmpty.hidden = true;
    for (const vm of vms) {
        const li = document.createElement('li');
        li.className = 'vm-row';
        const stateClass = (vm.powerState || '').toLowerCase();
        const stateLabel = (vm.powerState || 'unknown').toUpperCase();
        const ipMarkup = vm.publicIp
            ? `<span class="vm-row-ip" title="Public IP"><code>${escapeHtml(vm.publicIp)}</code></span>`
            : `<span class="vm-row-ip vm-row-ip-none" title="No public IP \u2014 use Bastion">private</span>`;
        li.innerHTML = `
            <span class="vm-row-name">${escapeHtml(vm.name)}</span>
            ${ipMarkup}
            <span class="vm-row-loc">${escapeHtml(vm.location || '')}</span>
            <span class="vm-row-state ${stateClass}">${escapeHtml(stateLabel)}</span>
        `;
        myVmsList.appendChild(li);
    }
}

function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
}

function startMyVmsPolling() {
    stopMyVmsPolling();
    myVmsTimer = setInterval(refreshMyVms, 20000);
}

function stopMyVmsPolling() {
    if (myVmsTimer) {
        clearInterval(myVmsTimer);
        myVmsTimer = null;
    }
}
