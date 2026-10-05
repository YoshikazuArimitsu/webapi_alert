data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/api.zip"
}

data "archive_file" "request_count_monitor" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/request-count-monitor.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}-api"
  retention_in_days = var.lambda_log_retention_days
}

resource "aws_lambda_function" "api" {
  function_name    = "${local.name}-api"
  role             = aws_iam_role.lambda.arn
  runtime          = var.lambda_runtime
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda,
  ]
}

# ALB から Lambda を呼び出す許可
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.api.arn
}

data "aws_iam_policy_document" "request_count_monitor" {
  statement {
    sid       = "ReadAlbRequestCount"
    actions   = ["cloudwatch:GetMetricData"]
    resources = ["*"]
  }

  statement {
    sid       = "PublishComparisonResult"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["${local.name}/ALB"]
    }
  }
}

resource "aws_iam_role" "request_count_monitor" {
  name               = "${local.name}-request-count-monitor-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "request_count_monitor_basic" {
  role       = aws_iam_role.request_count_monitor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "request_count_monitor" {
  name   = "${local.name}-request-count-monitor"
  role   = aws_iam_role.request_count_monitor.id
  policy = data.aws_iam_policy_document.request_count_monitor.json
}

resource "aws_cloudwatch_log_group" "request_count_monitor" {
  name              = "/aws/lambda/${local.name}-request-count-monitor"
  retention_in_days = var.lambda_log_retention_days
}

resource "aws_lambda_function" "request_count_monitor" {
  function_name    = "${local.name}-request-count-monitor"
  role             = aws_iam_role.request_count_monitor.arn
  runtime          = var.lambda_runtime
  handler          = "monitor_function.lambda_handler"
  filename         = data.archive_file.request_count_monitor.output_path
  source_code_hash = data.archive_file.request_count_monitor.output_base64sha256
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  environment {
    variables = {
      ALB_ARN_SUFFIX          = aws_lb.main.arn_suffix
      COMPARISON_TIMEZONE     = var.comparison_timezone
      CUSTOM_METRIC_NAMESPACE = "${local.name}/ALB"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.request_count_monitor_basic,
    aws_iam_role_policy.request_count_monitor,
    aws_cloudwatch_log_group.request_count_monitor,
  ]
}

resource "aws_cloudwatch_event_rule" "request_count_monitor" {
  name                = "${local.name}-request-count-monitor"
  description         = "当日累計のALBアクセス数を前日合計と比較します"
  schedule_expression = var.request_count_monitor_schedule_expression
}

resource "aws_cloudwatch_event_target" "request_count_monitor" {
  rule = aws_cloudwatch_event_rule.request_count_monitor.name
  arn  = aws_lambda_function.request_count_monitor.arn
}

resource "aws_lambda_permission" "request_count_monitor_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.request_count_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.request_count_monitor.arn
}
