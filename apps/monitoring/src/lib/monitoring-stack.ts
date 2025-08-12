import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions';

export interface MonitoringStackProps extends cdk.StackProps {
  clusterName?: string;
  domainName?: string;
}

export class MonitoringStack extends cdk.Stack {
  public readonly dashboard: cloudwatch.Dashboard;
  public readonly alarmTopic: sns.Topic;

  constructor(scope: Construct, id: string, props: MonitoringStackProps) {
    super(scope, id, props);

    // SNS Topic for alarms
    this.alarmTopic = new sns.Topic(this, 'IAgentAlarmTopic', {
      topicName: 'iagent-alarms',
      displayName: 'iAgent Application Alarms',
    });

    // CloudWatch Dashboard
    this.dashboard = new cloudwatch.Dashboard(this, 'IAgentDashboard', {
      dashboardName: 'iAgent-Application-Dashboard',
    });

    // EKS Cluster Metrics
    if (props.clusterName) {
      this.addEksMetrics(props.clusterName);
    }

    // Application Metrics
    this.addApplicationMetrics();

    // Log Groups
    this.addLogGroups();

    // Alarms
    this.addAlarms();

    // Outputs
    new cdk.CfnOutput(this, 'DashboardUrl', {
      value: `https://${this.region}.console.aws.amazon.com/cloudwatch/home?region=${this.region}#dashboards:name=${this.dashboard.dashboardName}`,
      description: 'CloudWatch Dashboard URL',
    });

    new cdk.CfnOutput(this, 'AlarmTopicArn', {
      value: this.alarmTopic.topicArn,
      description: 'SNS Topic ARN for Alarms',
    });
  }

  private addEksMetrics(clusterName: string): void {
    // CPU Utilization
    const cpuMetric = new cloudwatch.Metric({
      namespace: 'AWS/EKS',
      metricName: 'CPUUtilization',
      dimensionsMap: {
        ClusterName: clusterName,
      },
      statistic: 'Average',
      period: cdk.Duration.minutes(5),
    });

    // Memory Utilization
    const memoryMetric = new cloudwatch.Metric({
      namespace: 'AWS/EKS',
      metricName: 'MemoryUtilization',
      dimensionsMap: {
        ClusterName: clusterName,
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

  private addLogGroups(): void {
    // Application Log Group
    const appLogGroup = new logs.LogGroup(this, 'IAgentAppLogs', {
      logGroupName: '/aws/eks/iagent/application',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Access Log Group
    new logs.LogGroup(this, 'IAgentAccessLogs', {
      logGroupName: '/aws/eks/iagent/access',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Error Log Group
    new logs.LogGroup(this, 'IAgentErrorLogs', {
      logGroupName: '/aws/eks/iagent/errors',
      retention: logs.RetentionDays.ONE_MONTH,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // Add log widgets to dashboard
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

  private addAlarms(): void {
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
} 