/**
 * GetProfile — Reads profile data from Azure Table Storage using managed identity.
 * No connection string, no storage keys: TableClient + DefaultAzureCredential.
 */
const { TableClient } = require('@azure/data-tables');
const { DefaultAzureCredential } = require('@azure/identity');

const credential = new DefaultAzureCredential();

module.exports = async function (context, req) {
    try {
        const accountName = process.env.STORAGE_ACCOUNT_NAME;
        if (!accountName) {
            throw new Error('STORAGE_ACCOUNT_NAME not configured');
        }
        const tableClient = new TableClient(
            `https://${accountName}.table.core.windows.net`,
            'profiles',
            credential
        );

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
                    github: 'https://github.com/ganguly298',
                    linkedin: 'https://www.linkedin.com/in/saurav-ganguly-8b1542279'
                }
            }
        };
    }
};
