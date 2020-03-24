#!/bin/bash
set -e

BAKED_IMAGE_ID=$(jq -r '.builds[-1].artifact_id' logs/manifest.json | cut -d: -f2)
echo "Baked image ID: ${BAKED_IMAGE_ID}"

aws ec2 describe-images \
    --image-ids $BAKED_IMAGE_ID \
    --query 'Images[0]' > produced.json

aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$BAKED_IMAGE_ID Name=resource-type,Values=image" > tags.json
jq -s '.[0] * .[1]' produced.json tags.json > logs/produced-ami.json

rm -rf produced.json tags.json
