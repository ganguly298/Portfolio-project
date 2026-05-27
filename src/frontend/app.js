const config = window.PORTFOLIO_CONFIG || {};
const apiBaseUrl = (config.apiBaseUrl || '').replace(/\/$/, '');

const profileName = document.getElementById('profile-name');
const profileTitle = document.getElementById('profile-title');
const profileAbout = document.getElementById('profile-about');
const profileJson = document.getElementById('profile-json');
const statusPill = document.getElementById('status-pill');
const githubLink = document.getElementById('github-link');
const skillsList = document.getElementById('skills-list');
const form = document.getElementById('contact-form');
const formStatus = document.getElementById('form-status');

if (!apiBaseUrl) {
    statusPill.textContent = 'Missing API base URL';
    statusPill.classList.add('error');
    profileJson.textContent = 'config.js was not generated during deployment.';
} else {
    loadProfile();
}

form.addEventListener('submit', async (event) => {
    event.preventDefault();

    const payload = Object.fromEntries(new FormData(form).entries());
    formStatus.textContent = 'Sending message...';

    try {
        const response = await fetch(`${apiBaseUrl}/api/contact`, {
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
        const response = await fetch(`${apiBaseUrl}/api/profile`);
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
