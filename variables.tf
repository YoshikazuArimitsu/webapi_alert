############################################
# 共通
############################################
variable "project_name" {
  description = "リソース名の接頭辞。既存環境と並べて作る場合は別の名前にする"
  type        = string
  default     = "alb-alert"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name は英小文字・数字・ハイフンで 20 文字以内にしてください（ALB/ターゲットグループ名の長さ制限のため）。"
  }
}

variable "aws_region" {
  description = "ALB・Lambda・アラームを作成するリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "tags" {
  description = "全リソースに付与する追加タグ"
  type        = map(string)
  default     = {}
}

############################################
# ネットワーク
############################################
variable "vpc_cidr" {
  description = "VPC の CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnets" {
  description = "パブリックサブネット（AZ 名 => CIDR）。ALB には 2 つ以上の AZ が必要"
  type        = map(string)
  default = {
    "ap-northeast-1a" = "10.20.0.0/24"
    "ap-northeast-1c" = "10.20.1.0/24"
  }

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "ALB には 2 つ以上の AZ のサブネットが必要です。"
  }
}

variable "alb_ingress_cidrs" {
  description = "ALB（HTTP:80）へのアクセスを許可する送信元 CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

############################################
# Lambda
############################################
variable "lambda_runtime" {
  description = "Lambda のランタイム"
  type        = string
  default     = "python3.13"
}

variable "lambda_memory_size" {
  description = "Lambda のメモリ（MB）"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda のタイムアウト（秒）"
  type        = number
  default     = 10
}

variable "lambda_log_retention_days" {
  description = "Lambda の CloudWatch Logs 保持日数"
  type        = number
  default     = 14
}

############################################
# 前日比アクセス数アラーム
############################################
variable "comparison_timezone" {
  description = "前日・当日の境界に使用する IANA タイムゾーン"
  type        = string
  default     = "Asia/Tokyo"
}

variable "request_count_monitor_schedule_expression" {
  description = "前日比を判定するEventBridgeスケジュール式"
  type        = string
  default     = "rate(5 minutes)"
}

variable "notify_on_recovery" {
  description = "アラームが正常（OK）に戻ったときも Slack に通知するか"
  type        = bool
  default     = true
}

############################################
# Slack 通知（Amazon Q Developer in chat applications）
############################################
variable "slack_team_id" {
  description = "Q Developer で認可済みの Slack ワークスペース ID（T で始まる）"
  type        = string

  validation {
    condition     = can(regex("^T[A-Z0-9]+$", var.slack_team_id))
    error_message = "slack_team_id は T で始まるワークスペース ID を指定してください。"
  }
}

variable "slack_channel_id" {
  description = "通知先 Slack チャンネル ID（C で始まる。プライベートチャンネルは G の場合あり）"
  type        = string

  validation {
    condition     = can(regex("^[CG][A-Z0-9]+$", var.slack_channel_id))
    error_message = "slack_channel_id は C または G で始まるチャンネル ID を指定してください。"
  }
}

variable "chatbot_api_region" {
  description = "Q Developer（Chatbot）API を呼ぶリージョン。us-east-2 / us-west-2 / eu-west-1 / ap-southeast-1 など対応リージョンのみ"
  type        = string
  default     = "us-east-2"
}

variable "chatbot_guardrail_policy_arns" {
  description = "Slack から実行できる操作の上限（ガードレール）となる IAM ポリシー"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

variable "chatbot_role_policy_arns" {
  description = "Q Developer のチャネルロールに付与する IAM ポリシー"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"]
}

variable "chatbot_logging_level" {
  description = "Q Developer の CloudWatch Logs 出力レベル（ERROR / INFO / NONE）"
  type        = string
  default     = "ERROR"

  validation {
    condition     = contains(["ERROR", "INFO", "NONE"], var.chatbot_logging_level)
    error_message = "chatbot_logging_level は ERROR / INFO / NONE のいずれかです。"
  }
}
