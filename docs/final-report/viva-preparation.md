# Viva preparation

Say this, and do not add a deployment that has not happened.

CloudCart is an EverShop store. The store database is PostgreSQL. Task 2 is a separate MySQL security lab because the brief asks for MySQL and EverShop does not run on MySQL. The two are not connected. The Windows volume `postgres-data` is the original store data and is not deleted by this repository.

The Terraform stacks describe Route 53, ACM, WAF, MySQL, Auto Scaling, ECS on EC2, CloudFront, and S3. `confirm_paid_deployment` defaults to false, so a plan adds nothing. No stack has been applied. There is no live URL.

Local tests cover HSTS and redirect rules, presigned URL expiry, EICAR quarantine, a Pillow WebP thumbnail, query filtering, signed-URL expiry, a simulated IAM token, a simulated rotation, a simulated five-minute RPO flag that stays false, in-process scaling, and a simulated blue/green rollback. Those results are LOCALLY VALIDATED. They are not AWS DEPLOYED.

S3 Object Lambda has been closed to new customers since 7 November 2025. The thumbnail file is an ordinary object. It does not meet the Object Lambda requirement. The scanner matches the EICAR test string and does not include a ClamAV database.

If asked for the cost, say the target is ₹0 and the required services are not free. WAF, a domain, Multi-AZ RDS, an ALB, and public IPv4 addresses bill. A month of the combined design is about ₹12,000 with GST. Nothing has been created, so the current AWS charge from this project is zero.

The portal submission is done by the intern, not by this repository.
