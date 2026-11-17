# AWS secure networking and compute lab

**Status: deployment-ready example; not deployed or validated against a live AWS account.**

## Scenario
Create a small public HTTP demonstration server in an isolated VPC, with a reserved private subnet and private S3 artifact storage. The private subnet has no NAT or instances, by design. This is not a high-availability production deployment.

## Architecture
Internet → Internet Gateway → public route table → public subnet → EC2 (Amazon Linux 2023 + Nginx, TCP 80). Separate private subnet (no internet route). S3 bucket (public access blocked, SSE-S3 encryption).

## Requirements
Terraform >=1.5, AWS CLI configured with an authorized account, permissions to create VPC, EC2, IAM-independent networking and S3 resources. Costs may apply, including public IPv4 and compute.

## Run
```bash
aws sts get-caller-identity
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output demo_url
```
Open the demo URL. The site is HTTP-only for demonstration; do not use it for sensitive data. Confirm the private subnet has no default route, the S3 bucket blocks public access, the instance uses IMDSv2 and encrypted root volume.

## Evidence checklist
- [ ] Redacted `terraform plan` and `apply` output
- [ ] Browser screenshot showing Nginx demo
- [ ] VPC/subnet/route table screenshots
- [ ] S3 public-access and encryption screenshots
- [ ] Date, region, cost estimate, test outcomes and any deviations

## Cleanup
`terraform destroy` after evidence capture. Bucket uses `force_destroy = true`: **do not put important data in it**. Terraform state may contain sensitive values; never commit `.tfstate` or plan files.
