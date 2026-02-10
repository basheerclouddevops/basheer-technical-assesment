# DevOps Technical Assessment — ECS on EC2 (Terraform)

## Purpose
This repository demonstrates a production-style ECS (EC2 launch type) deployment using:
- Application Load Balancer  
- ECS Capacity Provider  
- Mixed On-Demand + Spot capacity  
- Secure secrets via AWS SSM Parameter Store  
- Multi-AZ resilience  
- Zero-downtime deployment settings  

---

## How to run

```bash
cd terraform
terraform init
terraform plan
terraform apply
