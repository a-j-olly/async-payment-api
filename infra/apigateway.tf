locals {
  api_url = "${aws_api_gateway_deployment.payment_rest_api_deployment.invoke_url}${aws_api_gateway_stage.dev.stage_name}"
}

data "template_file" "payment_oas_template" {
  template = file("../payment-api-schema.yaml")

  vars = {
    submit_exec_role_arn      = aws_iam_role.payment_api_submit_exec_role.arn
    submit_payment_queue_name = "arn:aws:apigateway:${var.aws_region}:sqs:path/${aws_sqs_queue.submit_payment_queue.name}"
  }
}

resource "aws_api_gateway_rest_api" "payment_rest_api" {
  name        = "payment"
  description = "This API contains operations involving payments"
  body        = data.template_file.payment_oas_template.rendered

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_deployment" "payment_rest_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.payment_rest_api.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.payment_rest_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.payment_rest_api.id
  deployment_id = aws_api_gateway_deployment.payment_rest_api_deployment.id

  xray_tracing_enabled = true
}

resource "aws_api_gateway_method_settings" "payment_rest_api_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.payment_rest_api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
    metrics_enabled        = true
    logging_level          = "ERROR"
    data_trace_enabled     = true
  }
}

resource "aws_api_gateway_api_key" "payment_rest_api_key" {
  name = "payment_api_key"
}

resource "aws_api_gateway_usage_plan" "payment_rest_api_usage_plan" {
  name        = "payment-api-usage-plan"
  description = "Sets the usage policy for consumers. Required to use an API Key"

  api_stages {
    api_id = aws_api_gateway_rest_api.payment_rest_api.id
    stage  = aws_api_gateway_stage.dev.stage_name
  }

  quota_settings {
    limit  = 20
    offset = 2
    period = "WEEK"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

resource "aws_api_gateway_usage_plan_key" "payment_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.payment_rest_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.payment_rest_api_usage_plan.id
}