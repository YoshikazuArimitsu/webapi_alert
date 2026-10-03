import json
import datetime


def lambda_handler(event, context):
    body = {
        "message": "Hello from Lambda behind ALB",
        "path": event.get("path"),
        "method": event.get("httpMethod"),
        "time": datetime.datetime.utcnow().isoformat() + "Z",
    }
    return {
        "statusCode": 200,
        "statusDescription": "200 OK",
        "isBase64Encoded": False,
        "headers": {"Content-Type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False),
    }
