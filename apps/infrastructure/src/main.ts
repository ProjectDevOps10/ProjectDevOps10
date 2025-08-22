#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CostOptimizedInfrastructureStack } from './lib/cost-optimized-infrastructure-stack';

const app = new cdk.App();

// Get parameters from context or environment
const clusterName = app.node.tryGetContext('clusterName') || 'iagent-cluster';
const instanceType = app.node.tryGetContext('nodeGroupInstanceType') || 't3.medium';
const enableSpotInstances = app.node.tryGetContext('enableSpotInstances') !== 'false';

new CostOptimizedInfrastructureStack(app, 'IAgentInfrastructureStack', {
  clusterName,
  nodeGroupInstanceType: instanceType,
  nodeGroupMinSize: 0,
  nodeGroupMaxSize: 2,
  nodeGroupDesiredSize: 1,
  enableSpotInstances,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1',
  },
});
