# ADDENDUM — Production Scenarios

## 1) Spot failure during deployment (60% reclaimed)
- Spot instances are terminated by AWS.  
- Tasks running on those instances stop.  
- ECS continues serving traffic from On-Demand instances.  
- The capacity provider detects lost capacity and scales the ASG.  
- New Spot instances launch and new tasks are placed.  
- ALB keeps routing traffic → **no downtime to users.**

## 2) Secrets break at runtime (SSM permission removed)
- New tasks fail to start because they cannot read SSM.  
- ECS shows TASK FAILED / PROVISIONING error.  
- CloudWatch alarms would alert the team.  
- Fix: restore SSM permission to the ECS task role.  
- Redeploy service → tasks recover safely.

## 3) Pending task deadlock (10 desired, 6 capacity)
- 4 tasks remain in PENDING state.  
- Capacity provider notices lack of capacity.  
- ASG scales out with new EC2 instances.  
- New instances join the ECS cluster.  
- Pending tasks move to RUNNING automatically.

## 4) Deployment safety (rolling update)
- ECS starts new tasks first.  
- ALB registers new healthy targets.  
- Old tasks are drained only after replacements are healthy.  
- If new tasks fail health checks → ECS rolls back.

## 5) TLS, trust boundary, identity
- TLS terminates at the ALB.  
- Traffic inside the VPC is plain HTTP.  
- Containers run using the **ECS Task Role**.  
- The task role can only read its specific SSM parameter.

## 6) Cost floor (zero traffic for 12 hours)
You still pay for:
- Application Load Balancer  
- Minimum 2 On-Demand EC2 instances  
- NAT Gateway  
- EBS volumes attached to instances  

## 7) Three real failure modes

### A) AZ outage  
**Detection:** ALB target unhealthy + CloudWatch alarms  
**Blast radius:** Only one AZ  
**Mitigation:** Multi-AZ design keeps service running in other AZs  

### B) Spot interruption  
**Detection:** Spot interruption notice + ECS task stops  
**Blast radius:** Only Spot capacity  
**Mitigation:** On-Demand baseline keeps service alive  

### C) Bad deployment  
**Detection:** ALB health check failures  
**Blast radius:** Limited to new tasks  
**Mitigation:** ECS automatic rollback
