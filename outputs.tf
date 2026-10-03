output "alb_url" {
  description = "API の URL"
  value       = "http://${aws_lb.main.dns_name}/"
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alert.arn
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.high_request_count.alarm_name
}

output "slack_destination" {
  description = "通知先（ワークスペース名 / チャンネル名）"
  value       = "${aws_chatbot_slack_channel_configuration.alert.slack_team_name} / #${aws_chatbot_slack_channel_configuration.alert.slack_channel_name}"
}

output "test_notification_command" {
  description = "Slack へのテスト通知を送るコマンド（確認後は StateValue=OK で戻す）"
  value       = "aws cloudwatch set-alarm-state --region ${var.aws_region} --alarm-name ${aws_cloudwatch_metric_alarm.high_request_count.alarm_name} --state-value ALARM --state-reason \"テスト通知\""
}
