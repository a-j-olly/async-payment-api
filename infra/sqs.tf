resource "aws_sqs_queue" "submit_payment_queue" {
  name                      = "submit-payment-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 2000
  receive_wait_time_seconds = 20
  sqs_managed_sse_enabled   = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.submit_payment_deadletter_queue.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "submit_payment_deadletter_queue" {
  name                      = "submit-payment-deadletter-queue"
  message_retention_seconds = 864000
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_redrive_allow_policy" "submit_payment_queue_redrive_allow_policy" {
  queue_url = aws_sqs_queue.submit_payment_deadletter_queue.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.submit_payment_queue.arn]
  })
}