# Questions for the internship mentor

Send these in your own mail or chat. They decide evaluation and stipend. I cannot answer them.

---

Hello,

I am building the six Cloud Technology tasks as one EverShop project called CloudCart. Two facts change how the evidence will look, and I want your decision before I treat a substitute as acceptable.

1. Local simulation. My AWS budget for this internship is ₹0. The required design includes services that bill by the hour, including NAT Gateway, Application Load Balancer, Multi-AZ RDS, EC2, Route 53 hosted zones, and WAF. I can build infrastructure as code, validate it, and run EverShop locally at no cost. I will not describe that work as a live AWS deployment.

   Are local implementation and validated templates eligible for evaluation and for stipend consideration, or do you require live AWS console evidence for each task?

2. Database engine. The Task 2 brief asks for MySQL RDS. EverShop supports PostgreSQL only, and my working store already uses PostgreSQL 16. RDS for PostgreSQL supports the same security controls the task lists: private subnets, Multi-AZ, no public access, IAM database authentication, forced TLS, Secrets Manager rotation, and point-in-time recovery.

   Should the store database be RDS for PostgreSQL, with every listed control demonstrated, or do you require a separate MySQL instance as well?

I will keep receipts of anything that is actually created in AWS, and I will mark anything that was only simulated.

Thank you.

---

Record the reply, with the date, in this file under the questions. Do not start a paid deployment because a reply is slow. Do not mark a simulated task as accepted by the mentor until the reply says so.
