import {
	SQSEvent,
	SQSHandler,
	SQSRecord,
	SQSBatchItemFailure,
	SQSBatchResponse,
} from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
let dbClient: DynamoDBClient, docClient: DynamoDBDocumentClient;

export const handler: SQSHandler = async (
	event: SQSEvent
): Promise<SQSBatchResponse> => {
	const batchItemFailures: SQSBatchItemFailure[] = [];

	// Initialise SDK clients
	try {
		dbClient = new DynamoDBClient({
			region: process.env.aws_region,
		});
		docClient = DynamoDBDocumentClient.from(dbClient);
	} catch (error) {
		console.log(`Failed to initialize SDK client: \n${error}`);
		return {
			batchItemFailures,
			...event.Records.map((record) => {
				return { itemIdentifier: record.messageId };
			}),
		};
	}

	// Put records in DynamoDB
	for (const record of event.Records) {
		try {
			await putRecord(docClient, record);
		} catch (error) {
			console.log(`MessageId ${record.messageId}: \n${error}`);
			batchItemFailures.push({ itemIdentifier: record.messageId });
		}
	}

	return { batchItemFailures };
};

// If this function throws an exception, the record will be sent back to SQS after the handler finishes executing.
async function putRecord(
	client: DynamoDBDocumentClient,
	message: SQSRecord
): Promise<void> {
	const Item = JSON.parse(message.body);
	const command = new PutCommand({
		TableName: process.env.payments_table_name,
		Item,
	});
	await client.send(command);
}
