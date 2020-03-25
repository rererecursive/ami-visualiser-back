REGION?=ap-southeast-2
APPLICATION?=web
S3_BUCKET?=ztlewis-builds
S3_PREFIX?=packer-builds

GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_COMMIT := $(shell git rev-parse --short HEAD)
BUILD_DATE := $(shell date +%Y-%m-%d"T"%H-%M-%S)

TEMPLATE_IN=template.pkr.hcl
TEMPLATE_OUT=template_out.pkr.hcl
OHAI=ohai_tmp.log
SHELL=/bin/bash

# Create environment variables (i.e. 'key=val, ...')
MAKE_ENV += REGION APPLICATION GIT_BRANCH GIT_COMMIT BUILD_DATE
SHELL_EXPORT := $(foreach v,$(MAKE_ENV),$(v)='$($(v))' )

all: build get-produced-ami get-source-ami get-ohai-output upload-to-s3

build:
	${SHELL_EXPORT} envsubst < ${TEMPLATE_IN} > ${TEMPLATE_OUT}
	packer build -on-error=abort -color=false -machine-readable ${TEMPLATE_OUT} | tee logs/output.log

get-produced-ami:
	@{ \
	set -e -x ;\
	PRODUCED_IMAGE_ID=$$(jq -r '.builds[-1].artifact_id' logs/manifest.json | cut -d: -f2) ;\
	if [[ -z $${PRODUCED_IMAGE_ID} ]]; then \
		echo "ERROR: the produced image ID could not be extracted." ;\
		exit 1 ;\
	fi ;\
	aws ec2 describe-images --image-ids $${PRODUCED_IMAGE_ID} --query 'Images[0]' > produced.json ;\
	aws ec2 describe-tags --filters "Name=resource-id,Values=$${PRODUCED_IMAGE_ID} Name=resource-type,Values=image" > p-tags.json ;\
	jq -s '.[0] * .[1]' produced.json p-tags.json > logs/produced-ami.json ;\
	rm -rf produced.json p-tags.json ;\
	}

get-source-ami:
	@{ \
	set -e -x ;\
	SOURCE_IMAGE_ID=$$(grep -m 1 "Found Image ID:" logs/output.log | awk '{print $$NF}') ;\
	if [[ -z $${SOURCE_IMAGE_ID} ]]; then \
		echo "ERROR: the source image ID could not be extracted." ;\
		exit 1 ;\
	fi ;\
	aws ec2 describe-images --image-ids $${SOURCE_IMAGE_ID} --query 'Images[0]' > source.json ;\
    aws ec2 describe-tags --filters "Name=resource-id,Values=$${SOURCE_IMAGE_ID} Name=resource-type,Values=image" > s-tags.json ;\
	jq -s '.[0] * .[1]' source.json s-tags.json > logs/source-ami.json ;\
	rm -rf source.json s-tags.json ;\
	}

# Extract the Ohai output from the build log
get-ohai-output:
	@{ \
		set -e -x ;\
		cp logs/output.log ${OHAI} ;\
		sed -i '/---BEGIN_OHAI_OUTPUT---/,$$!d' ${OHAI} ;\
		sed -i '/---END_OHAI_OUTPUT---/q' ${OHAI} ;\
		sed -i 's/%!(PACKER_COMMA)/,/g' ${OHAI} ;\
		sed '1,1d' ${OHAI} | sed '$$d' | cut -d: -f2- > logs/ohai.json ;\
		rm ${OHAI} ;\
	}

upload-to-s3:
	@{ \
	set -e -x ;\
	FOLDER=$$(grep -m 1 "Prevalidating AMI Name" logs/output.log | awk '{print $$NF}' | sed 's@/@-@g') ;\
	zip -j -r build.zip logs/* ;\
	aws s3 cp build.zip s3://${S3_BUCKET}/${S3_PREFIX}/$${FOLDER}/ ;\
	}
