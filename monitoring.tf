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

resource "aws_cloudwatch_metric_alarm" "previous_day_request_count" {
  alarm_name          = "${local.name}-request-count-exceeds-previous-day"
  alarm_description   = "当日のALBアクセス数累計が前日の合計を超えました"
  namespace           = "${local.name}/ALB"
  metric_name         = "RequestCountExceedsPreviousDay"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alert.arn]
  ok_actions    = var.notify_on_recovery ? [aws_sns_topic.alert.arn] : []
}
