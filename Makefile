# Makefile for EKS Fargate Migration
# Goal: Move iAgent workloads to AWS Fargate for fast (~sub-2 minute) pod starts

.PHONY: deploy cleanup smoke test status help install-deps

# Variables
CLUSTER_NAME := iagent-cluster
REGION := eu-central-1
NAMESPACE := default
APP_NAME := iagent-sample

# Default target
help:
	@echo "🚀 EKS Fargate Migration - Fast & Cheap Pod Starts"
	@echo ""
	@echo "Available targets:"
	@echo "  deploy      - Deploy Fargate profiles, CoreDNS migration, and ALB controller"
	@echo "  cleanup     - Destroy Fargate infrastructure (confirm off)"
	@echo "  smoke       - Deploy sample app and test ALB connectivity"
	@echo "  test        - Run comprehensive tests"
	@echo "  status      - Show cluster and Fargate status"
	@echo "  install-deps- Install required dependencies"
	@echo ""
	@echo "💡 Quick start: make install-deps && make deploy && make smoke"

# Install dependencies
install-deps:
	@echo "📦 Installing dependencies..."
	npm install
	aws --version
	kubectl version --client
	helm version
	@echo "✅ Dependencies installed"

# Deploy Fargate infrastructure
deploy:
	@echo "🚀 Deploying EKS Fargate infrastructure..."
	@echo "📍 Cluster: $(CLUSTER_NAME) in $(REGION)"
	cd apps/infrastructure && \
	npx cdk synth --app "npx ts-node src/fargate-main.ts" && \
	npx cdk deploy IAgentFargateEksStack \
		--app "npx ts-node src/fargate-main.ts" \
		--require-approval never \
		--region $(REGION)
	@echo "⏳ Waiting for Fargate profiles to be active..."
	@./scripts/wait-for-fargate.sh $(CLUSTER_NAME) $(REGION)
	@echo "✅ Fargate deployment complete!"

# Clean up infrastructure
cleanup:
	@echo "🧹 Destroying Fargate infrastructure..."
	@echo "⚠️  This will remove Fargate profiles and ALB controller"
	cd apps/infrastructure && \
	npx cdk destroy IAgentFargateEksStack \
		--app "npx ts-node src/fargate-main.ts" \
		--force \
		--region $(REGION)
	@echo "✅ Cleanup complete"

# Deploy sample app and test ALB
smoke:
	@echo "🔥 Running smoke test..."
	@echo "📦 Deploying sample app to Fargate..."
	
	# Ensure namespace exists
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	
	# Wait for ALB controller to be ready
	@echo "⏳ Waiting for AWS Load Balancer Controller..."
	kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
	
	# Apply sample app if not already deployed by CDK
	@echo "🚀 Checking sample app deployment..."
	@if ! kubectl get deployment $(APP_NAME) -n $(NAMESPACE) >/dev/null 2>&1; then \
		echo "📦 Deploying sample app..."; \
		kubectl apply -f manifests/sample-app.yaml; \
	fi
	
	# Wait for pods to be ready
	@echo "⏳ Waiting for pods to be ready on Fargate..."
	kubectl wait --for=condition=ready pod -l app=$(APP_NAME) -n $(NAMESPACE) --timeout=300s
	
	# Wait for ALB to be provisioned
	@echo "⏳ Waiting for ALB to be provisioned..."
	@timeout 300 bash -c 'until kubectl get ingress $(APP_NAME) -n $(NAMESPACE) -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" | grep -q amazonaws.com; do echo "Waiting for ALB..."; sleep 10; done'
	
	# Get ALB DNS and test
	$(eval ALB_DNS := $(shell kubectl get ingress $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'))
	@echo "🌐 ALB DNS: $(ALB_DNS)"
	@echo "🧪 Testing ALB connectivity..."
	@timeout 60 bash -c 'until curl -s -o /dev/null -w "%{http_code}" http://$(ALB_DNS) | grep -q 200; do echo "Waiting for ALB to be healthy..."; sleep 5; done'
	@echo "✅ Smoke test passed! ALB is responding with 200 OK"
	@echo "🔗 Access your app at: http://$(ALB_DNS)"

# Run comprehensive tests
test: smoke
	@echo "🧪 Running comprehensive tests..."
	
	# Test Fargate nodes
	@echo "🔍 Checking Fargate nodes..."
	kubectl get nodes -l eks.amazonaws.com/compute-type=fargate
	
	# Test CoreDNS on Fargate
	@echo "🔍 Checking CoreDNS on Fargate..."
	kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
	
	# Test sample app pods on Fargate
	@echo "🔍 Checking sample app pods on Fargate..."
	kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o wide
	
	# Test ALB target health
	@echo "🔍 Testing ALB target health..."
	$(eval ALB_DNS := $(shell kubectl get ingress $(APP_NAME) -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'))
	@curl -s -w "Response: %{http_code}, Time: %{time_total}s\n" http://$(ALB_DNS) -o /dev/null
	
	@echo "✅ All tests passed!"

# Show cluster and Fargate status
status:
	@echo "📊 EKS Fargate Cluster Status"
	@echo "═══════════════════════════════"
	
	@echo "\n🏗️  Cluster Info:"
	aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) \
		--query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint}' \
		--output table
	
	@echo "\n🚀 Fargate Profiles:"
	aws eks list-fargate-profiles --cluster-name $(CLUSTER_NAME) --region $(REGION) \
		--output table --query 'fargateProfileNames'
	
	@echo "\n🔍 Fargate Profile Details:"
	@for profile in $$(aws eks list-fargate-profiles --cluster-name $(CLUSTER_NAME) --region $(REGION) --query 'fargateProfileNames[]' --output text); do \
		echo "\n📋 Profile: $$profile"; \
		aws eks describe-fargate-profile --cluster-name $(CLUSTER_NAME) --fargate-profile-name $$profile --region $(REGION) \
			--query 'fargateProfile.{Status:status,Namespace:selectors[0].namespace,CreatedAt:createdAt}' \
			--output table; \
	done
	
	@echo "\n🖥️  Nodes (should show fargate- nodes):"
	kubectl get nodes -o wide
	
	@echo "\n🐳 Pods on Fargate:"
	kubectl get pods -A -o wide | grep fargate || echo "No Fargate pods found yet"
	
	@echo "\n🌐 Load Balancer Controller:"
	kubectl get deployment aws-load-balancer-controller -n kube-system -o wide || echo "ALB Controller not installed"
	
	@echo "\n🔗 Sample App Status:"
	@if kubectl get ingress $(APP_NAME) -n $(NAMESPACE) >/dev/null 2>&1; then \
		echo "Ingress:"; \
		kubectl get ingress $(APP_NAME) -n $(NAMESPACE); \
		echo "\nPods:"; \
		kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME) -o wide; \
	else \
		echo "Sample app not deployed yet"; \
	fi

# Quick CLI deployment (fallback without CDK)
deploy-cli:
	@echo "🔧 CLI-based Fargate deployment (fallback method)..."
	@./scripts/deploy-fargate-cli.sh $(CLUSTER_NAME) $(REGION)

# Build the project
build:
	@echo "🔨 Building infrastructure..."
	cd apps/infrastructure && npx nx build infrastructure

# Validate the CDK templates
validate:
	@echo "✅ Validating CDK templates..."
	cd apps/infrastructure && npx cdk synth --app "npx ts-node src/fargate-main.ts" > /dev/null
	@echo "✅ Templates are valid"
