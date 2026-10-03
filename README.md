# ALB アクセス過多アラート（Terraform）

インターネット向け ALB → Lambda の Web API を作成し、ALB へのリクエスト数が閾値を超えたら
Amazon Q Developer in chat applications（旧 AWS Chatbot）経由で Slack に通知する構成。

```
Internet ──HTTP:80──▶ ALB ──▶ Lambda (Web API)
                       │
                       └─ RequestCount ─▶ CloudWatch Alarm ─▶ SNS ─▶ Q Developer ─▶ Slack
```

[Amazon CloudWatch でのアラームの使用](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)
[aws_cloudwatch_metric_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm.html)

対象メトリックと閾値の単純比較であればメトリックアラームで直接アラームを上げることができる。
過去と比べたり、動的な監視処理が必要になる場合は Lambda 等でロジックを書く必要がある。
