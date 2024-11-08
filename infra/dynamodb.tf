resource "aws_dynamodb_table" "payments_table" {
  name           = "PaymentsTable"
  billing_mode   = "PROVISIONED"
  read_capacity  = 2
  write_capacity = 2
  hash_key       = "paymentId"
  range_key      = "userId"

  attribute {
    name = "paymentId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }
}

resource "aws_appautoscaling_target" "payments_table_write_target" {
  max_capacity       = 20
  min_capacity       = 2
  resource_id        = "table/${aws_dynamodb_table.payments_table.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "payments_table_write_policy" {
  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.payments_table_write_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.payments_table_write_target.resource_id
  scalable_dimension = aws_appautoscaling_target.payments_table_write_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.payments_table_write_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = 70
  }
}