#!/bin/bash
set -e

SOURCE_IMAGE_ID=$(grep -m 1 "Found Image ID:" logs/output.log | awk '{print $NF}')

if [[ -z $SOURCE_IMAGE_ID ]]; then
    echo "ERROR: the source image ID could not be extracted."
    exit 1
fi

aws ec2 describe-images \
    --image-ids $SOURCE_IMAGE_ID \
    --query 'Images[0]' > source.json

aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$SOURCE_IMAGE_ID Name=resource-type,Values=image" > tags.json
jq -s '.[0] * .[1]' source.json tags.json > logs/source-ami.json

rm -rf source.json tags.json

