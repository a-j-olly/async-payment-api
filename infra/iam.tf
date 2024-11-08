# 
# API Gateway '/submit' Execution Role
#
resource "aws_iam_role" "payment_api_submit_exec_role" {
  name               = "PaymentAPISubmitExecRole"
  description        = "An execution role that allows the API Gateway to send messages to the submit-payment SQS queue"
  assume_role_policy = file("./iam/assume_policy/APIGatewayAssumePolicy.json")
}

data "template_file" "submit_payment_queue_template" {
  template = file("./iam/permission_policy/PaymentAPISubmitPolicy.json")

  vars = {
    sqs_queue_arn = aws_sqs_queue.submit_payment_queue.arn
  }
}

resource "aws_iam_policy" "submit_payment_queue_policy" {
  name        = "PaymentAPISubmitPolicy"
  description = "A policy granting permission to send messages to the submit-payment SQS queue"
  policy      = data.template_file.submit_payment_queue_template.rendered
}

resource "aws_iam_role_policy_attachment" "payment_api_submit_exec_role_attachment" {
  role       = aws_iam_role.payment_api_submit_exec_role.name
  policy_arn = aws_iam_policy.submit_payment_queue_policy.arn
}

# 
# Lambda Function 'submit-payments' Execution Role
# 
resource "aws_iam_role" "submit_payments_function_exec_role" {
  name               = "SubmitPaymentsFunctionExecRole"
  description        = "An execution role that allows the submit-payments function to assume permissions of the following policy: SubmitPaymentsFunctionPolicy"
  assume_role_policy = file("./iam/assume_policy/LambdaFunctionAssumePolicy.json")
}

data "template_file" "submit_payments_function_template" {
  template = file("./iam/permission_policy/SubmitPaymentsFunctionPolicy.json")

  vars = {
    sqs_queue_arn      = aws_sqs_queue.submit_payment_queue.arn
    dynamodb_table_arn = aws_dynamodb_table.payments_table.arn
  }
}

resource "aws_iam_policy" "submit_payments_function_policy" {
  name        = "SubmitPaymentsFunctionPolicy"
  description = "A policy granting the following permissions to the submit-payments function: send messages to the submit-payment SQS queue, putItems in the PaymentsTable, and write logs to CloudWatch."
  policy      = data.template_file.submit_payments_function_template.rendered
}

resource "aws_iam_role_policy_attachment" "submit_payments_function_exec_role_attachment" {
  role       = aws_iam_role.submit_payments_function_exec_role.name
  policy_arn = aws_iam_policy.submit_payments_function_policy.arn
}