# ALB アクセス過多アラート（Terraform）

インターネット向け ALB → Lambda の Web API を作成し、ALB へのリクエスト数が閾値を超えたら
Amazon Q Developer in chat applications（旧 AWS Chatbot）経由で Slack に通知する構成です。

```
Internet ──HTTP:80──▶ ALB ──▶ Lambda (Web API)
                       │
                       └─ RequestCount ─▶ CloudWatch Alarm ─▶ SNS ─▶ Q Developer ─▶ Slack
```

## ファイル構成

| ファイル | 内容 |
|---|---|
| `versions.tf` | Terraform / プロバイダのバージョン、AWS プロバイダ（メイン用・Q Developer 用） |
| `variables.tf` | カスタマイズ用の変数 |
| `network.tf` | VPC、パブリックサブネット×2、IGW、ルートテーブル、ALB 用セキュリティグループ |
| `lambda.tf` | Lambda 関数、IAM ロール、ロググループ、ALB からの呼び出し許可 |
| `alb.tf` | ALB、ターゲットグループ（Lambda）、HTTP リスナー |
| `monitoring.tf` | SNS トピック、CloudWatch アラーム（RequestCount） |
| `chatbot.tf` | Q Developer の Slack チャネル設定と IAM ロール |
| `outputs.tf` | URL やテスト通知コマンドなど |
| `lambda/lambda_function.py` | Web API の Lambda コード |
| `terraform.tfvars.example` | 変数設定のサンプル |

## 事前準備

1. Terraform 1.5 以上と AWS CLI をインストールし、AWS の認証情報を設定する。
2. **Slack ワークスペースを Q Developer で認可する**（Terraform ではできないため手動）。
   AWS コンソール →「Amazon Q Developer in chat applications」→「新しいクライアントを設定」→ Slack →
   Slack 側で対象ワークスペースを選んで「許可する」。
3. 通知先の ID を調べる。
   - ワークスペース ID（`T...`）: Q Developer コンソールのワークスペース詳細、またはブラウザ版 Slack の URL `app.slack.com/client/<ワークスペースID>/...`
   - チャンネル ID（`C...`）: Slack でチャンネル名を右クリック →「チャンネル詳細を表示」の一番下
   - プライベートチャンネルの場合は、そのチャンネルで `/invite @Amazon Q` を実行しておく。

## 使い方

```powershell
cd F:\work\webapi_alert
copy terraform.tfvars.example terraform.tfvars   # 値を編集
terraform init
terraform plan
terraform apply
```

apply 後、`alb_url` の URL をブラウザで開くと Lambda の JSON が返ります。

### Slack へのテスト通知

```powershell
terraform output -raw test_notification_command   # 表示されたコマンドを実行
aws cloudwatch set-alarm-state --region ap-northeast-1 --alarm-name alb-alert-high-request-count --state-value OK --state-reason "テスト終了"
```

## 主な変数

| 変数 | デフォルト | 説明 |
|---|---|---|
| `slack_team_id` | （必須） | 通知先 Slack ワークスペース ID |
| `slack_channel_id` | （必須） | 通知先チャンネル ID |
| `request_count_threshold` | `1000` | この件数を超えたらアラーム |
| `alarm_period_seconds` | `60` | 集計期間（秒、60 の倍数） |
| `alarm_evaluation_periods` | `1` | 評価する期間の数 |
| `alarm_datapoints_to_alarm` | `1` | 何期間超えたらアラームにするか |
| `notify_on_recovery` | `true` | 正常復帰時も通知するか |
| `project_name` | `alb-alert` | リソース名の接頭辞 |
| `aws_region` | `ap-northeast-1` | 構築リージョン |
| `vpc_cidr` / `public_subnets` | `10.20.0.0/16` ほか | ネットワーク |
| `alb_ingress_cidrs` | `["0.0.0.0/0"]` | ALB へのアクセス元制限 |
| `lambda_runtime` / `lambda_memory_size` / `lambda_timeout` | `python3.13` / `128` / `10` | Lambda 設定 |
| `chatbot_api_region` | `us-east-2` | Q Developer API のリージョン |
| `chatbot_guardrail_policy_arns` | `ReadOnlyAccess` | Slack から実行できる操作の上限 |
| `chatbot_logging_level` | `ERROR` | Q Developer のログレベル |

例：「5 分間に 5000 件超が 2 回続いたら通知」にする場合

```hcl
request_count_threshold   = 5000
alarm_period_seconds      = 300
alarm_evaluation_periods  = 2
alarm_datapoints_to_alarm = 2
```

## 既存環境（手作業で構築したもの）との関係

2026-10-03 に AWS MCP で構築した環境（CloudFormation スタック `alb-alert-stack` と、
API で作成した VPC・IAM ロール・Q Developer 設定 `alb-alert-slack`）はこのコードの管理外です。
同じ `project_name = "alb-alert"` のまま apply すると、ALB・ターゲットグループ・IAM ロール・
Q Developer 設定の名前が重複してエラーになります。次のどちらかで対応してください。

- **Terraform に置き換える**: 既存環境を削除してから apply する
  （Q Developer 設定 `alb-alert-slack` → スタック `alb-alert-stack` → IAM ロール 2 つ → VPC 一式の順に削除）。
- **並行して作る**: `project_name` を別の名前（例 `alb-alert-tf`）にし、`vpc_cidr` も重ならない値にする。

## 削除

```powershell
terraform destroy
```

Slack ワークスペースの認可は削除されません。不要なら Q Developer コンソールから削除してください。
