# Windows Package Repository Lab (Chocolatey)

Terraform lab for deploying a self-hosted Chocolatey NuGet package repository on AWS. Provisions a Windows EC2 instance running IIS with the Chocolatey.Server web application, backed by an IAM role for S3 access.

## Architecture

```mermaid
flowchart TD
    subgraph VPC["VPC"]
        subgraph SG["Security Group"]
            EC2["EC2 Windows Server\nChocolatey.Server\n(IIS web app)\nuser_data bootstrap"]
        end
    end

    CLIENT["Choco Clients\n(Windows hosts)"] -- "HTTP\nchoco install/update" --> EC2
    OPS["Operator"] -- "RDP port 3389" --> EC2

    EC2 --> IAM["IAM Role\nS3 read/write"]
    EC2 --> S3["S3 Bucket\nPackage storage\n/ artifacts"]

    subgraph "Chocolatey.Server"
        IIS["IIS Site\nChocolateyServer"]
        PKG["C:\\tools\\chocolatey.server\nApp_Data\\Packages\n(.nupkg files)"]
        CFG["Web.config\n(API key + auth)"]
    end

    EC2 --- IIS & PKG & CFG
```

## Repository Structure

```
├── chocolatey-repository/
│   ├── main.tf               # EC2 + security group + IAM role + S3
│   ├── user_data.tpl         # Bootstrap: installs IIS + Chocolatey.Server
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── assume_role_policy.json  # EC2 trust policy
│   └── policy_s3_bucket.json    # S3 access policy
└── modules/
    ├── ec2_instance/         # EC2 module
    ├── ec2_role/             # IAM role module
    └── sg_security_group/    # Security group module
```

## Prerequisites

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) installed
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured
- Existing VPC with at least one subnet
- IAM user with admin permissions

## Variables to Update

| Variable | Description |
|----------|-------------|
| `vpc_id` | Target VPC ID |
| `subnet_id` | Subnet ID for EC2 placement |
| `image_id` | Windows Server AMI ID |
| `region` | AWS region |
| `cidr_blocks` | VPC CIDR for internal access |

## Usage

```shell
aws configure

terraform init
terraform plan
terraform apply --auto-approve
```

## Post-Deployment

The `user_data` bootstrap creates an IIS site called **ChocolateyServer** at `C:\tools\chocolatey.server`. A default `Web.config` is generated — change the default API key and credentials before exposing to production networks.

**Push a package to the repository:**
```powershell
choco push MyPackage.1.0.0.nupkg --source="http://<EC2_IP>/chocolatey" --api-key="<your-api-key>"
```

**Register the repository on choco clients:**
```powershell
choco source add -n=MyRepo -s="http://<EC2_IP>/chocolatey"
choco install <package-name>
```
