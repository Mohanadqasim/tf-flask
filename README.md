# Terraform AWS Flask CI/CD Project

## Overview
This project provisions AWS infrastructure using Terraform and deploys a Dockerized Flask application to an EC2 instance using GitHub Actions with OIDC authentication.  
The CI/CD pipeline builds a Docker image, pushes it to Amazon ECR, and deploys it automatically to EC2.

## Architecture
- EC2 instance (t3.micro)
- Security Group (SSH + TCP 5000)
- IAM role for EC2 (ECR pull access)
- Amazon ECR repository
- GitHub OIDC role (no stored AWS credentials)
- Dockerized Flask application

Deployment flow:  
GitHub → OIDC → ECR → EC2 → Docker restart

## Application
`app.py` exposes:
- `/` → returns `Hello World`
- `/health` → returns `OK`

The application runs on port `5000`.

## Infrastructure
Provisioned using Terraform:
- Default VPC
- Security group `tf-flask-sg`
- Key pair `tf-flask-key`
- IAM instance profile
- ECR repository `tf-flask-ecr`
- GitHub OIDC role for CI/CD

## CI/CD Deployment
Triggered on push to the `main` branch.

Pipeline steps:
1. Assume IAM role via OIDC  
2. Build Docker image  
3. Push image to ECR  
4. SSH into EC2  
5. Pull latest image  
6. Restart container  

## Run Locally
Build the image:
```bash
docker build -t tf-flask-app .
docker run -p 5000:5000 tf-flask-app