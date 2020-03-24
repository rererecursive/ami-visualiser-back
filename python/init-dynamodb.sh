#!/bin/bash
aws dynamodb put-item --table-name amis --item file://unknown.json
