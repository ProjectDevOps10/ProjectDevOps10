# 🚀 EKS Fargate Migration for iAgent

**Goal**: Move iAgent workloads to AWS Fargate for EKS to achieve **sub-2 minute pod starts** while keeping costs low and infrastructure simple.

## 🎯 What This Delivers

### ✅ **Fast Pod Starts**
- **Target**: Sub-2 minute pod startup times
- **Reality**: 30-120 seconds typical startup (no EC2 boot time)
- **Mechanism**: Pre-warmed Fargate infrastructure

### 💰 **Cost Optimization**
- **Billing**: Pay only for resources you request (CPU/memory)
- **No Waste**: No idle EC2 nodes consuming resources
- **Right-sizing**: Precise resource allocation per pod

### 🏗️ **Infrastructure Simplicity**
- **Serverless**: No EC2 nodes to manage, patch, or scale
- **Managed**: AWS handles the underlying infrastructure
- **Secure**: Isolated compute environments per pod

## 📋 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS EKS Cluster                         │
│                   (iagent-cluster)                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Namespace  │  │   Namespace  │  │   Namespace  │      │
│  │   default    │  │     prod     │  │   staging    │      │
│  │              │  │              │  │              │      │
│  │ Fargate      │  │ Fargate      │  │ Fargate      │      │
│  │ Profile      │  │ Profile      │  │ Profile      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┤
│  │              AWS Load Balancer Controller               │
│  │                   (with IRSA)                          │
│  └─────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────────┤
│  │                   CoreDNS                              │
│  │              (running on Fargate)                      │
│  └─────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                ┌─────────────────────────────────┐
                │     Application Load Balancer   │
                │        (ALB with IP targets)    │
                └─────────────────────────────────┘
                                │
                                ▼
                        🌐 Internet Traffic
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl configured for your EKS cluster
- Node.js and npm for CDK
- Docker for container builds

### 1. Deploy Fargate Infrastructure
```bash
# Install dependencies
make install-deps

# Deploy Fargate profiles and ALB controller
make deploy
```

### 2. Test with Sample Application
```bash
# Deploy sample app and verify ALB connectivity
make smoke
```

### 3. Check Status
```bash
# View cluster and Fargate status
make status
```

## 📚 Detailed Implementation

### 🏗️ **CDK Infrastructure Stack**

The Fargate migration is implemented in TypeScript CDK v2:

- **File**: `apps/infrastructure/src/lib/fargate-eks-stack.ts`
- **Entry**: `apps/infrastructure/src/fargate-main.ts`
- **Config**: `apps/infrastructure/cdk-fargate.json`

#### Key Components:

1. **Pod Execution Role**
   - Service Principal: `pods.eks.amazonaws.com`
   - Policy: `AmazonEKSFargatePodExecutionRolePolicy`

2. **Fargate Profiles**
   - Namespaces: `default`, `prod`, `staging`
   - Subnets: Private subnets from existing VPC
   - Selectors: By namespace

3. **CoreDNS Migration**
   - EKS Add-on with `computeType: "Fargate"`
   - Conflict resolution: `OVERWRITE`

4. **AWS Load Balancer Controller**
   - IRSA (IAM Roles for Service Accounts)
   - Helm chart deployment
   - ALB support with IP target type

### 🔧 **Makefile Targets**

| Target | Description |
|--------|-------------|
| `make deploy` | Deploy Fargate infrastructure via CDK |
| `make cleanup` | Destroy Fargate infrastructure |
| `make smoke` | Deploy sample app and test ALB |
| `make test` | Run comprehensive tests |
| `make status` | Show cluster and Fargate status |
| `make deploy-cli` | CLI-based deployment (fallback) |

### 📦 **Sample Application**

**File**: `manifests/sample-app.yaml`

The sample app demonstrates:
- ✅ **Fargate scheduling**: Pods run on `fargate-*` nodes
- ✅ **ALB integration**: Internet-facing load balancer
- ✅ **Health checks**: Readiness and liveness probes
- ✅ **Resource optimization**: Right-sized requests/limits

#### Key Annotations for ALB:
```yaml
annotations:
  kubernetes.io/ingress.class: alb
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip  # Required for Fargate!
```

## ⚡ Why Fargate is Fast

### 🔥 **Pre-warmed Infrastructure**
- AWS maintains a pool of pre-configured compute capacity
- No EC2 boot time (30-60 seconds saved)
- Container runtime is optimized for fast starts

### 🎯 **Optimized Scheduling**
- Direct pod-to-Fargate mapping
- No node-level resource contention
- Faster container image pulls

### 💡 **Best Practices for Speed**
1. **Small images**: Use Alpine or distroless base images
2. **Right-sizing**: Set appropriate resource requests
3. **Health checks**: Optimize probe timing
4. **Init containers**: Minimize startup dependencies

## 💰 Cost Optimization Guide

### 🎯 **Resource Right-sizing**

Fargate charges based on requested resources. Optimize your requests:

```yaml
resources:
  requests:
    memory: "64Mi"    # Start small
    cpu: "50m"        # 0.05 vCPU
  limits:
    memory: "128Mi"   # Allow burst
    cpu: "100m"       # 0.1 vCPU
```

### 📊 **Cost Knobs**

| Configuration | Impact | Recommendation |
|---------------|--------|----------------|
| **CPU requests** | Linear cost scaling | Start with 0.25 vCPU (250m) |
| **Memory requests** | Linear cost scaling | Start with 512Mi |
| **Replica count** | Multiplies cost | Use HPA for auto-scaling |
| **Namespace distribution** | Resource isolation | Separate dev/prod for cost tracking |

### 💡 **Cost Monitoring**

```bash
# Check resource utilization
kubectl top pods -n default

# Monitor costs by namespace
kubectl get pods -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory"
```

## 🚨 Fargate Limitations & Workarounds

### ❌ **What Won't Work on Fargate**

1. **DaemonSets** - Not supported
2. **Privileged containers** - Security restriction
3. **hostNetwork/hostPort** - Isolation requirement
4. **GPUs** - Not available
5. **Windows containers** - Linux only
6. **Persistent volumes** - EFS only

### ✅ **Workarounds**

| Limitation | Workaround |
|------------|------------|
| **DaemonSets** | Add a small EC2 managed node group for specific workloads |
| **Storage** | Use EFS with EFS CSI driver |
| **Networking** | Use ALB/NLB with IP target type |
| **Monitoring** | Use managed services (CloudWatch, X-Ray) |

### 🔧 **Hybrid Approach**

If you need capabilities not supported by Fargate:

```bash
# Add a small spot node group for special workloads
aws eks create-nodegroup \
  --cluster-name iagent-cluster \
  --nodegroup-name spot-workers \
  --node-role arn:aws:iam::ACCOUNT:role/NodeInstanceRole \
  --capacity-type SPOT \
  --instance-types t3.small \
  --scaling-config minSize=0,maxSize=3,desiredSize=1
```

## 🔍 Adding More Namespaces

To add new namespaces to Fargate profiles:

### Via CDK (Recommended):
```typescript
// Add to namespaces array in fargate-eks-stack.ts
const namespaces = ['default', 'prod', 'staging', 'new-namespace'];
```

### Via CLI:
```bash
aws eks create-fargate-profile \
  --cluster-name iagent-cluster \
  --fargate-profile-name fp-new-namespace \
  --pod-execution-role-arn arn:aws:iam::ACCOUNT:role/EKSFargatePodExecutionRole \
  --subnets subnet-xxx subnet-yyy \
  --selectors namespace=new-namespace \
  --region eu-central-1
```

## 🧪 Testing & Validation

### ✅ **Acceptance Criteria**

1. **Fargate Nodes**:
   ```bash
   kubectl get nodes -l eks.amazonaws.com/compute-type=fargate
   ```

2. **CoreDNS on Fargate**:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
   ```

3. **ALB Health**:
   ```bash
   curl -s -w "Status: %{http_code}, Time: %{time_total}s\n" http://ALB_DNS
   ```

### 🔍 **Troubleshooting**

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Pods pending** | `kubectl get pods` shows pending | Check Fargate profile selectors |
| **ALB not created** | No external IP on ingress | Verify ALB controller and annotations |
| **Slow starts** | >2 min pod start | Check image size and resource requests |
| **CoreDNS issues** | DNS resolution fails | Verify CoreDNS addon migration |

### 📊 **Monitoring Commands**

```bash
# Monitor pod startup times
kubectl get events --sort-by='.lastTimestamp' | grep fargate

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names k8s-default-iagentsa-xxx --query 'TargetGroups[0].TargetGroupArn' --output text)

# View resource utilization
kubectl top pods --containers -n default
```

## 🚀 Migration Strategy

### 1. **Pre-migration Checklist**
- [ ] Inventory existing workloads
- [ ] Identify Fargate incompatible workloads
- [ ] Plan namespace strategy
- [ ] Test with sample applications

### 2. **Migration Steps**
1. Deploy Fargate profiles (this project)
2. Migrate CoreDNS to Fargate
3. Install ALB controller
4. Move applications namespace by namespace
5. Validate and monitor

### 3. **Rollback Plan**
```bash
# If needed, revert to EC2 nodes
make cleanup
# Scale up existing node group
aws eks update-nodegroup-config --cluster-name iagent-cluster --nodegroup-name existing-nodes --scaling-config desiredSize=2
```

## 📞 Support & Resources

### 🔗 **Official Documentation**
- [EKS Fargate User Guide](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Fargate Pod Configuration](https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html)

### 🛠️ **Useful Commands**
```bash
# Quick status check
make status

# Deploy everything
make deploy && make smoke

# Check costs (estimate)
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE

# Debug pod issues
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
```

---

## 🎉 Success Metrics

After successful deployment, you should see:

- ✅ **Pod start times**: 30-120 seconds
- ✅ **Cost reduction**: 20-40% compared to always-on EC2
- ✅ **Zero infrastructure management**: No nodes to patch/manage
- ✅ **Improved reliability**: Isolated compute per pod
- ✅ **Better security**: Pod-level isolation

**Next**: Monitor your applications, optimize resource requests, and enjoy serverless Kubernetes! 🚀
