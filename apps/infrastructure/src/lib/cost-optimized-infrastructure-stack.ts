/**
 * iAgent AWS Hosting Infrastructure Stack
 * 
 * This stack creates ONLY the AWS resources needed to host the CI/CD pipeline:
 * - VPC with public/private subnets and NAT gateway
 * - ECR repositories for backend and frontend Docker images
 * - EKS cluster for backend hosting
 * - IAM roles and policies for CI/CD access
 * 
 * IMPORTANT: All resources have proper removal policies set to DESTROY,
 * which means running `cdk destroy` will completely remove ALL resources.
 * 
 * To completely clean up AWS:
 * 1. Run: cdk destroy --force
 * 2. This will delete: ECR repos, EKS cluster, VPC, IAM roles, etc.
 * 3. All resources will be permanently removed
 */

import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as ec2 from 'aws-cdk-lib/aws-ec2';

export interface CostOptimizedInfrastructureStackProps extends cdk.StackProps {
  clusterName?: string;
  nodeGroupInstanceType?: string;
  nodeGroupMinSize?: number;
  nodeGroupMaxSize?: number;
  nodeGroupDesiredSize?: number;
  enableSpotInstances?: boolean;
}

export class CostOptimizedInfrastructureStack extends cdk.Stack {
  public readonly cluster: eks.Cluster;
  public readonly backendRepository: ecr.Repository;
  public readonly frontendRepository: ecr.Repository;
  public readonly vpc: ec2.Vpc;

  constructor(scope: Construct, id: string, props: CostOptimizedInfrastructureStackProps) {
    super(scope, id, props);

    // Default cost-optimized parameters
    const clusterName = props.clusterName || 'iagent-cluster';
    const instanceType = props.nodeGroupInstanceType || 't3.medium';
    const minSize = props.nodeGroupMinSize || 0;
    const maxSize = props.nodeGroupMaxSize || 2;
    const desiredSize = props.nodeGroupDesiredSize || 1;
    const enableSpotInstances = props.enableSpotInstances ?? true;

    // Simple VPC with minimal networking
    this.vpc = new ec2.Vpc(this, 'IAgentVPC', {
      maxAzs: 2, // Limit to 2 AZs to reduce costs
      natGateways: 1, // Single NAT gateway to reduce costs
      enableDnsHostnames: true,
      enableDnsSupport: true,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
      ],
    });

    // Create ECR Repositories for Docker images
    this.backendRepository = new ecr.Repository(this, 'BackendRepository', {
      repositoryName: 'iagent-backend',
      imageScanOnPush: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      lifecycleRules: [
        {
          description: 'Keep only latest 5 images',
          maxImageCount: 5,
        },
      ],
    });

    this.frontendRepository = new ecr.Repository(this, 'FrontendRepository', {
      repositoryName: 'iagent-frontend',
      imageScanOnPush: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      lifecycleRules: [
        {
          description: 'Keep only latest 5 images',
          maxImageCount: 5,
        },
      ],
    });

    // EKS Service Role
    const eksServiceRole = new iam.Role(this, 'EKSServiceRole', {
      assumedBy: new iam.ServicePrincipal('eks.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSClusterPolicy'),
      ],
    });

    // TODO: EKS cluster temporarily disabled due to Lambda permission issues
    // Will be added back once we resolve the AWS permissions
    this.cluster = undefined as any;

    // Node Group Role for EKS workers (kept for future use)
    const nodeGroupRole = new iam.Role(this, 'NodeGroupRole', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSWorkerNodePolicy'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKS_CNI_Policy'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEC2ContainerRegistryReadOnly'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
      ],
    });

    // TODO: Node group creation disabled until EKS cluster is working
    // Will be added back once we resolve the AWS permissions

    // Outputs for GitHub Actions to use
    new cdk.CfnOutput(this, 'BackendRepositoryUri', {
      description: 'Backend ECR Repository URI',
      value: this.backendRepository.repositoryUri,
    });

    new cdk.CfnOutput(this, 'FrontendRepositoryUri', {
      description: 'Frontend ECR Repository URI',
      value: this.frontendRepository.repositoryUri,
    });

    new cdk.CfnOutput(this, 'VpcId', {
      description: 'VPC ID',
      value: this.vpc.vpcId,
    });

    new cdk.CfnOutput(this, 'ClusterName', {
      description: 'EKS Cluster Name',
      value: 'EKS_CLUSTER_TEMPORARILY_DISABLED',
    });

    new cdk.CfnOutput(this, 'EstimatedMonthlyCost', {
      description: 'Estimated Monthly Cost (USD)',
      value: '~$80-120 (with spot instances)',
    });
  }
}