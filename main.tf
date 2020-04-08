locals {
  iam_changes_pattern = "(($.eventName=DeleteGroupPolicy) || ($.eventName=DeleteRolePolicy) ||($.eventName=DeleteUserPolicy) || ($.eventName=PutGroupPolicy) || ($.eventName=PutRolePolicy) || ($.eventName=PutUserPolicy) || ($.eventName=CreatePolicy) || ($.eventName=DeletePolicy) || ($.eventName=CreatePolicyVersion) || ($.eventName=DeletePolicyVersion) || ($.eventName=AttachRolePolicy) || ($.eventName=DetachRolePolicy) || ($.eventName=AttachUserPolicy) || ($.eventName=DetachUserPolicy) || ($.eventName=AttachGroupPolicy) || ($.eventName=DetachGroupPolicy))"

  vpc_changes_pattern = "(($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink))"

}

resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  count = var.unauthorized_api_calls ? length(var.accounts) : 0

  name           = "UnauthorizedAPICalls-${element(var.accounts, count.index).account_name}"
  pattern        = "{ (($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  count = var.unauthorized_api_calls ? length(var.accounts) : 0

  alarm_name                = "UnauthorizedAPICalls-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.unauthorized_api_calls[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring unauthorized API calls will help reveal application errors and may reduce time to detect malicious activity."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "no_mfa_console_signin_assumed_role" {
  count = var.no_mfa_console_login && ! var.disable_assumed_role_login_alerts ? length(var.accounts) : 0

  name           = "NoMFAConsoleSignin-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "NoMFAConsoleSignin"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "no_mfa_console_signin_no_assumed_role" {
  count = var.no_mfa_console_login && var.disable_assumed_role_login_alerts ? length(var.accounts) : 0

  name    = "NoMFAConsoleSignin ${element(var.accounts, count.index).account_name}"
  pattern = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.arn != \"*assumed-role*\") && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"

  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "NoMFAConsoleSignin"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "no_mfa_console_signin" {
  count = var.no_mfa_console_login ? length(var.accounts) : 0

  alarm_name                = "NoMFAConsoleSignin-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = var.disable_assumed_role_login_alerts ? aws_cloudwatch_log_metric_filter.no_mfa_console_signin_no_assumed_role[0].id : aws_cloudwatch_log_metric_filter.no_mfa_console_signin_assumed_role[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring for single-factor console logins will increase visibility into accounts that are not protected by MFA."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  count = var.root_usage ? length(var.accounts) : 0

  name           = "RootUsage-${element(var.accounts, count.index).account_name}"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" && $.userIdentity.accountId = ${element(var.accounts, count.index).account_id} }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "RootUsage"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  count = var.root_usage ? length(var.accounts) : 0

  alarm_name                = "RootUsage-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.root_usage[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring for root account logins will provide visibility into the use of a fully privileged account and an opportunity to reduce the use of it."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  count = var.iam_changes ? length(var.accounts) : 0

  name           = "IAMChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ${local.iam_changes_pattern} && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "IAMChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  count = var.iam_changes ? length(var.accounts) : 0

  alarm_name                = "IAMChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.iam_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to IAM policies will help ensure authentication and authorization controls remain intact."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "cloudtrail_cfg_changes" {
  count = var.cloudtrail_cfg_changes ? length(var.accounts) : 0

  name           = "CloudTrailCfgChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ (($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "CloudTrailCfgChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_cfg_changes" {
  count = var.cloudtrail_cfg_changes ? length(var.accounts) : 0

  alarm_name                = "CloudTrailCfgChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.cloudtrail_cfg_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to CloudTrail's configuration will help ensure sustained visibility to activities performed in the AWS account."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "console_signin_failures" {
  count = var.console_signin_failures ? length(var.accounts) : 0

  name           = "ConsoleSigninFailures-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "ConsoleSigninFailures"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_signin_failures" {
  count = var.console_signin_failures ? length(var.accounts) : 0

  alarm_name                = "ConsoleSigninFailures-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.console_signin_failures[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring failed console logins may decrease lead time to detect an attempt to brute force a credential, which may provide an indicator, such as source IP, that can be used in other event correlation."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "disable_or_delete_cmk" {
  count = var.disable_or_delete_cmk ? length(var.accounts) : 0

  name           = "DisableOrDeleteCMK-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "DisableOrDeleteCMK"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "disable_or_delete_cmk" {
  count = var.disable_or_delete_cmk ? length(var.accounts) : 0

  alarm_name                = "DisableOrDeleteCMK-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.disable_or_delete_cmk[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring failed console logins may decrease lead time to detect an attempt to brute force a credential, which may provide an indicator, such as source IP, that can be used in other event correlation."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "s3_bucket_policy_changes" {
  count = var.s3_bucket_policy_changes ? length(var.accounts) : 0

  name           = "S3BucketPolicyChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "S3BucketPolicyChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_bucket_policy_changes" {
  count = var.s3_bucket_policy_changes ? length(var.accounts) : 0

  alarm_name                = "S3BucketPolicyChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.s3_bucket_policy_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to S3 bucket policies may reduce time to detect and correct permissive policies on sensitive S3 buckets."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "aws_config_changes" {
  count = var.aws_config_changes ? length(var.accounts) : 0

  name           = "AWSConfigChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder)||($.eventName=DeleteDeliveryChannel)||($.eventName=PutDeliveryChannel)||($.eventName=PutConfigurationRecorder)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "AWSConfigChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "aws_config_changes" {
  count = var.aws_config_changes ? length(var.accounts) : 0

  alarm_name                = "AWSConfigChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.aws_config_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to AWS Config configuration will help ensure sustained visibility of configuration items within the AWS account."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  count = var.security_group_changes ? length(var.accounts) : 0

  name           = "SecurityGroupChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ (($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id})}"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  count = var.security_group_changes ? length(var.accounts) : 0

  alarm_name                = "SecurityGroupChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.security_group_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to security group will help ensure that resources and services are not unintentionally exposed."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "nacl_changes" {
  count = var.nacl_changes ? length(var.accounts) : 0

  name           = "NACLChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ (($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "NACLChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "nacl_changes" {
  count = var.nacl_changes ? length(var.accounts) : 0

  alarm_name                = "NACLChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.nacl_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to NACLs will help ensure that AWS resources and services are not unintentionally exposed."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "network_gw_changes" {
  count = var.network_gw_changes ? length(var.accounts) : 0

  name           = "NetworkGWChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ (($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "NetworkGWChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "network_gw_changes" {
  count = var.network_gw_changes ? length(var.accounts) : 0

  alarm_name                = "NetworkGWChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.network_gw_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to network gateways will help ensure that all ingress/egress traffic traverses the VPC border via a controlled path."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "route_table_changes" {
  count = var.route_table_changes ? length(var.accounts) : 0

  name           = "RouteTableChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ (($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable)) && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "RouteTableChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "route_table_changes" {
  count = var.route_table_changes ? length(var.accounts) : 0

  alarm_name                = "RouteTableChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.route_table_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to route tables will help ensure that all VPC traffic flows through an expected path."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "vpc_changes" {
  count = var.vpc_changes ? length(var.accounts) : 0

  name           = "VPCChanges-${element(var.accounts, count.index).account_name}"
  pattern        = "{ ${local.vpc_changes_pattern} && ($.userIdentity.accountId = ${element(var.accounts, count.index).account_id}) }"
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = "VPCChanges"
    namespace = var.alarm_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "vpc_changes" {
  count = var.vpc_changes ? length(var.accounts) : 0

  alarm_name                = "VPCChanges-${element(var.accounts, count.index).account_name}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = aws_cloudwatch_log_metric_filter.vpc_changes[0].id
  namespace                 = var.alarm_namespace
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Alert for account ${element(var.accounts, count.index).account_name} (ID: ${element(var.accounts, count.index).account_id}). Monitoring changes to VPC will help ensure that all VPC traffic flows through an expected path."
  alarm_actions             = [var.alarm_sns_topic_arn]
  treat_missing_data        = "notBreaching"
  insufficient_data_actions = []

  tags = {
    Automation = "Terraform"
  }
}
