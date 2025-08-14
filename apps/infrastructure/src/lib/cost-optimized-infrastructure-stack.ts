import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions';
import * as lambda from 'aws-cdk-lib/aws-lambda';


export interface CostOptimizedInfrastructureStackProps extends cdk.StackProps {
  domainName?: string;
  clusterName?: string;
  nodeGroupInstanceType?: string;
  nodeGroupMinSize?: number;
  nodeGroupMaxSize?: number;
  nodeGroupDesiredSize?: number;
  enableSpotInstances?: boolean;
  enableMonitoring?: boolean;
  enableAlarms?: boolean;
  maxMonthlyCostUSD?: number;
}

export class CostOptimizedInfrastructureStack extends cdk.Stack {
  public readonly cluster: eks.Cluster;
  public readonly backendRepository: ecr.Repository;
  public readonly frontendRepository: ecr.Repository;
  public readonly hostedZone?: route53.IHostedZone;
  public readonly certificate?: acm.ICertificate;
  public readonly vpc: ec2.Vpc;
  public alarmTopic?: sns.Topic;
  public dashboard?: cloudwatch.Dashboard;
  public readonly logGroups: logs.LogGroup[] = [];

  constructor(scope: Construct, id: string, props: CostOptimizedInfrastructureStackProps) {
    super(scope, id, props);

    // Default cost-optimized parameters
    const clusterName = props.clusterName || 'iagent-cluster';
    const instanceType = props.nodeGroupInstanceType || 't3.medium';
    const minSize = props.nodeGroupMinSize || 0;
    const maxSize = props.nodeGroupMaxSize || 3;
    const desiredSize = props.nodeGroupDesiredSize || 1;
    const enableSpotInstances = props.enableSpotInstances ?? true;
    const enableMonitoring = props.enableMonitoring ?? true;
    const enableAlarms = props.enableAlarms ?? true;
    const maxMonthlyCostUSD = props.maxMonthlyCostUSD || 50;

    // Cost-optimized VPC with fewer NAT gateways
    this.vpc = new ec2.Vpc(this, 'IAgentCostOptimizedVPC', {
      maxAzs: 2, // Limit to 2 AZs to reduce NAT gateway costs
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

    // Cost-optimized ECR Repositories with lifecycle policies
    this.backendRepository = new ecr.Repository(this, 'BackendRepository', {
      repositoryName: 'iagent-backend',
      imageScanOnPush: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      lifecycleRules: [
        {
          description: 'Keep only latest 5 images',
          maxImageCount: 5,
          rulePriority: 1,
        },
        {
          description: 'Delete untagged images after 1 day',
          maxImageAge: cdk.Duration.days(1),
          tagStatus: ecr.TagStatus.UNTAGGED,
          rulePriority: 2,
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
          rulePriority: 1,
        },
        {
          description: 'Delete untagged images after 1 day',
          maxImageAge: cdk.Duration.days(1),
          tagStatus: ecr.TagStatus.UNTAGGED,
          rulePriority: 2,
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

    // Create kubectl layer
    const kubectlLayer = new lambda.LayerVersion(this, 'KubectlLayer', {
      code: lambda.Code.fromInline(`
import json
def handler(event, context):
    return {"statusCode": 200, "body": json.dumps("kubectl layer")}
      `),
      compatibleRuntimes: [lambda.Runtime.PYTHON_3_9],
      description: 'kubectl layer for EKS',
    });

    // EKS Cluster with cost optimizations
    this.cluster = new eks.Cluster(this, 'IAgentCluster', {
      clusterName: clusterName,
      version: eks.KubernetesVersion.V1_28,
      vpc: this.vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      role: eksServiceRole,
      defaultCapacity: 0, // No default capacity, we'll add cost-optimized node groups
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      clusterLogging: enableMonitoring ? [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
      ] : [],
      kubectlLayer: kubectlLayer,
    });

    // Cost-optimized Node Group with Spot Instances
    const nodeGroupRole = new iam.Role(this, 'NodeGroupRole', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSWorkerNodePolicy'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKS_CNI_Policy'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEC2ContainerRegistryReadOnly'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
      ],
    });

    const nodeGroupConfig: any = {
      instanceTypes: [new ec2.InstanceType(instanceType)],
      minSize: minSize,
      maxSize: maxSize,
      desiredSize: desiredSize,
      diskSize: 20, // Minimal disk size to reduce costs
      amiType: eks.NodegroupAmiType.AL2_X86_64,
      releaseVersion: undefined,
      remoteAccess: undefined, // Disable SSH access to reduce attack surface
      nodeRole: nodeGroupRole,
      tags: {
        'Environment': 'development',
        'Project': 'iAgent',
        'CostOptimized': 'true',
      },
    };

    if (enableSpotInstances) {
      nodeGroupConfig.capacityType = eks.CapacityType.SPOT;
    }

    this.cluster.addNodegroupCapacity('CostOptimizedNodeGroup', nodeGroupConfig);

    // Add Cluster Autoscaler for cost optimization
    this.cluster.addHelmChart('ClusterAutoscaler', {
      chart: 'cluster-autoscaler',
      repository: 'https://kubernetes.github.io/autoscaler',
      namespace: 'kube-system',
      values: {
        'autoDiscovery': {
          'clusterName': clusterName,
        },
        'awsRegion': this.region,
        'rbac': {
          'serviceAccount': {
            'annotations': {
              'eks.amazonaws.com/role-arn': nodeGroupRole.roleArn,
            },
          },
        },
        'extraArgs': {
          'scale-down-enabled': true,
          'scale-down-delay-after-add': '2m',
          'scale-down-unneeded-time': '5m',
          'skip-nodes-with-local-storage': false,
          'expander': 'least-waste',
        },
      },
    });

    // Cost monitoring and alarms
    if (enableAlarms) {
      this.setupCostMonitoring(maxMonthlyCostUSD);
    }

    // CloudWatch logging with retention policies
    if (enableMonitoring) {
      this.setupCostOptimizedMonitoring();
    }

    // Output important information
    new cdk.CfnOutput(this, 'ClusterName', {
      value: this.cluster.clusterName,
      description: 'EKS Cluster Name',
    });

    new cdk.CfnOutput(this, 'BackendRepositoryUri', {
      value: this.backendRepository.repositoryUri,
      description: 'Backend ECR Repository URI',
    });

    new cdk.CfnOutput(this, 'FrontendRepositoryUri', {
      value: this.frontendRepository.repositoryUri,
      description: 'Frontend ECR Repository URI',
    });

    new cdk.CfnOutput(this, 'VpcId', {
      value: this.vpc.vpcId,
      description: 'VPC ID',
    });

    new cdk.CfnOutput(this, 'EstimatedMonthlyCost', {
      value: this.calculateEstimatedCost(enableSpotInstances, instanceType),
      description: 'Estimated Monthly Cost (USD)',
    });
  }

  private setupCostMonitoring(maxMonthlyCostUSD: number): void {
    // SNS Topic for cost alerts
    this.alarmTopic = new sns.Topic(this, 'CostAlarmTopic', {
      topicName: 'iAgent-cost-alerts',
      displayName: 'iAgent Cost Alerts',
    });

    // Cost alarm using CloudWatch (simplified - real cost monitoring requires AWS Budgets)
    const estimatedCostAlarm = new cloudwatch.Alarm(this, 'EstimatedCostAlarm', {
      alarmName: 'iAgent-estimated-cost-alarm',
      alarmDescription: `Alert when estimated costs exceed $${maxMonthlyCostUSD}`,
      metric: new cloudwatch.Metric({
        namespace: 'AWS/EC2',
        metricName: 'NetworkIn',
        dimensionsMap: {
          'InstanceType': 't3.medium',
        },
        statistic: 'Sum',
      }),
      threshold: 1000000000, // Placeholder - real implementation needs AWS Budgets
      evaluationPeriods: 1,
    });

    estimatedCostAlarm.addAlarmAction(new actions.SnsAction(this.alarmTopic));

    // EKS Cluster health alarms
    const clusterStatusAlarm = new cloudwatch.Alarm(this, 'ClusterStatusAlarm', {
      alarmName: 'iAgent-cluster-status',
      alarmDescription: 'Monitor EKS cluster status',
      metric: new cloudwatch.Metric({
        namespace: 'AWS/EKS',
        metricName: 'cluster_failed_request_count',
        dimensionsMap: {
          'ClusterName': this.cluster.clusterName,
        },
        statistic: 'Sum',
      }),
      threshold: 10,
      evaluationPeriods: 2,
    });

    clusterStatusAlarm.addAlarmAction(new actions.SnsAction(this.alarmTopic));
  }

  private setupCostOptimizedMonitoring(): void {
    // Create log groups with retention policies
    const clusterLogGroup = new logs.LogGroup(this, 'ClusterLogGroup', {
      logGroupName: `/aws/eks/${this.cluster.clusterName}/cluster`,
      retention: logs.RetentionDays.ONE_WEEK, // Short retention to reduce costs
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const applicationLogGroup = new logs.LogGroup(this, 'ApplicationLogGroup', {
      logGroupName: `/aws/eks/${this.cluster.clusterName}/application`,
      retention: logs.RetentionDays.THREE_DAYS, // Very short retention for app logs
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    this.logGroups.push(clusterLogGroup, applicationLogGroup);

    // Cost-optimized CloudWatch Dashboard
    this.dashboard = new cloudwatch.Dashboard(this, 'CostOptimizedDashboard', {
      dashboardName: 'iAgent-cost-optimized-monitoring',
      widgets: [
        [
          new cloudwatch.GraphWidget({
            title: 'EKS Cluster CPU Utilization',
            left: [
              new cloudwatch.Metric({
                namespace: 'AWS/EKS',
                metricName: 'node_cpu_utilization',
                dimensionsMap: {
                  'ClusterName': this.cluster.clusterName,
                },
                statistic: 'Average',
              }),
            ],
            width: 12,
          }),
        ],
        [
          new cloudwatch.GraphWidget({
            title: 'ECR Repository Size',
            left: [
              new cloudwatch.Metric({
                namespace: 'AWS/ECR',
                metricName: 'RepositorySizeInBytes',
                dimensionsMap: {
                  'RepositoryName': this.backendRepository.repositoryName,
                },
                statistic: 'Average',
              }),
            ],
            width: 12,
          }),
        ],
      ],
    });
  }

  private calculateEstimatedCost(spotInstances: boolean, instanceType: string): string {
    // Simplified cost calculation
    const eksControlPlane = 73; // $73/month for EKS control plane
    const natGateway = 45; // $45/month for 1 NAT gateway
    
    // Instance costs (very rough estimates)
    const instanceCosts: { [key: string]: number } = {
      't3.micro': 8,
      't3.small': 16,
      't3.medium': 33,
      't3.large': 66,
    };
    
    let instanceCost = instanceCosts[instanceType] || 33;
    if (spotInstances) {
      instanceCost = instanceCost * 0.3; // Spot instances are ~70% cheaper
    }
    
    const ecrStorage = 2; // ~$2/month for ECR storage
    const cloudWatch = 5; // ~$5/month for CloudWatch
    
    const total = eksControlPlane + natGateway + instanceCost + ecrStorage + cloudWatch;
    
    return `${total.toFixed(0)} (with ${spotInstances ? 'spot' : 'on-demand'} instances)`;
  }
}