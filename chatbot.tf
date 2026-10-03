# Slack ワークスペースの認可（OAuth）は Terraform では行えないため、
# 事前に AWS コンソールの「Amazon Q Developer in chat applications」で
# 対象ワークスペースを追加しておくこと（README 参照）。

data "aws_iam_policy_document" "chatbot_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chatbot" {
  name               = "${local.name}-chatbot-role"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume.json
}

resource "aws_iam_role_policy_attachment" "chatbot" {
  for_each = toset(var.chatbot_role_policy_arns)

  role       = aws_iam_role.chatbot.name
  policy_arn = each.value
}

resource "aws_chatbot_slack_channel_configuration" "alert" {
  provider = aws.chatbot

  configuration_name    = "${local.name}-slack"
  iam_role_arn          = aws_iam_role.chatbot.arn
  slack_team_id         = var.slack_team_id
  slack_channel_id      = var.slack_channel_id
  sns_topic_arns        = [aws_sns_topic.alert.arn]
  guardrail_policy_arns = var.chatbot_guardrail_policy_arns
  logging_level         = var.chatbot_logging_level
}
