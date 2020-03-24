#!/bin/bash
BUCKET="ztlewis"
PREFIX="packer-builds"
FOLDER=$(grep -m 1 "Prevalidating AMI Name" output.log | awk '{print $NF}' | sed 's@/@-@g')

aws s3 cp --recursive logs/ s3://$BUCKET/$PREFIX/$FOLDER/
