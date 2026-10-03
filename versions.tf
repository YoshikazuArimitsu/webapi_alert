terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # aws_chatbot_slack_channel_configuration は 5.71.0 以降で利用可能
      version = ">= 5.71.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

# ALB / Lambda / CloudWatch / SNS などメインのリソース
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Amazon Q Developer in chat applications（旧 AWS Chatbot）用。
# Chatbot API は限られたリージョンでのみ提供されるため、別プロバイダで管理する。
provider "aws" {
  alias  = "chatbot"
  region = var.chatbot_api_region

  default_tags {
    tags = local.common_tags
  }
}
