STACK_NAME ?= cp-prod-apk
APK_BUCKET ?= apk.cloudposse.com
LAMBDA_BUCKET ?= $(STACK_NAME)

BUCKET ?= apk.cloudposse.com

cf/bucket:
	aws s3 mb s3://$(LAMBDA_BUCKET)

cf/package:
	aws cloudformation package \
	  --template-file template.yaml \
	  --output-template-file serverless-output.yaml \
	  --s3-bucket $(LAMBDA_BUCKET)

cf/deploy:
	aws cloudformation deploy \
	  --parameter-overrides BucketName=$(APK_BUCKET) FunctionName=$(STACK_NAME) \
	  --template-file serverless-output.yaml \
	  --stack-name $(STACK_NAME) \
	  --capabilities CAPABILITY_IAM

cf/destroy:
	-aws s3 rb s3://$(APK_BUCKET) --force
	-aws s3 rb s3://$(LAMBDA_BUCKET) --force
	aws cloudformation delete-stack --stack-name $(STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME)

aws/ssm:
	aws ssm put-parameter --region $(AWS_REGION) --name '/apk/rsa' --type 'SecureString' --value "`cat ops@cloudposse.com.rsa`"
	aws ssm put-parameter --region $(AWS_REGION) --name '/apk/key' --type 'String' --value 'ops@cloudposse.com.rsa.pub'

sync:
	aws s3 cp contrib/install.sh s3://$(APK_BUCKET)/install.sh
	aws s3 cp ops@cloudposse.com.rsa.pub s3://$(APK_BUCKET)/  
#	aws s3 sync ../packages/tmp/vendor/ s3://$(APK_BUCKET)/3.8/vendor/
