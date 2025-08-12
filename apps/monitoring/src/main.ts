#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { MonitoringStack } from './lib/monitoring-stack';

const app = new cdk.App();

new MonitoringStack(app, 'IAgentMonitoringStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1', // Frankfurt - closest to Israel
  },
  description: 'iAgent Monitoring and Observability Stack',
});

app.synth(); 