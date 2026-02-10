# DESIGN

## A) Zero-Downtime Deployments
- An internal ALB sits in front of the ECS service.  
- During deployment, ECS starts new tasks first (max 200%).  
- Old tasks keep receiving traffic while new ones come up.  
- Only after new tasks pass ALB health checks are old tasks drained.  
- If new tasks fail health checks, ECS automatically rolls back.

## B) Secrets Handling
- Secrets are stored in AWS SSM Parameter Store (outside Terraform).  
- The ECS **task role** reads secrets at runtime.  
- No secrets appear in Terraform code, variables, or state.  
- This limits blast radius if the repo or state is compromised.

## C) Spot + On-Demand Strategy
- Two On-Demand instances form the availability baseline.  
- Spot instances are used only for scale (overflow capacity).  
- If Spot is reclaimed, the service continues running on On-Demand.  
- The capacity provider automatically replaces lost Spot capacity.

## D) Scaling Behavior
- ECS service can scale tasks based on CPU utilization.  
- The capacity provider watches for PENDING tasks.  
- When tasks are pending, it scales the Auto Scaling Group.  
- New EC2 instances join the ECS cluster and run waiting tasks.

## E) Operations & Monitoring (Top 5 Alerts)
1. ECS service unhealthy  
2. ALB 5xx error rate high  
3. Spot interruption notices  
4. Rising number of PENDING tasks  
5. High CPU on ECS tasks  

## F) What I would improve with more time
- Add HTTPS listener on ALB with ACM certificate  
- Add CloudWatch alarms + PagerDuty integration  
- Use instance refresh for safer ASG updates  
- Add blue/green deployment with CodeDeploy
