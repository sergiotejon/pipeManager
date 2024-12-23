.PHONY: deploy release clean shell

# Local variables
APPS := dashboard.bin launcher.bin webhook-listener.bin cleaner.bin
IMAGES := dashboard.image launcher.image webhook-listener.image cleaner.image

# Local Development Environment
K3D_REGISTRY_NAME=k3d-registry
K3D_REGISTRY_PORT=5111
K3S_CLUSTER_NAME=k3s-default
KUBECONFIG=$(PWD)/kubeconfig

# Project name
PROJECT_NAME=github.com/sergiotejon/pipeManager

# Key
SSH_PRIVATE_KEY?=$(HOME)/.ssh/id_rsa

##@ General

help: ## Display this help
	@echo ""
	@echo "Example of building applcations and images:"
	@echo ""
	@echo "To build go applications:"
	@for app in $(APPS); do \
		echo "  make $$app"; \
	done
	@echo ""
	@echo "and docker images:"
	@for image in $(IMAGES); do \
		echo "  make $$image"; \
	done
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup development environment

setup-cluster: ## Set up local development environment
	@echo "Setting up local development environment..."
	k3d registry create registry -p ${K3D_REGISTRY_PORT}
	k3d cluster create --registry-use ${K3D_REGISTRY_NAME}:${K3D_REGISTRY_PORT} -a 3
	@echo "Local development environment set up"

get-kubeconfig: ## Retrieve kubeconfig for local development environment
	@echo "Retrieving kubeconfig for local development environment"
	@k3d kubeconfig get ${K3S_CLUSTER_NAME} > ${KUBECONFIG}
	@chmod 600 ${KUBECONFIG}
	@echo "export KUBECONFIG=${KUBECONFIG}" > set-kubeconfig.sh
	@echo "Kubeconfig retrieved"
	@echo "Run 'source set-kubeconfig.sh' to set the kubeconfig environment variable for the current shell"

create-git-secret: ## Create git secret in devel k8s cluster using local ssh key
	@echo "Creating git secret..."
	ssh-keyscan -t rsa github.com > /tmp/known_hosts
	kubectl --kubeconfig ${KUBECONFIG} create secret generic git-credentials \
		--namespace pipe-manager \
		--from-file=id_rsa=${SSH_PRIVATE_KEY} \
		--from-file=known_hosts=/tmp/known_hosts

remove-cluster: ## Remove local development environment
	@echo "Removing local development environment..."
	k3d cluster delete ${K3S_CLUSTER_NAME}
	k3d registry delete ${K3D_REGISTRY_NAME}
	@echo "Local development environment removed"

shell: ## Open a shell in the devbox
	if ! command -v devbox &> /dev/null; then \
    echo "devbox is not installed. Installing devbox..."; \
		curl -fsSL https://get.jetify.com/devbox | bash; \
	fi
	SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY} devbox shell

vendor: ## Install dependencies
	@echo "Installing dependencies..."
	go mod vendor

##@ Build

all: $(APPS) $(IMAGES) ## Build all go applications and docker images

bin: $(APPS) ## Build all go applications

images: $(IMAGES) ## Build all docker images

clean: ## Clean up
	@echo "Cleaning up"
	rm -rf ${KUBECONFIG}
	rm -rf set-kubeconfig.sh
	rm -rf gke_gcloud_auth_plugin_cache
	rm -rf bin/*
	rm -rf dist
	rm -rf vendor
	for image in $(IMAGES); do \
		docker rmi -f ${K3D_REGISTRY_NAME}:${K3D_REGISTRY_PORT}/$${image%.image}:$(shell cz version -p) || true; \
	done

##@ Deploy (Fix this to use remote helm chart)

deploy: ## Deploy applications to devel k8s cluster
	@echo "Deploying applications to devel k8s cluster..."
	helm upgrade --install --wait --timeout 300s \
		--kubeconfig ${KUBECONFIG} --create-namespace --namespace pipe-manager \
		-f configs/devel/values.yaml \
		-f configs/devel/config.yaml \
		webhook-listener ./deploy/charts/webhook-listener

uninstall: ## Delete applications from devel k8s cluster
	@echo "Deleting applications from devel k8s cluster..."
	helm delete --kubeconfig ${KUBECONFIG} --namespace pipe-manager webhook-listener

port-forward: ## Port forward to devel k8s cluster
	@echo "Port forwarding to devel k8s cluster..."
	kubectl --kubeconfig ${KUBECONFIG} port-forward svc/webhook-listener 8080:80 --namespace pipe-manager

tunnel: ## Tunnel with ngrok to devel k8s cluster
	@echo "Tunneling with ngrok to devel k8s cluster..."
	ngrok http 8080

##@ Release binaries and docker images

release: ## Release applications to prod k8s cluster
	@echo "TODO: Release applications and helm charts"
	@echo goreleaser build --snapshot
	@echo goreleaser release --snapshot


#
# Internal targets
#

# Build go application
$(APPS):
	@echo "Building $(basename $@)"
	go build \
		-ldflags "-X ${PROJECT_NAME}/internal/pkg/version.Version=$(shell cz version -p)" \
		-o bin/$(basename $@) cmd/$(basename $@)/main.go

# Build docker image
$(IMAGES):
	docker build \
		-f build/$(basename $@).Dockerfile \
		--build-arg APP_VERSION=$(shell cz version -p) \
		-t ${K3D_REGISTRY_NAME}:${K3D_REGISTRY_PORT}/$(basename $@):$(shell cz version -p) .
	docker push ${K3D_REGISTRY_NAME}:${K3D_REGISTRY_PORT}/$(basename $@):$(shell cz version -p)
