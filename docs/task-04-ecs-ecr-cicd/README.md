# Task 4 — Immutable deployment with ECS, ECR, and CI/CD

Status: **LOCAL / DOCUMENTED. Not deployed.** `application/docker/Dockerfile` and `docker-compose.yml` pin the EverShop image by digest. Terraform defines ECS on EC2, an ALB, two target groups, CodeDeploy blue/green, ECR immutable tags, Parameter Store names, a CodeBuild project, and a CodePipeline. The CodeBuild role trusts `codebuild.amazonaws.com`. The pipeline trusts `codepipeline.amazonaws.com`. None of those AWS resources exist. The image was not built in the validation environment because Docker is not installed there.

## Objective

Build EverShop as an image, store it in ECR, run it on ECS on EC2 behind an ALB, configure it from Parameter Store, and ship it through CodePipeline and CodeBuild with a blue/green traffic shift that can roll back.

## Requirements

1. Containerize EverShop.
2. Push images to ECR.
3. ECS on EC2.
4. An Application Load Balancer.
5. Configuration in Systems Manager Parameter Store.
6. CodePipeline.
7. CodeBuild.
8. CI/CD.
9. Zero-downtime blue/green deployments.

## Design notes

The production Dockerfile starts from the pinned `evershop/evershop` digest and does not copy a media volume into the image. Media is the Task 6 bucket. `docker-compose.yml` remains the development file and keeps PostgreSQL. `ci-cd/codedeploy/taskdef.json` carries the `<IMAGE1_NAME>` placeholder the pipeline deploy action expects. A CodeStar connection ARN is still required before an approved apply; the default is empty and the resource count stays zero.

ECS uses the EC2 launch type, as the brief requires. Fargate is not a substitute. The service sits in private subnets. The ALB listens in the public subnets, with the regional ACM certificate, and forwards to the task target group.

Parameter Store holds non-secret values: database host, database name, image bucket, and CloudFront domain. The database password is not a parameter. The task role reads secrets at runtime, or uses IAM database authentication.

CodeBuild builds the image and pushes the digest to ECR. CodePipeline runs that build and then a CodeDeploy ECS blue/green deployment. Blue/green here means all of the following:

- The ECS service uses the CodeDeploy deployment controller.
- Two target groups exist.
- A test listener can reach the replacement set before production traffic moves.
- Production traffic is shifted.
- A rollback shifts production traffic back to the previous task set.
- The test captures both shifts.

A rolling update is a valid ECS feature and will be labeled as a rolling update if that is what was run.

## Evidence to collect later

- Dockerfile and the development Compose file, with secrets removed from any copy that is committed.
- ECR repository and an image digest.
- Cluster, service, and task definition.
- ALB listeners, target groups, and health checks.
- Parameter names and types. Values that are sensitive are not printed.
- `buildspec.yml` and the pipeline definition.
- A deployment record showing the traffic shift, and a second record showing rollback.

## Security and rollback

The pipeline role can deploy. It cannot use root. Image tags are immutable digests in the task definition that was deployed. Rollback is the CodeDeploy rollback to the previous revision, followed by a health check on the storefront. If the new image fails its test listener, production traffic is left on the original set.

## Cost

The ALB, EC2 instances, EBS, CodeBuild minutes, and the pipeline can all bill. ECR storage for one small image is minor. Approval and a destroy list come before the first apply.

## Not done

The Dockerfile exists. ECR, ECS, the ALB, Parameter Store, CodeBuild, and CodePipeline do not. Blue/green rollback is covered by `cloudcart/deploy.py` and is SIMULATED. It is not a CodeDeploy traffic shift. Docker and `http://127.0.0.1:3000/` were BLOCKED in the 17 November 2026 validation run on this Linux environment.
