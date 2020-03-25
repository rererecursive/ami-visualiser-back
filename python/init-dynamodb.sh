#!/bin/bash
aws dynamodb put-item --table-name amis --item '{"id": {"S": "unknown"}}'
