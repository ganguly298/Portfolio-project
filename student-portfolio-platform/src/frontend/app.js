/**
 * app.js — Frontend logic for Student Portfolio Platform
 * Calls the Function App API to fetch profile data and submit contact form
 */

// Replace with your Function App URL after deployment
const API_BASE = '/api'; // Static Web App proxies to linked Function App

// Load profile on page load
document.addEventListener('DOMContentLoaded', loadProfile);

async function loadProfile() {
    try {
        const response = await fetch(`${API_BASE}/profile`);
        const result = await response.json();
        const data = result.data;

        document.getElementById('profile-name').textContent = data.name;
        document.getElementById('profile-title').textContent = data.title;
        document.getElementById('profile-about').textContent = data.about;

        const skillsContainer = document.getElementById('skills-container');
        data.skills.forEach(skill => {
            const badge = document.createElement('span');
            badge.className = 'skill-badge';
            badge.textContent = skill;
            skillsContainer.appendChild(badge);
        });
    } catch (error) {
        console.error('Failed to load profile:', error);
        document.getElementById('profile-name').textContent = 'Portfolio';
        document.getElementById('profile-about').textContent = 'Unable to load profile data. The Function App may not be running.';
    }
}

// Contact form submission
document.getElementById('contact-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const status = document.getElementById('contact-status');

    const payload = {
        name: document.getElementById('contact-name').value,
        email: document.getElementById('contact-email').value,
        message: document.getElementById('contact-message').value
    };

    try {
        const response = await fetch(`${API_BASE}/contact`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const result = await response.json();

        if (result.success) {
            status.textContent = result.message;
            status.className = 'success';
            document.getElementById('contact-form').reset();
        } else {
            status.textContent = result.error || 'Something went wrong.';
            status.className = 'error';
        }
    } catch (error) {
        status.textContent = 'Network error. Please try again.';
        status.className = 'error';
    }
});
