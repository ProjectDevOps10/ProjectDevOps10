# AWS Setup for iAgent DevContainer

This document explains how AWS credentials are configured in the iAgent development container.

## 🏗️ Architecture

The devcontainer automatically loads AWS credentials from the `.secrets` file during startup, ensuring that AWS CLI and all AWS services are immediately available.

## 📁 Files

### `.secrets` (REQUIRED)
Contains your AWS credentials. **DO NOT commit this file to version control.**

```bash
# AWS Credentials for local GitHub Actions testing
AWS_ACCOUNT_ID=045498639212
AWS_ACCESS_KEY_ID=AKIAQVF7OENWFTE65PXP
AWS_SECRET_ACCESS_KEY=DOIiQPWdJHTLA1vcGiXcn4hhb58zJVOFGrx7MwDe

# GitHub Token (optional)
# GITHUB_TOKEN=your_github_personal_access_token_here
```

### `.devcontainer/validate-secrets.sh`
Validates that all required AWS credentials are present and properly formatted.

### `.devcontainer/startup.sh`
Runs during container startup to:
1. Validate AWS credentials
2. Set up global AWS profile for all shells
3. Load them into environment variables
4. Test AWS CLI connectivity

### `.devcontainer/setup-aws-profile.sh`
Creates a global profile script that automatically loads AWS credentials in every shell session.

## 🚀 How It Works

1. **Container Starts**: The devcontainer runs `startup.sh`
2. **Validation**: `validate-secrets.sh` checks for required credentials
3. **Global Setup**: `setup-aws-profile.sh` creates global profile for all shells
4. **Loading**: Credentials are loaded from `.secrets` file
5. **Testing**: AWS CLI connectivity is tested
6. **Ready**: Container is ready with full AWS access in every shell session

## ✅ Validation Checks

The system validates:
- **File Existence**: `.secrets` file must exist
- **Required Variables**: All AWS credentials must be present
- **Format**: Credentials must match expected patterns
- **Connectivity**: AWS CLI must work with the credentials

## 🧪 Testing

Run the test script to verify your setup:

```bash
./test-aws-setup.sh
```

This will:
- Validate credentials
- Test AWS CLI
- Test basic AWS services (S3, EC2)

## 🔧 Troubleshooting

### Container Won't Start
- Ensure `.secrets` file exists
- Check that all required variables are set
- Verify credential formats are correct

### AWS CLI Not Working
- Rebuild the devcontainer
- Check AWS permissions for your account
- Verify the region is correct

### Missing Permissions
- Ensure your AWS user has the necessary IAM permissions
- Check if credentials have expired

## 🚨 Security Notes

- **Never commit `.secrets` to version control**
- **Use IAM roles when possible instead of access keys**
- **Rotate access keys regularly**
- **Limit permissions to minimum required**

## 📋 Required AWS Permissions

Your AWS user should have at least:
- `sts:GetCallerIdentity`
- `s3:ListAllMyBuckets`
- `ec2:DescribeRegions`

For full iAgent functionality, you may need additional permissions based on your deployment requirements.

## 🔄 Updating Credentials

1. Edit the `.secrets` file
2. Rebuild the devcontainer
3. The new credentials will be automatically loaded

## 📚 Additional Resources

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [DevContainer Documentation](https://containers.dev/)
- [iAgent Project Documentation](./README.md)
