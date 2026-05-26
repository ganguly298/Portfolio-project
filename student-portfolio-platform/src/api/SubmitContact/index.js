/**
 * SubmitContact — Receives contact form data and triggers Logic App
 */
const https = require('https');

module.exports = async function (context, req) {
    const { name, email, message } = req.body || {};

    if (!name || !email || !message) {
        context.res = {
            status: 400,
            body: { error: 'Missing required fields: name, email, message' }
        };
        return;
    }

    // Forward to Logic App HTTP trigger
    const logicAppUrl = process.env.LOGIC_APP_CALLBACK_URL;

    if (logicAppUrl) {
        try {
            await postToLogicApp(logicAppUrl, { name, email, message });
            context.log(`Contact form forwarded to Logic App from: ${email}`);
        } catch (err) {
            context.log.warn('Logic App trigger failed:', err.message);
        }
    }

    context.res = {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
            success: true,
            message: `Thank you ${name}, your message has been received!`
        }
    };
};

function postToLogicApp(url, data) {
    return new Promise((resolve, reject) => {
        const parsedUrl = new URL(url);
        const options = {
            hostname: parsedUrl.hostname,
            path: parsedUrl.pathname + parsedUrl.search,
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        };
        const req = https.request(options, (res) => {
            res.on('data', () => {});
            res.on('end', () => resolve());
        });
        req.on('error', reject);
        req.write(JSON.stringify(data));
        req.end();
    });
}
