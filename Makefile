IMAGE_NAME ?= ghcr.io/shaohan-he/release-demo-service
TAG ?= local
VERSION ?= v1.0.0
GIT_SHA ?= local
GIT_BASH := D:/ai/Git/bin/bash.exe
BASH ?= $(if $(wildcard $(GIT_BASH)),$(GIT_BASH),bash)

.PHONY: test docker-build kustomize-dev kustomize-staging kustomize-production deploy-dev deploy-staging deploy-production smoke-staging rollback-production release-record

test:
	cd app && python -m pytest

docker-build:
	$(BASH) scripts/build-image.sh $(IMAGE_NAME) $(TAG) $(GIT_SHA) $(VERSION)

kustomize-dev:
	kubectl kustomize k8s/overlays/dev

kustomize-staging:
	kubectl kustomize k8s/overlays/staging

kustomize-production:
	kubectl kustomize k8s/overlays/production

deploy-dev:
	$(BASH) scripts/deploy.sh dev

deploy-staging:
	$(BASH) scripts/deploy.sh staging

deploy-production:
	$(BASH) scripts/deploy.sh production

smoke-staging:
	$(BASH) scripts/smoke-test.sh staging

rollback-production:
	$(BASH) scripts/rollback.sh production --undo

release-record:
	$(BASH) scripts/release-record.sh staging $(VERSION) $(GIT_SHA) success
