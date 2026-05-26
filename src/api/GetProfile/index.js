/**
 * GetProfile — Reads profile data from Azure Table Storage
 * No VNet needed — Function App connects to Table Storage via connection string
 */
const { TableClient } = require('@azure/data-tables');

module.exports = async function (context, req) {
    try {
        const connectionString = process.env.TABLE_STORAGE_CONNECTION;
        const tableClient = TableClient.fromConnectionString(connectionString, 'profiles');

        // Try to get profile from Table Storage
        const entity = await tableClient.getEntity('portfolio', 'saurav');

        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: {
                success: true,
                source: 'table-storage',
                data: {
                    name: entity.name,
                    title: entity.title,
                    about: entity.about,
                    skills: JSON.parse(entity.skills || '[]'),
                    github: entity.github || '',
                    linkedin: entity.linkedin || ''
                }
            }
        };
    } catch (error) {
        context.log.warn('Table Storage read failed:', error.message);

        // Fallback: return default data (useful before seeding)
        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: {
                success: true,
                source: 'default',
                data: {
                    name: 'Saurav Ganguly',
                    title: 'Cloud Engineering Student',
                    about: 'Learning cloud infrastructure with Azure for Students. Building serverless APIs and managing IaC with Bicep.',
                    skills: ['Azure', 'Bicep', 'IaC', 'DevOps', 'Python', 'Node.js'],
                    github: 'https://github.com/saurav',
                    linkedin: ''
                }
            }
        };
    }
};
