# Test categories

A passing test in one column does not satisfy another column.

| Category | What it may claim | What exists | Phase 4 result |
| --- | --- | --- | --- |
| A. Local unit | A function in this repository, with no service running | `tests/unit/`, `tests/chaos/`, `tests/security/`, `application/edge-functions/edge.test.js` | Run by `scripts/run_validation.py` |
| B. Local integration | More than one local component, still no AWS | `tests/integration/test_presign_api.py` starts the presign server. `tests/integration/test_runtime_contracts.py` reads Compose, the Dockerfile, and `.dockerignore`. | Run with the unit suite. No Docker daemon. |
| C. AWS infrastructure | `terraform plan` or an AWS read | Six stacks plan with the paid gate off. The plan adds nothing. | Plan exit 0 is not a created resource. |
| D. AWS deployment | A resource that exists in the account, with command output | None | Not run. `terraform apply` is not allowed in this phase. |

Not in category B: a container start, a PostgreSQL login, or an EverShop page. Those are blocked until Docker is present and the trial uses a volume other than the original `postgres-data`.

Not in category D: the in-process blue/green model, the RPO calculator, or the EICAR scanner.
