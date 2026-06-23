const config = window.PORTFOLIO_CONFIG || {};
const apiBaseUrl = (config.apiBaseUrl || '').replace(/\/$/, '');
const authConfig = config.auth || {};
const authEnabled = Boolean(authConfig.enabled);

const profileName = document.getElementById('profile-name');
const profileTitle = document.getElementById('profile-title');
const profileAbout = document.getElementById('profile-about');
const profileJson = document.getElementById('profile-json');
const statusPill = document.getElementById('status-pill');
const githubLink = document.getElementById('github-link');
const linkedinLink = document.getElementById('linkedin-link');
const skillsList = document.getElementById('skills-list');
const form = document.getElementById('contact-form');
const formStatus = document.getElementById('form-status');
const visitorCount = document.getElementById('visitor-count');
const authBar = document.getElementById('auth-bar');
const authStatus = document.getElementById('auth-status');
const loginButton = document.getElementById('login-button');
const logoutButton = document.getElementById('logout-button');

let msalClient = null;
let activeAccount = null;

initializeApp();

loginButton?.addEventListener('click', signIn);
logoutButton?.addEventListener('click', signOut);

async function initializeApp() {
    if (!apiBaseUrl) {
        statusPill.textContent = 'Missing API base URL';
        statusPill.classList.add('error');
        profileJson.textContent = 'config.js was not generated during deployment.';
        return;
    }

    if (authEnabled) {
        const authReady = await initializeAuth();
        if (!authReady || !activeAccount) {
            setSignedOutState();
            return;
        }
    }

    await loadProfile();
    await bumpVisitorCount();
}

async function initializeAuth() {
    authBar.hidden = false;

    if (!window.msal || !authConfig.tenantId || !authConfig.clientId || !authConfig.apiScope) {
        statusPill.textContent = 'Authentication config missing';
        statusPill.classList.add('error');
        profileJson.textContent = 'config.js must include auth.tenantId, auth.clientId, and auth.apiScope.';
        return false;
    }

    msalClient = new msal.PublicClientApplication({
        auth: {
            clientId: authConfig.clientId,
            authority: `https://login.microsoftonline.com/${authConfig.tenantId}`,
            redirectUri: window.location.href.split('#')[0]
        },
        cache: {
            cacheLocation: 'sessionStorage'
        }
    });

    const redirectResult = await msalClient.handleRedirectPromise();
    activeAccount = redirectResult?.account || msalClient.getAllAccounts()[0] || null;
    if (activeAccount) {
        msalClient.setActiveAccount(activeAccount);
    }

    updateAuthUi();
    return true;
}

async function signIn() {
    try {
        const result = await msalClient.loginPopup({ scopes: [authConfig.apiScope] });
        activeAccount = result.account;
        msalClient.setActiveAccount(activeAccount);
        updateAuthUi();
        await loadProfile();
        await bumpVisitorCount();
    } catch (error) {
        statusPill.textContent = 'Sign-in failed';
        statusPill.classList.add('error');
        profileJson.textContent = error.message;
    }
}

function signOut() {
    msalClient.logoutPopup({ account: activeAccount }).catch((error) => {
        profileJson.textContent = error.message;
    });
    activeAccount = null;
    setSignedOutState();
}

function setSignedOutState() {
    updateAuthUi();
    statusPill.textContent = 'Sign in to call the API';
    statusPill.classList.remove('ok', 'warn');
    profileJson.textContent = 'The static site is public, but Function API calls require Microsoft Entra ID.';
    visitorCount.textContent = 'Visitors: sign in required';
    formStatus.textContent = 'Sign in to submit the contact form.';
    setFormEnabled(false);
}

function updateAuthUi() {
    if (!authEnabled || !authBar) return;

    const signedIn = Boolean(activeAccount);
    authStatus.textContent = signedIn ? `Signed in as ${activeAccount.username}` : 'Not signed in';
    loginButton.hidden = signedIn;
    logoutButton.hidden = !signedIn;
    setFormEnabled(signedIn);
    if (signedIn) {
        formStatus.textContent = 'Submit the form to test POST /api/contact.';
        formStatus.classList.remove('error');
    }
}

function setFormEnabled(enabled) {
    form.querySelectorAll('input, textarea, button').forEach((element) => {
        element.disabled = !enabled;
    });
}

async function apiFetch(path, options = {}) {
    const headers = new Headers(options.headers || {});

    if (authEnabled) {
        const token = await getAccessToken();
        headers.set('Authorization', `Bearer ${token}`);
    }

    return fetch(`${apiBaseUrl}${path}`, {
        ...options,
        headers
    });
}

async function getAccessToken() {
    const request = {
        account: activeAccount,
        scopes: [authConfig.apiScope]
    };

    try {
        const result = await msalClient.acquireTokenSilent(request);
        return result.accessToken;
    } catch (error) {
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
    } catch (err) {
        visitorCount.textContent = 'Visitors: unavailable';
    }
}

form.addEventListener('submit', async (event) => {
    event.preventDefault();

    const payload = Object.fromEntries(new FormData(form).entries());
    formStatus.textContent = 'Sending message...';

    try {
        const response = await apiFetch('/api/contact', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });
        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Contact submission failed');
        }

        form.reset();
        formStatus.textContent = data.message;
        formStatus.classList.remove('error');
    } catch (error) {
        formStatus.textContent = error.message;
        formStatus.classList.add('error');
    }
});

async function loadProfile() {
    statusPill.textContent = 'Loading profile from Function App';

    try {
        const response = await apiFetch('/api/profile');
        const result = await response.json();

        if (!response.ok) {
            throw new Error('Profile fetch failed');
        }

        renderProfile(result);
    } catch (error) {
        statusPill.textContent = 'API error';
        statusPill.classList.add('error');
        profileJson.textContent = error.message;
    }
}

function renderProfile(result) {
    const profile = result.data || {};

    profileName.textContent = profile.name || 'No name found';
    profileTitle.textContent = profile.title || '';
    profileAbout.textContent = profile.about || '';
    githubLink.href = profile.github || '#';
    githubLink.textContent = profile.github ? 'GitHub Profile' : 'GitHub unavailable';
    if (linkedinLink) {
        linkedinLink.href = profile.linkedin || '#';
        linkedinLink.textContent = profile.linkedin ? 'LinkedIn Profile' : 'LinkedIn unavailable';
        linkedinLink.style.display = profile.linkedin ? '' : 'none';
    }

    statusPill.textContent = `Source: ${result.source}`;
    statusPill.classList.toggle('ok', result.source === 'table-storage');
    statusPill.classList.toggle('warn', result.source !== 'table-storage');

    skillsList.innerHTML = '';
    (profile.skills || []).forEach((skill) => {
        const item = document.createElement('li');
        item.textContent = skill;
        skillsList.appendChild(item);
    });

    profileJson.textContent = JSON.stringify(result, null, 2);
}
