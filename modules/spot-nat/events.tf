resource "aws_cloudwatch_event_rule" "route_handler" {
  name           = "${var.name}-route-handler"
  description    = "Event rule for ec2 events for SPOT NAT instance"
  event_bus_name = "default"

  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : [
      "EC2 Instance State-change Notification",
      "EC2 Spot Instance Interruption Warning"
    ]
  })
}

resource "aws_cloudwatch_event_target" "route_handler" {
  rule      = aws_cloudwatch_event_rule.route_handler.name
  target_id = "${var.name}-route_handler"
  arn       = aws_lambda_function.route_handler.arn
}

resource "aws_lambda_permission" "route_handler" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.route_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.route_handler.arn
}
