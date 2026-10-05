# ALB アクセス過多アラート（Terraform）

インターネット向け ALB → Lambda の Web API を作成し、当日の ALB リクエスト数累計が
前日の合計を超えたら、Amazon Q Developer in chat applications（旧 AWS Chatbot）経由で
Slack に通知する構成。

```
Internet ──HTTP:80──▶ ALB ──▶ Lambda (Web API)
                       │
                       └─ RequestCount ─▶ 比較Lambda ─▶ カスタムメトリクス ─▶ CloudWatch Alarm ─▶ SNS ─▶ Q Developer ─▶ Slack
```

[Amazon CloudWatch でのアラームの使用](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/CloudWatch_Alarms.html)
[aws_cloudwatch_metric_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm.html)

EventBridge が 5 分ごとに比較 Lambda を実行します。Lambda は `AWS/ApplicationELB` の
`RequestCount` を集計し、`comparison_timezone`（既定値: `Asia/Tokyo`）の日付境界で
当日累計と前日合計を比較します。当日累計が前日合計を上回るとカスタムメトリクスに `1` を
出力し、CloudWatch Alarm が SNS 経由で Slack へ一度だけ通知します。アラームは比較結果が
再び `0` になると OK に戻ります。

比較頻度は `request_count_monitor_schedule_expression`（既定値: `rate(5 minutes)`）で変更できます。
