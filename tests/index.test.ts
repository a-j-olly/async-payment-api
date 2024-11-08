import sqsEvent from "./__fixtures__/sqs-event.json";
import { handler } from "../src/index";

import { mockClient } from "aws-sdk-client-mock";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import "aws-sdk-client-mock-jest";

const ddbMock = mockClient(DynamoDBDocumentClient);

beforeAll(() => {
	process.env.aws_region = "eu-west-2";
	process.env.payments_table_name = "TestTable";
});

afterEach(() => {
	ddbMock.reset();
});

describe("Happy path", () => {
	test("Process multiple records", async () => {
		ddbMock.on(PutCommand).resolves({});

		// @ts-ignore
		const result = await handler(sqsEvent);

		expect(ddbMock).toHaveReceivedNthCommandWith(1, PutCommand, {
			TableName: "TestTable",
			Item: {
				amount: 7.99,
				currency: "GBP",
				dateTimestamp: "1709553600",
				description: "Regular payment made to Netflix from HSBC account",
				paymentId: "paymentId1",
				userId: "userId1",
			},
		});
		expect(ddbMock).toHaveReceivedNthCommandWith(2, PutCommand, {
			TableName: "TestTable",
			Item: {
				amount: 12.99,
				currency: "GBP",
				dateTimestamp: "1709553605",
				description: "Regular payment made to Disney from Natwest account",
				paymentId: "paymentId2",
				userId: "userId2",
			},
		});
		expect(ddbMock).toHaveReceivedNthCommandWith(3, PutCommand, {
			TableName: "TestTable",
			Item: {
				amount: 5.99,
				currency: "GBP",
				dateTimestamp: "1709553608",
				description: "Regular payment made to Audible from HSBC account",
				paymentId: "paymentId3",
				userId: "userId1",
			},
		});
		expect(result).toStrictEqual({ batchItemFailures: [] });
	});
});

describe("Unhappy path", () => {
	test("Returns records that all throw errors", async () => {
		ddbMock.on(PutCommand).rejects(new Error("Failure"));

		// @ts-ignore
		const result = await handler(sqsEvent);

		expect(result).toStrictEqual({
			batchItemFailures: [
				{ itemIdentifier: "messageId1" },
				{ itemIdentifier: "messageId2" },
				{ itemIdentifier: "messageId3" },
			],
		});
	});
	test("Returns the first message", async () => {
		ddbMock.on(PutCommand).rejectsOnce(new Error("Failure")).resolves({});

		// @ts-ignore
		const result = await handler(sqsEvent);

		expect(result).toStrictEqual({
			batchItemFailures: [{ itemIdentifier: "messageId1" }],
		});
	});
});
