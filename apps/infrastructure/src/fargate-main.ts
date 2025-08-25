#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { FargateEksStack } from './lib/fargate-eks-stack';

const app = new cdk.App();

new FargateEksStack(app, 'IAgentFargateEksStack', {
  clusterName: 'iagent-cluster',
  region: 'eu-central-1',
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: 'eu-central-1',
  },
  description: 'EKS Fargate migration for iAgent cluster - fast pod starts with cost optimization',
  tags: {
    Project: 'iAgent',
    Environment: 'Production',
    CostCenter: 'DevOps',
    ManagedBy: 'CDK',
  },
});

app.synth();
