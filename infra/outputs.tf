output "api_url" {
  value = local.api_url
}

output "api_key" {
  value = aws_api_gateway_usage_plan_key.payment_usage_plan_key.value
}