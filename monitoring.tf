resource "aws_sns_topic" "alert" {
  name = "${local.name}-topic"
}

data "aws_iam_policy_document" "alert_topic" {
  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alert.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alert" {
  arn    = aws_sns_topic.alert.arn
  policy = data.aws_iam_policy_document.alert_topic.json
}

resource "aws_cloudwatch_metric_alarm" "high_request_count" {
  alarm_name = "${local.name}-high-request-count"
  alarm_description = format(
    "ALBへのリクエスト数が%d秒間に%d件を超えました",
    var.alarm_period_seconds,
    var.request_count_threshold,
  )

  namespace           = "AWS/ApplicationELB"
  metric_name         = "RequestCount"
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  datapoints_to_alarm = var.alarm_datapoints_to_alarm
  threshold           = var.request_count_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alert.arn]
  ok_actions    = var.notify_on_recovery ? [aws_sns_topic.alert.arn] : []
}
