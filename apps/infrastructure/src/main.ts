#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { CostOptimizedInfrastructureStack } from './lib/cost-optimized-infrastructure-stack';

const app = new cdk.App();

// Get parameters from context or environment
const clusterName = app.node.tryGetContext('clusterName') || 'iagent-cluster-v2';
const instanceType = app.node.tryGetContext('nodeGroupInstanceType') || 't3.small';
const enableSpotInstances = false; // Disable spot instances to avoid quota issues

new CostOptimizedInfrastructureStack(app, 'IAgentInfrastructureStackV3', {
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
