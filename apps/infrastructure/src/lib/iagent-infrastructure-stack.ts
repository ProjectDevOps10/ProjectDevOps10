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

export interface IAgentInfrastructureStackProps extends cdk.StackProps {
  domainName?: string;
  clusterName?: string;
  nodeGroupInstanceType?: string;
  nodeGroupMinSize?: number;
  nodeGroupMaxSize?: number;
  nodeGroupDesiredSize?: number;
  enableMonitoring?: boolean;
  enableAlarms?: boolean;
}

export class IAgentInfrastructureStack extends cdk.Stack {
  public readonly cluster: eks.Cluster;
  public readonly backendRepository: ecr.Repository;
  public readonly frontendRepository: ecr.Repository;
  public readonly hostedZone?: route53.IHostedZone;
  public readonly certificate?: acm.ICertificate;
  public readonly vpc: ec2.Vpc;
  public alarmTopic?: sns.Topic;
  public dashboard?: cloudwatch.Dashboard;
  public readonly logGroups: logs.LogGroup[] = [];

  constructor(scope: Construct, id: string, props: IAgentInfrastructureStackProps) {
    super(scope, id, props);

    // VPC for EKS cluster
    this.vpc = new ec2.Vpc(this, 'IAgentVPC', {
      maxAzs: 2,
      natGateways: 1,
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

    // ECR Repositories
    this.backendRepository = new ecr.Repository(this, 'BackendRepository', {
      repositoryName: 'iagent-backend',
      imageScanOnPush: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      lifecycleRules: [
        {
          maxImageCount: 10,
          rulePriority: 1,
        },
      ],
    });

    this.frontendRepository = new ecr.Repository(this, 'FrontendRepository', {
      repositoryName: 'iagent-frontend',
      imageScanOnPush: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      lifecycleRules: [
        {
          maxImageCount: 10,
          rulePriority: 1,
        },
      ],
    });

    // EKS Cluster
    this.cluster = new eks.Cluster(this, 'IAgentCluster', {
      version: eks.KubernetesVersion.V1_28,
      clusterName: props.clusterName || 'iagent-cluster',
      vpc: this.vpc,
      vpcSubnets: [{ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }],
      defaultCapacity: 0, // We'll add node groups manually
      endpointAccess: eks.EndpointAccess.PUBLIC_AND_PRIVATE,
      kubectlLayer: lambda.LayerVersion.fromLayerVersionArn(this, 'KubectlLayer', 
        `arn:aws:lambda:${this.region}:770693421928:layer:KubectlLayer:1`
      ),
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR,
        eks.ClusterLoggingTypes.CONTROLLER_MANAGER,
        eks.ClusterLoggingTypes.SCHEDULER,
      ],
    });

    // Node Group for the cluster
    this.cluster.addNodegroupCapacity('IAgentNodeGroup', {
      instanceTypes: [ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MEDIUM)],
      minSize: props.nodeGroupMinSize || 1,
      maxSize: props.nodeGroupMaxSize || 3,
      desiredSize: props.nodeGroupDesiredSize || 2,
      subnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
      labels: {
        role: 'general',
      },
      tags: {
        'k8s.io/cluster-autoscaler/node-template/label/role': 'general',
      },
    });

    // Add Cluster Autoscaler
    this.addClusterAutoscaler();

    // Add AWS Load Balancer Controller
    this.addLoadBalancerController();

    // Add External DNS for automatic DNS management
    this.addExternalDNS();

    // Add Metrics Server
    this.addMetricsServer();

    // Add NGINX Ingress Controller
    this.addNginxIngressController();

    // Route53 Hosted Zone (if domain provided)
    if (props.domainName) {
      this.hostedZone = new route53.HostedZone(this, 'IAgentHostedZone', {
        zoneName: props.domainName,
      });

      // SSL Certificate
      this.certificate = new acm.Certificate(this, 'IAgentCertificate', {
        domainName: props.domainName,
        subjectAlternativeNames: [`*.${props.domainName}`],
        validation: acm.CertificateValidation.fromDns(this.hostedZone),
      });

      // Output the nameservers
      new cdk.CfnOutput(this, 'Nameservers', {
        value: this.hostedZone.hostedZoneNameServers?.join(', ') || '',
        description: 'Nameservers for the hosted zone',
      });
    }

    // Monitoring and Observability (if enabled)
    if (props.enableMonitoring !== false) {
      this.setupMonitoring(props.enableAlarms !== false);
    }

    // Outputs
    new cdk.CfnOutput(this, 'ClusterName', {
      value: this.cluster.clusterName,
      description: 'EKS Cluster Name',
    });

    new cdk.CfnOutput(this, 'ClusterEndpoint', {
      value: this.cluster.clusterEndpoint,
      description: 'EKS Cluster Endpoint',
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

    // Add stack destruction protection
    this.addStackProtection();
  }

  private setupMonitoring(enableAlarms: boolean): void {
    // SNS Topic for alarms
    this.alarmTopic = new sns.Topic(this, 'IAgentAlarmTopic', {
      topicName: 'iagent-alarms',
      displayName: 'iAgent Application Alarms',
    });

    // CloudWatch Dashboard
    this.dashboard = new cloudwatch.Dashboard(this, 'IAgentDashboard', {
      dashboardName: 'iAgent-Application-Dashboard',
    });

    // Log Groups
    this.createLogGroups();

    // Add EKS metrics to dashboard
    this.addEksMetrics();

    // Add application metrics to dashboard
    this.addApplicationMetrics();

    // Add alarms if enabled
    if (enableAlarms) {
      this.addAlarms();
    }

    // Outputs for monitoring
    new cdk.CfnOutput(this, 'DashboardUrl', {
      value: `https://${this.region}.console.aws.amazon.com/cloudwatch/home?region=${this.region}#dashboards:name=${this.dashboard.dashboardName}`,
      description: 'CloudWatch Dashboard URL',
    });

    new cdk.CfnOutput(this, 'AlarmTopicArn', {
      value: this.alarmTopic.topicArn,
      description: 'SNS Topic ARN for Alarms',
    });
  }

  private createLogGroups(): void {
    // Application Log Group
    const appLogGroup = new logs.LogGroup(this, 'IAgentAppLogs', {
      logGroupName: '/aws/eks/iagent/application',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Access Log Group
    const accessLogGroup = new logs.LogGroup(this, 'IAgentAccessLogs', {
      logGroupName: '/aws/eks/iagent/access',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Error Log Group
    const errorLogGroup = new logs.LogGroup(this, 'IAgentErrorLogs', {
      logGroupName: '/aws/eks/iagent/errors',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    this.logGroups.push(appLogGroup, accessLogGroup, errorLogGroup);

    // Add log widgets to dashboard
    if (this.dashboard) {
      this.dashboard.addWidgets(
        new cloudwatch.LogQueryWidget({
          title: 'Application Logs',
          logGroupNames: [appLogGroup.logGroupName],
          queryLines: [
            'fields @timestamp, @message',
            'filter @message like /ERROR/',
            'sort @timestamp desc',
            'limit 20',
          ],
          width: 24,
          height: 6,
        })
      );
    }
  }

  private addEksMetrics(): void {
    if (!this.dashboard) return;

    // CPU Utilization
    const cpuMetric = new cloudwatch.Metric({
      namespace: 'AWS/EKS',
      metricName: 'CPUUtilization',
      dimensionsMap: {
        ClusterName: this.cluster.clusterName,
      },
      statistic: 'Average',
      period: cdk.Duration.minutes(5),
    });

    // Memory Utilization
    const memoryMetric = new cloudwatch.Metric({
      namespace: 'AWS/EKS',
      metricName: 'MemoryUtilization',
      dimensionsMap: {
        ClusterName: this.cluster.clusterName,
      },
      statistic: 'Average',
      period: cdk.Duration.minutes(5),
    });

    // Add metrics to dashboard
    this.dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'EKS Cluster CPU Utilization',
        left: [cpuMetric],
        width: 12,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'EKS Cluster Memory Utilization',
        left: [memoryMetric],
        width: 12,
        height: 6,
      })
    );
  }

  private addApplicationMetrics(): void {
    if (!this.dashboard) return;

    // Custom application metrics
    const requestCount = new cloudwatch.Metric({
      namespace: 'iAgent/Application',
      metricName: 'RequestCount',
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
    });

    const responseTime = new cloudwatch.Metric({
      namespace: 'iAgent/Application',
      metricName: 'ResponseTime',
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
    });

    const errorRate = new cloudwatch.Metric({
      namespace: 'iAgent/Application',
      metricName: 'ErrorRate',
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
    });

    // Add application metrics to dashboard
    this.dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'Application Request Count',
        left: [requestCount],
        width: 8,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'Application Response Time',
        left: [responseTime],
        width: 8,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'Application Error Rate',
        left: [errorRate],
        width: 8,
        height: 6,
      })
    );
  }

  private addAlarms(): void {
    if (!this.alarmTopic) return;

    // High CPU Alarm
    const highCpuAlarm = new cloudwatch.Alarm(this, 'HighCpuAlarm', {
      metric: new cloudwatch.Metric({
        namespace: 'AWS/EKS',
        metricName: 'CPUUtilization',
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
      }),
      threshold: 80,
      evaluationPeriods: 2,
      alarmDescription: 'EKS cluster CPU utilization is high',
    });

    // High Memory Alarm
    const highMemoryAlarm = new cloudwatch.Alarm(this, 'HighMemoryAlarm', {
      metric: new cloudwatch.Metric({
        namespace: 'AWS/EKS',
        metricName: 'MemoryUtilization',
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
      }),
      threshold: 85,
      evaluationPeriods: 2,
      alarmDescription: 'EKS cluster memory utilization is high',
    });

    // High Error Rate Alarm
    const highErrorRateAlarm = new cloudwatch.Alarm(this, 'HighErrorRateAlarm', {
      metric: new cloudwatch.Metric({
        namespace: 'iAgent/Application',
        metricName: 'ErrorRate',
        statistic: 'Average',
        period: cdk.Duration.minutes(5),
      }),
      threshold: 5,
      evaluationPeriods: 2,
      alarmDescription: 'Application error rate is high',
    });

    // Add alarm actions
    highCpuAlarm.addAlarmAction(new actions.SnsAction(this.alarmTopic));
    highMemoryAlarm.addAlarmAction(new actions.SnsAction(this.alarmTopic));
    highErrorRateAlarm.addAlarmAction(new actions.SnsAction(this.alarmTopic));

    // Add OK actions
    highCpuAlarm.addOkAction(new actions.SnsAction(this.alarmTopic));
    highMemoryAlarm.addOkAction(new actions.SnsAction(this.alarmTopic));
    highErrorRateAlarm.addOkAction(new actions.SnsAction(this.alarmTopic));
  }

  private addStackProtection(): void {
    // Add stack protection to prevent accidental deletion
    const cfnStack = this.node.defaultChild as cdk.CfnStack;
    if (cfnStack) {
      cfnStack.addPropertyOverride('DeletionPolicy', 'Retain');
    }
  }

  // Public method to enable/disable monitoring
  public enableMonitoring(enable = true): void {
    if (enable && !this.dashboard) {
      this.setupMonitoring(true);
    }
  }

  // Public method to get all resources for cleanup
  public getAllResources(): string[] {
    const resources: string[] = [];
    
    // EKS Cluster
    resources.push(this.cluster.clusterName);
    
    // ECR Repositories
    resources.push(this.backendRepository.repositoryName);
    resources.push(this.frontendRepository.repositoryName);
    
    // VPC
    resources.push(this.vpc.vpcId);
    
    // Log Groups
    this.logGroups.forEach(logGroup => {
      resources.push(logGroup.logGroupName);
    });
    
    // SNS Topic
    if (this.alarmTopic) {
      resources.push(this.alarmTopic.topicName);
    }
    
    // Dashboard
    if (this.dashboard) {
      resources.push(this.dashboard.dashboardName);
    }
    
    return resources;
  }

  private addClusterAutoscaler(): void {
    const clusterAutoscalerServiceAccount = this.cluster.addServiceAccount('cluster-autoscaler', {
      name: 'cluster-autoscaler',
      namespace: 'kube-system',
    });

    // Create IAM policy for cluster autoscaler
    const clusterAutoscalerPolicy = new iam.Policy(this, 'ClusterAutoscalerPolicy', {
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'autoscaling:DescribeAutoScalingGroups',
            'autoscaling:DescribeAutoScalingInstances',
            'autoscaling:DescribeLaunchConfigurations',
            'autoscaling:DescribeTags',
            'autoscaling:SetDesiredCapacity',
            'autoscaling:TerminateInstanceInAutoScalingGroup',
            'ec2:DescribeLaunchTemplateVersions',
          ],
          resources: ['*'],
        }),
      ],
    });

    clusterAutoscalerPolicy.attachToRole(clusterAutoscalerServiceAccount.role!);

    // Deploy Cluster Autoscaler using Helm
    this.cluster.addHelmChart('ClusterAutoscaler', {
      chart: 'cluster-autoscaler',
      repository: 'https://kubernetes.github.io/autoscaler',
      namespace: 'kube-system',
      values: {
        autoDiscovery: {
          clusterName: this.cluster.clusterName,
        },
        awsRegion: this.region,
        rbac: {
          serviceAccount: {
            create: false,
            name: clusterAutoscalerServiceAccount.serviceAccountName,
          },
        },
      },
    });
  }

  private addLoadBalancerController(): void {
    const albControllerServiceAccount = this.cluster.addServiceAccount('aws-load-balancer-controller', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system',
    });

    // Create IAM policy for ALB Controller
    const albControllerPolicy = new iam.Policy(this, 'ALBControllerPolicy', {
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'iam:CreateServiceLinkedRole',
            'ec2:DescribeAccountAttributes',
            'ec2:DescribeAddresses',
            'ec2:DescribeInternetGateways',
            'ec2:DescribeVpcs',
            'ec2:DescribeSubnets',
            'ec2:DescribeSecurityGroups',
            'ec2:DescribeInstances',
            'ec2:DescribeNetworkInterfaces',
            'ec2:DescribeTags',
            'elasticloadbalancing:DescribeLoadBalancers',
            'elasticloadbalancing:DescribeLoadBalancerAttributes',
            'elasticloadbalancing:DescribeListeners',
            'elasticloadbalancing:DescribeListenerCertificates',
            'elasticloadbalancing:DescribeSSLPolicies',
            'elasticloadbalancing:DescribeRules',
            'elasticloadbalancing:DescribeTargetGroups',
            'elasticloadbalancing:DescribeTargetGroupAttributes',
            'elasticloadbalancing:DescribeTargetHealth',
            'elasticloadbalancing:DescribeTags',
          ],
          resources: ['*'],
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'cognito-idp:DescribeUserPoolClient',
            'acm:ListCertificates',
            'acm:DescribeCertificate',
            'iam:ListServerCertificates',
            'iam:GetServerCertificate',
            'waf-regional:GetWebACL',
            'waf-regional:GetWebACLForResource',
            'waf-regional:AssociateWebACL',
            'waf-regional:DisassociateWebACL',
            'wafv2:GetWebACL',
            'wafv2:GetWebACLForResource',
            'wafv2:AssociateWebACL',
            'wafv2:DisassociateWebACL',
            'shield:DescribeProtection',
            'shield:GetSubscriptionState',
            'ec2:AuthorizeSecurityGroupIngress',
            'ec2:RevokeSecurityGroupIngress',
          ],
          resources: ['*'],
        }),
      ],
    });

    albControllerPolicy.attachToRole(albControllerServiceAccount.role!);

    // Add additional policies to the ALB Controller
    const albControllerAdditionalPolicy = new iam.Policy(this, 'ALBControllerAdditionalPolicy', {
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'elasticloadbalancing:CreateLoadBalancer',
            'elasticloadbalancing:CreateTargetGroup',
          ],
          resources: ['*'],
          conditions: {
            StringEquals: {
              'aws:RequestTag/kubernetes.io/cluster/iagent-cluster': 'owned',
            },
          },
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'elasticloadbalancing:CreateListener',
            'elasticloadbalancing:DeleteListener',
            'elasticloadbalancing:CreateRule',
            'elasticloadbalancing:DeleteRule',
            'elasticloadbalancing:SetWebAcl',
            'elasticloadbalancing:ModifyListener',
            'elasticloadbalancing:AddListenerCertificates',
            'elasticloadbalancing:RemoveListenerCertificates',
            'elasticloadbalancing:ModifyRule',
          ],
          resources: ['*'],
        }),
      ],
    });

    albControllerAdditionalPolicy.attachToRole(albControllerServiceAccount.role!);

    // Deploy AWS Load Balancer Controller using Helm
    this.cluster.addHelmChart('AwsLoadBalancerController', {
      chart: 'aws-load-balancer-controller',
      repository: 'https://aws.github.io/eks-charts',
      namespace: 'kube-system',
      values: {
        clusterName: this.cluster.clusterName,
        serviceAccount: {
          create: false,
          name: albControllerServiceAccount.serviceAccountName,
        },
        region: this.region,
        vpcId: this.cluster.vpc.vpcId,
      },
    });
  }

  private addExternalDNS(): void {
    const externalDnsServiceAccount = this.cluster.addServiceAccount('external-dns', {
      name: 'external-dns',
      namespace: 'kube-system',
    });

    // Create IAM policy for External DNS
    const externalDnsPolicy = new iam.Policy(this, 'ExternalDNSPolicy', {
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'route53:ChangeResourceRecordSets',
          ],
          resources: ['arn:aws:route53:::hostedzone/*'],
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'route53:ListResourceRecordSets',
            'route53:ListHostedZonesByName',
          ],
          resources: ['*'],
        }),
      ],
    });

    externalDnsPolicy.attachToRole(externalDnsServiceAccount.role!);

    // Deploy External DNS using Helm
    this.cluster.addHelmChart('ExternalDNS', {
      chart: 'external-dns',
      repository: 'https://kubernetes-sigs.github.io/external-dns',
      namespace: 'kube-system',
      values: {
        provider: 'aws',
        policy: 'sync',
        registry: 'txt',
        txtOwnerId: this.cluster.clusterName,
        serviceAccount: {
          create: false,
          name: externalDnsServiceAccount.serviceAccountName,
        },
      },
    });
  }

  private addMetricsServer(): void {
    this.cluster.addHelmChart('MetricsServer', {
      chart: 'metrics-server',
      repository: 'https://kubernetes-sigs.github.io/metrics-server',
      namespace: 'kube-system',
      values: {
        args: ['--kubelet-insecure-tls'],
      },
    });
  }

  private addNginxIngressController(): void {
    this.cluster.addHelmChart('NginxIngressController', {
      chart: 'ingress-nginx',
      repository: 'https://kubernetes.github.io/ingress-nginx',
      namespace: 'ingress-nginx',
      createNamespace: true,
      values: {
        controller: {
          service: {
            type: 'LoadBalancer',
            annotations: {
              'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb',
              'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing',
            },
          },
        },
      },
    });
  }
} 