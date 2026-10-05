import datetime
import logging
import os
from zoneinfo import ZoneInfo

import boto3


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

cloudwatch = boto3.client("cloudwatch")


def get_request_count(start_time, end_time, load_balancer):
    response = cloudwatch.get_metric_data(
        MetricDataQueries=[
            {
                "Id": "request_count",
                "MetricStat": {
                    "Metric": {
                        "Namespace": "AWS/ApplicationELB",
                        "MetricName": "RequestCount",
                        "Dimensions": [
                            {"Name": "LoadBalancer", "Value": load_balancer},
                        ],
                    },
                    "Period": 300,
                    "Stat": "Sum",
                },
                "ReturnData": True,
            },
        ],
        StartTime=start_time,
        EndTime=end_time,
        ScanBy="TimestampAscending",
    )
    return sum(response["MetricDataResults"][0]["Values"])


def lambda_handler(event, context):
    timezone = ZoneInfo(os.environ["COMPARISON_TIMEZONE"])
    now = datetime.datetime.now(timezone)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    yesterday_start = today_start - datetime.timedelta(days=1)
    load_balancer = os.environ["ALB_ARN_SUFFIX"]

    today_request_count = get_request_count(today_start, now, load_balancer)
    yesterday_request_count = get_request_count(
        yesterday_start, today_start, load_balancer
    )
    exceeds_previous_day = int(today_request_count > yesterday_request_count)

    cloudwatch.put_metric_data(
        Namespace=os.environ["CUSTOM_METRIC_NAMESPACE"],
        MetricData=[
            {
                "MetricName": "RequestCountExceedsPreviousDay",
                "Dimensions": [
                    {"Name": "LoadBalancer", "Value": load_balancer},
                ],
                "Unit": "Count",
                "Value": exceeds_previous_day,
            },
        ],
    )

    result = {
        "today_request_count": today_request_count,
        "yesterday_request_count": yesterday_request_count,
        "exceeds_previous_day": bool(exceeds_previous_day),
    }
    LOGGER.info("ALB request count comparison: %s", result)
    return result
