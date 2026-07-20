import json, os, boto3
from decimal import Decimal

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    if method == "GET":
        items = table.scan()["Items"]
        return {"statusCode": 200, "body": json.dumps(items, default=str)}
    if method == "POST":
        item = json.loads(event["body"], parse_float=Decimal)
        table.put_item(Item=item)
        return {"statusCode": 201, "body": json.dumps(item, default=str)}
    if method == "PUT":
        item = json.loads(event["body"], parse_float=Decimal)
        table.put_item(Item=item)
        return {"statusCode": 200, "body": json.dumps(item, default=str)}
    if method == "DELETE":
        coffee_id = event["queryStringParameters"]["coffeeId"]
        table.delete_item(Key={"coffeeId": coffee_id})
        return {"statusCode": 204}
    return {"statusCode": 405, "body": "Method not allowed"}