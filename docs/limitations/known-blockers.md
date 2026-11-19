# Known blockers

Updated 19 November 2026 (Asia/Calcutta). These items were not bypassed.

| Blocker | Why it stops the work | Label |
| --- | --- | --- |
| ₹0 target | WAF, Multi-AZ RDS, ALB, public IPv4, Route 53 zones, Secrets Manager, and a domain registration are paid. A month of the required stack is about ₹12,000 with GST. No apply is approved. See `docs/reports/zero-cost-strategy.md`. | BLOCKED |
| AWS caller is not identified in this environment | The AWS CLI is not installed here. A previous note said the Windows CLI had used root. Root must not be used. | BLOCKED |
| No registered domain | ACM DNS validation cannot finish, and Route 53 failover has no public name to cut over. | BLOCKED |
| Docker is absent in the validation environment | The image was not built and EverShop was not started here. `http://127.0.0.1:3000/` refused the connection. The Windows store was not modified. | BLOCKED |
| S3 Object Lambda for new customers | The service no longer accepts new customers. The thumbnail substitute is ordinary S3. | BLOCKED pending mentor approval |
| MySQL versus PostgreSQL | EverShop runs on PostgreSQL. The brief names MySQL. The MySQL stack is a separate lab and is not wired to the store. | DOCUMENTED, mentor approval required |
| Five-minute RPO | The calculator explains the RDS log-upload interval. `LatestRestorableTime` was not read. | SIMULATED |
| Chaos tests | Zone loss and instance health are in-process. No EC2 instance was terminated. | SIMULATED |
| ClamAV definitions | The scanner matches EICAR only. A current signature database is not packaged. | LOCAL |
| Demo video | No recording exists. The script is `docs/final-report/demo-script.md`. | BLOCKED |
| Portal submission | One-time and irreversible. It stays with the intern. | Not submitted |
