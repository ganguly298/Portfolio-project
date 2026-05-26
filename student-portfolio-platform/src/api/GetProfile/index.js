/**
 * GetProfile — Queries the "legacy" PostgreSQL database on the VM
 * via the VNet private IP (The Handshake)
 */
const { Client } = require('pg');

module.exports = async function (context, req) {
    const client = new Client({
        host: process.env.DB_HOST,       // VM private IP (10.0.1.4)
        port: parseInt(process.env.DB_PORT || '5432'),
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME,
        ssl: false  // Internal VNet traffic, no SSL needed
    });

    try {
        await client.connect();
        const result = await client.query('SELECT * FROM profile LIMIT 1');
        await client.end();

        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: {
                success: true,
                data: result.rows[0] || {
                    name: "Saurav Ganguly",
                    title: "Cloud Engineering Student",
                    skills: ["Azure", "Bicep", "IaC", "DevOps", "Python"],
                    about: "Learning cloud infrastructure with Azure for Students"
                }
            }
        };
    } catch (error) {
        context.log.error('DB connection error:', error.message);
        // Fallback: return static data if DB is unavailable
        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: {
                success: true,
                source: 'fallback',
                data: {
                    name: "Saurav Ganguly",
                    title: "Cloud Engineering Student",
                    skills: ["Azure", "Bicep", "IaC", "DevOps", "Python"],
                    about: "Learning cloud infrastructure with Azure for Students"
                }
            }
        };
    }
};
