data "archive_file" "submit_payments_function_archive" {
  type        = "zip"
  source_file = "../dist/index.mjs"
  output_path = "../dist/lambda-archive.zip"
}

resource "aws_lambda_function" "submit_payments_function" {
  function_name    = "submit-payments"
  filename         = data.archive_file.submit_payments_function_archive.output_path
  source_code_hash = data.archive_file.submit_payments_function_archive.output_base64sha256
  role             = aws_iam_role.submit_payments_function_exec_role.arn
  memory_size      = 128
  handler          = "index.handler"
  runtime          = "nodejs20.x"

  environment {
    variables = {
      aws_region          = var.aws_region
      payments_table_name = aws_dynamodb_table.payments_table.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "submit_payment_queue_event_mapping" {
  event_source_arn        = aws_sqs_queue.submit_payment_queue.arn
  function_name           = aws_lambda_function.submit_payments_function.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }

  depends_on = [
    aws_iam_role_policy_attachment.submit_payments_function_exec_role_attachment
  ]
}