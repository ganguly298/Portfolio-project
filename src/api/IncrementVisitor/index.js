/**
 * IncrementVisitor — Atomically increments a visitor counter in Table Storage
 * using ETag-based optimistic concurrency. Returns the new count.
 */
const { TableClient, odata } = require('@azure/data-tables');
const { DefaultAzureCredential } = require('@azure/identity');

const credential = new DefaultAzureCredential();
const PARTITION_KEY = 'counter';
const ROW_KEY = 'visitors';
const MAX_RETRIES = 5;

module.exports = async function (context, req) {
    try {
        const accountName = process.env.STORAGE_ACCOUNT_NAME;
        if (!accountName) {
            throw new Error('STORAGE_ACCOUNT_NAME not configured');
        }
        const tableClient = new TableClient(
            `https://${accountName}.table.core.windows.net`,
            'counters',
            credential
        );

        let count = 0;
        let success = false;

        for (let attempt = 0; attempt < MAX_RETRIES && !success; attempt++) {
            try {
                const entity = await tableClient.getEntity(PARTITION_KEY, ROW_KEY);
                const newCount = (entity.count || 0) + 1;
                await tableClient.updateEntity(
                    {
                        partitionKey: PARTITION_KEY,
                        rowKey: ROW_KEY,
                        count: newCount
                    },
                    'Replace',
                    { etag: entity.etag }
                );
                count = newCount;
                success = true;
            } catch (err) {
                if (err.statusCode === 404) {
                    // First visitor ever — create the row.
                    try {
                        await tableClient.createEntity({
                            partitionKey: PARTITION_KEY,
                            rowKey: ROW_KEY,
                            count: 1
                        });
                        count = 1;
                        success = true;
                    } catch (createErr) {
                        if (createErr.statusCode !== 409) throw createErr;
                        // Someone else just created it; loop and update.
                    }
                } else if (err.statusCode === 412) {
                    // ETag mismatch — another writer beat us. Retry.
                    continue;
                } else {
                    throw err;
                }
            }
        }

        if (!success) {
            throw new Error('Counter update failed after retries');
        }

        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-store'
            },
            body: { success: true, count }
        };
    } catch (err) {
        context.log.error('Visitor counter failed:', err.message);
        context.res = {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
            body: { success: false, error: err.message }
        };
    }
};
