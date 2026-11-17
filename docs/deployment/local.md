# Local validation

From the project directory in PowerShell:

```powershell
python -m pip install -r requirements.txt
python scripts/run_validation.py
```

The command writes `evidence/test-results/validation-report.json` and `evidence/test-results/validation-report.md`.

It does not start EverShop, does not delete `postgres-data`, and does not apply Terraform.

`scripts/setup.ps1` creates `.env` from `.env.example` only when `.env` is absent. Put the local database password in `.env`. Do not commit it.

`scripts/cleanup-local.ps1` may remove containers labelled `cloudcart.lab=mysql-security`. It refuses any argument that names `postgres-data`.

The production image is `application/docker/Dockerfile`. The 17 November 2026 Linux validation did not build it: Docker was not installed, and `http://127.0.0.1:3000/` refused the connection. That result is BLOCKED, not a healthy store. On Windows, build it only when you intend to, and do not remove the existing volume:

```powershell
docker build -f application/docker/Dockerfile -t cloudcart-evershop:local .
```
