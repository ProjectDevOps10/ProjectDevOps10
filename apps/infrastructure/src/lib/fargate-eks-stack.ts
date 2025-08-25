import * as cdk from 'aws-cdk-lib';
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface FargateEksStackProps extends cdk.StackProps {
  readonly clusterName?: string;
  readonly region?: string;
}

export class FargateEksStack extends cdk.Stack {
  public readonly cluster: eks.ICluster;
  public readonly albDnsOutput: cdk.CfnOutput;

  constructor(scope: Construct, id: string, props?: FargateEksStackProps) {
    super(scope, id, props);

    const clusterName = props?.clusterName || 'iagent-cluster';
    const region = props?.region || 'eu-central-1';

    // Import existing VPC and cluster
    const vpc = ec2.Vpc.fromLookup(this, 'ExistingVpc', {
      vpcId: 'vpc-03681ed8d08f5a0be',
    });

    // Import existing cluster
    this.cluster = eks.Cluster.fromClusterAttributes(this, 'ExistingCluster', {
      clusterName: clusterName,
      vpc: vpc,
      openIdConnectProvider: eks.OpenIdConnectProvider.fromOpenIdConnectProviderArn(
        this,
        'OidcProvider',
        `arn:aws:iam::${this.account}:oidc-provider/oidc.eks.${region}.amazonaws.com/id/DB27746AA5D434218936184AB68D7F5E`
      ),
    });

    // Create Pod Execution Role for Fargate
    const podExecutionRole = new iam.Role(this, 'FargatePodExecutionRole', {
      roleName: `${clusterName}-fargate-pod-execution-role`,
      assumedBy: new iam.ServicePrincipal('pods.eks.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonEKSFargatePodExecutionRolePolicy'),
      ],
    });

    // Get private subnets for Fargate profiles
    const privateSubnetIds = ['subnet-02bca6adbadba6f93', 'subnet-0f89addb5a39b3c81'];

    // Create Fargate profiles for different namespaces
    const namespaces = ['default', 'prod', 'staging'];
    namespaces.forEach(namespace => {
      new eks.CfnFargateProfile(this, `FargateProfile-${namespace}`, {
        clusterName: clusterName,
        fargateProfileName: `fp-${namespace}`,
        podExecutionRoleArn: podExecutionRole.roleArn,
        selectors: [{ namespace }],
        subnets: privateSubnetIds,
        tags: [
          { key: 'Name', value: `${clusterName}-fargate-${namespace}` },
          { key: 'Environment', value: namespace === 'default' ? 'development' : namespace },
          { key: 'Project', value: 'iAgent' },
          { key: 'ManagedBy', value: 'CDK' },
        ],
      });
    });

    // Switch CoreDNS to run on Fargate
    new eks.CfnAddon(this, 'CoreDNSFargateAddon', {
      clusterName: clusterName,
      addonName: 'coredns',
      resolveConflicts: 'OVERWRITE',
      configurationValues: JSON.stringify({ 
        computeType: 'Fargate' 
      }),
    });

    // Create IRSA service account for AWS Load Balancer Controller
    const awsLbControllerServiceAccount = this.cluster.addServiceAccount('AwsLoadBalancerController', {
      name: 'aws-load-balancer-controller',
      namespace: 'kube-system',
    });

    // Create IAM policy for AWS Load Balancer Controller
    const lbcPolicyDocument = new iam.PolicyDocument({
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'iam:CreateServiceLinkedRole',
            'ec2:DescribeAccountAttributes',
            'ec2:DescribeAddresses',
            'ec2:DescribeAvailabilityZones',
            'ec2:DescribeInternetGateways',
            'ec2:DescribeVpcs',
            'ec2:DescribeVpcPeeringConnections',
            'ec2:DescribeSubnets',
            'ec2:DescribeSecurityGroups',
            'ec2:DescribeInstances',
            'ec2:DescribeNetworkInterfaces',
            'ec2:DescribeTags',
            'ec2:GetCoipPoolUsage',
            'ec2:GetManagedPrefixListAssociations',
            'ec2:GetManagedPrefixListEntries',
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
            'shield:DescribeSubscription',
            'shield:CreateProtection',
            'shield:DeleteProtection',
          ],
          resources: ['*'],
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'ec2:AuthorizeSecurityGroupIngress',
            'ec2:RevokeSecurityGroupIngress',
            'ec2:CreateSecurityGroup',
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
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'elasticloadbalancing:CreateLoadBalancer',
            'elasticloadbalancing:CreateTargetGroup',
          ],
          resources: ['*'],
          conditions: {
            Null: {
              'aws:RequestedRegion': 'false',
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
          ],
          resources: ['*'],
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'elasticloadbalancing:AddTags',
            'elasticloadbalancing:RemoveTags',
          ],
          resources: [
            'arn:aws:elasticloadbalancing:*:*:targetgroup/*/*',
            'arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*',
            'arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*',
          ],
          conditions: {
            Null: {
              'aws:RequestedRegion': 'false',
              'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false',
            },
          },
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'elasticloadbalancing:ModifyLoadBalancerAttributes',
            'elasticloadbalancing:SetIpAddressType',
            'elasticloadbalancing:SetSecurityGroups',
            'elasticloadbalancing:SetSubnets',
            'elasticloadbalancing:DeleteLoadBalancer',
            'elasticloadbalancing:ModifyTargetGroup',
            'elasticloadbalancing:ModifyTargetGroupAttributes',
            'elasticloadbalancing:DeleteTargetGroup',
          ],
          resources: ['*'],
          conditions: {
            Null: {
              'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false',
            },
          },
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'elasticloadbalancing:RegisterTargets',
            'elasticloadbalancing:DeregisterTargets',
          ],
          resources: ['arn:aws:elasticloadbalancing:*:*:targetgroup/*/*'],
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'ec2:CreateTags',
          ],
          resources: ['arn:aws:ec2:*:*:security-group/*'],
          conditions: {
            StringEquals: {
              'ec2:CreateAction': 'CreateSecurityGroup',
            },
            Null: {
              'aws:RequestedRegion': 'false',
            },
          },
        }),
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            'ec2:CreateTags',
            'ec2:DeleteTags',
          ],
          resources: ['arn:aws:ec2:*:*:security-group/*'],
          conditions: {
            Null: {
              'aws:RequestedRegion': 'false',
              'aws:ResourceTag/elbv2.k8s.aws/cluster': 'false',
            },
          },
        }),
      ],
    });

    const lbcPolicy = new iam.ManagedPolicy(this, 'AwsLoadBalancerControllerPolicy', {
      description: 'Policy for AWS Load Balancer Controller',
      document: lbcPolicyDocument,
    });

    awsLbControllerServiceAccount.role.addManagedPolicy(lbcPolicy);

    // Install AWS Load Balancer Controller via Helm
    const awsLbController = this.cluster.addHelmChart('AwsLoadBalancerController', {
      repository: 'https://aws.github.io/eks-charts',
      chart: 'aws-load-balancer-controller',
      namespace: 'kube-system',
      release: 'aws-load-balancer-controller',
      version: '1.8.1',
      values: {
        clusterName: clusterName,
        region: region,
        vpcId: vpc.vpcId,
        serviceAccount: {
          create: false,
          name: awsLbControllerServiceAccount.serviceAccountName,
        },
        replicaCount: 1,
        podLabels: {
          app: 'aws-load-balancer-controller',
        },
      },
      wait: true,
    });

    // Sample NGINX application with ALB Ingress
    const sampleAppManifests = [
      {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: 'iagent-sample',
          namespace: 'default',
          labels: { app: 'iagent-sample' },
        },
        spec: {
          replicas: 2,
          selector: { matchLabels: { app: 'iagent-sample' } },
          template: {
            metadata: { labels: { app: 'iagent-sample' } },
            spec: {
              containers: [
                {
                  name: 'nginx',
                  image: 'nginx:stable-alpine',
                  ports: [{ containerPort: 80 }],
                  resources: {
                    requests: { memory: '64Mi', cpu: '50m' },
                    limits: { memory: '128Mi', cpu: '100m' },
                  },
                  readinessProbe: {
                    httpGet: { path: '/', port: 80 },
                    initialDelaySeconds: 5,
                    periodSeconds: 10,
                  },
                  livenessProbe: {
                    httpGet: { path: '/', port: 80 },
                    initialDelaySeconds: 15,
                    periodSeconds: 20,
                  },
                },
              ],
            },
          },
        },
      },
      {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: 'iagent-sample',
          namespace: 'default',
        },
        spec: {
          type: 'ClusterIP',
          selector: { app: 'iagent-sample' },
          ports: [{ port: 80, targetPort: 80, protocol: 'TCP' }],
        },
      },
      {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: 'iagent-sample',
          namespace: 'default',
          annotations: {
            'kubernetes.io/ingress.class': 'alb',
            'alb.ingress.kubernetes.io/scheme': 'internet-facing',
            'alb.ingress.kubernetes.io/target-type': 'ip', // Required for Fargate
            'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80}]',
            'alb.ingress.kubernetes.io/tags': `Environment=fargate,Cluster=${clusterName}`,
          },
        },
        spec: {
          rules: [
            {
              http: {
                paths: [
                  {
                    path: '/',
                    pathType: 'Prefix',
                    backend: {
                      service: {
                        name: 'iagent-sample',
                        port: { number: 80 },
                      },
                    },
                  },
                ],
              },
            },
          ],
        },
      },
    ];

    // Apply sample app manifests
    sampleAppManifests.forEach((manifest, index) => {
      const manifestResource = this.cluster.addManifest(`SampleApp${index}`, manifest);
      manifestResource.node.addDependency(awsLbController);
    });

    // Output ALB DNS (we'll retrieve this later via kubectl)
    this.albDnsOutput = new cdk.CfnOutput(this, 'SampleAppALBDNS', {
      value: 'Check kubectl get ingress iagent-sample -n default for ALB DNS',
      description: 'ALB DNS name for the sample application',
      exportName: `${clusterName}-sample-alb-dns`,
    });

    // Outputs
    new cdk.CfnOutput(this, 'ClusterName', {
      value: clusterName,
      description: 'EKS Cluster name',
    });

    new cdk.CfnOutput(this, 'FargateProfiles', {
      value: namespaces.join(', '),
      description: 'Namespaces with Fargate profiles',
    });

    new cdk.CfnOutput(this, 'PodExecutionRoleArn', {
      value: podExecutionRole.roleArn,
      description: 'Fargate Pod Execution Role ARN',
    });
  }
}
