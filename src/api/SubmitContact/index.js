/**
 * SubmitContact — Saves contact form data to Table Storage + triggers Logic App
 */
const { TableClient } = require('@azure/data-tables');

module.exports = async function (context, req) {
    const { name, email, message } = req.body || {};

    if (!name || !email || !message) {
        context.res = {
            status: 400,
            headers: { 'Content-Type': 'application/json' },
            body: { error: 'Missing required fields: name, email, message' }
        };
        return;
    }

    // Save to Table Storage
    try {
        const connectionString = process.env.TABLE_STORAGE_CONNECTION;
        const tableClient = TableClient.fromConnectionString(connectionString, 'contacts');

        await tableClient.createEntity({
            partitionKey: 'contact',
            rowKey: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            name: name,
            email: email,
            message: message,
            submittedAt: new Date().toISOString()
        });

        context.log(`Contact saved from: ${email}`);
    } catch (err) {
        context.log.error('Table Storage write failed:', err.message);
    }

    // Forward to Logic App HTTP trigger (if configured)
    const logicAppUrl = process.env.LOGIC_APP_CALLBACK_URL;
    if (logicAppUrl) {
        try {
            const payload = JSON.stringify({ name, email, message });
            const response = await fetch(logicAppUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(payload).toString()
                },
                body: payload
            });
            context.log(`Logic App responded with status: ${response.status}`);
        } catch (err) {
            context.log.warn('Logic App trigger failed:', err.message);
        }
    } else {
        context.log.warn('LOGIC_APP_CALLBACK_URL not configured');
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
