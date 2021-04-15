cnf ?= config.env
include $(cnf)

DEPS_DIR = dependencies/python
DOCK_DIR = docker/apk-tools
FUNC_DIR = lambda

DOCKER_IMG_NAME = alpinist-apk

APK_FILES = apk-index apk-sign apk abuild-tar

.PHONY: docker-img pip-install deps package deploy clean help x
.DEFAULT_GOAL := help

$(DEPS_DIR)/%:
	id=$$(docker create $(DOCKER_IMG_NAME)) ;\
	docker cp $$id:/output/$(notdir $@) $(DEPS_DIR)/ ;\
	docker rm $$id

docker-img: ## Build the Docker Image with apk binaries and scripts
	docker build -t $(DOCKER_IMG_NAME) $(DOCK_DIR)/

pip-install: ## Installs Lambda Python deps in the dependencies dir
	mkdir -p $(DEPS_DIR) 2>/dev/null
	pip install \
		--no-warn-conflicts \
		--no-cache-dir \
		-r $(FUNC_DIR)/requirements.txt \
		-t $(DEPS_DIR)/

deps: pip-install docker-img $(addprefix $(DEPS_DIR)/,$(APK_FILES)) ## Installs all dependencies

package: deps ## Package Lambda function and layers, upload artifacts to S3
	aws cloudformation package \
		--s3-bucket $(S3_BUCKET_NAME_SAM) \
		--template-file template.yaml \
		--output-template-file serverless-output.yaml

deploy: ## Deploy Lambda into AWS using CloudFormation
	aws cloudformation deploy \
		--stack-name $(CF_STACK_NAME) \
		--parameter-overrides BucketName=$(S3_BUCKET_NAME_REPO) \
		--template-file serverless-output.yaml \
		--capabilities CAPABILITY_IAM

clean: ## Removes output templates, dependencies and Docker images
	rm -vf serverless-output.yaml 2>/dev/null || true
	rm -rf $(DEPS_DIR) 2>/dev/null || true
	docker rm $$(docker ps -a -q) 2>/dev/null || true
	docker rmi $(DOCKER_IMG_NAME) 2>/dev/null || true
	docker rmi $$(docker images --filter "dangling=true" -q --no-trunc) 2>/dev/null || true

help: ## Shows this help message
	$(info Available targets)
	@awk '/^[a-zA-Z\-\_0-9]+:/ {                                   \
          nb = sub( /^## /, "", helpMsg );                             \
          if(nb == 0) {                                                \
            helpMsg = $$0;                                             \
            nb = sub( /^[^:]*:.* ## /, "", helpMsg );                  \
          }                                                            \
          if (nb)                                                      \
            printf "\033[1;31m%-" width "s\033[0m %s\n", $$1, helpMsg; \
        }                                                              \
        { helpMsg = $$0 }'                                             \
        width=$$(grep -o '^[a-zA-Z_0-9]\+:' $(MAKEFILE_LIST) | wc -L)  \
        $(MAKEFILE_LIST) 2>/dev/null

