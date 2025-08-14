#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { CostOptimizedInfrastructureStack } from './lib/cost-optimized-infrastructure-stack.js';

const app = new cdk.App();

// Get environment variables for configuration
const enableMonitoring = process.env.ENABLE_MONITORING !== 'false'; // Default: true
const enableAlarms = process.env.ENABLE_ALARMS !== 'false'; // Default: true
const domainName = process.env.DOMAIN_NAME;
const clusterName = process.env.CLUSTER_NAME || 'iagent-cluster';
const nodeGroupInstanceType = process.env.NODE_GROUP_INSTANCE_TYPE || 't3.medium';
const nodeGroupMinSize = parseInt(process.env.NODE_GROUP_MIN_SIZE || '1');
const nodeGroupMaxSize = parseInt(process.env.NODE_GROUP_MAX_SIZE || '3');
const nodeGroupDesiredSize = parseInt(process.env.NODE_GROUP_DESIRED_SIZE || '2');

// Create the main infrastructure stack
new CostOptimizedInfrastructureStack(app, 'IAgentInfrastructureStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1', // Frankfurt - closest to Israel
  },
  description: 'iAgent DevOps Project Infrastructure Stack',
  
  // Infrastructure configuration
  domainName,
  clusterName,
  nodeGroupInstanceType: nodeGroupInstanceType as any,
  nodeGroupMinSize,
  nodeGroupMaxSize,
  nodeGroupDesiredSize,
  
  // Monitoring configuration
  enableMonitoring,
  enableAlarms,
});

// Add tags to all resources
cdk.Tags.of(app).add('Project', 'iAgent');
cdk.Tags.of(app).add('Environment', process.env.ENVIRONMENT || 'dev');
cdk.Tags.of(app).add('ManagedBy', 'CDK');
cdk.Tags.of(app).add('CostCenter', 'DevOps-Project');

// Output configuration summary
console.log('🚀 iAgent Infrastructure Configuration:');
console.log(`   Region: ${process.env.CDK_DEFAULT_REGION || 'eu-central-1'}`);
console.log(`   Cluster: ${clusterName}`);
console.log(`   Monitoring: ${enableMonitoring ? 'Enabled' : 'Disabled'}`);
console.log(`   Alarms: ${enableAlarms ? 'Enabled' : 'Disabled'}`);
console.log(`   Domain: ${domainName || 'Not configured'}`);
console.log(`   Node Group: ${nodeGroupInstanceType} (${nodeGroupMinSize}-${nodeGroupMaxSize})`);
console.log('');

// Add helpful commands to the output
app.node.addMetadata('commands', {
  deploy: 'npx nx run infrastructure:deploy',
  destroy: 'npx nx run infrastructure:destroy',
  diff: 'npx nx run infrastructure:diff',
  synth: 'npx nx run infrastructure:synth',
  bootstrap: 'npx nx run infrastructure:bootstrap',
}); 