# Local validation

Phase 4 execution status: **BLOCKED**. Docker is not installed in the validation environment, and `http://127.0.0.1:3000/` was not serving EverShop. No image was built. No container was started. The Windows volume `postgres-data` was not mounted, inspected, or deleted.

## What the store needs

EverShop and PostgreSQL 16, on the Compose network `myevershop`. The app reads `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME`. PostgreSQL reads `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` from `.env`. The database port is not published. The app is published only on `127.0.0.1:3000`. The app waits until `pg_isready` succeeds. Data stays in the named volume `postgres-data`.

Copy `.env.example` to `.env` only if `.env` does not already exist, then set the local password. Do not commit `.env`. Do not put AWS keys in it. `scripts/setup.ps1` does that copy when `.env` is absent.

## Run the checks without starting the store

```powershell
python -m pip install -r requirements.txt
python scripts/run_validation.py
```

The command writes `evidence/test-results/validation-report.json` and `evidence/test-results/validation-report.md`. It does not start EverShop, does not delete `postgres-data`, and does not apply Terraform.

## Build the image without starting a database

```powershell
docker build -f application/docker/Dockerfile -t cloudcart-evershop:local .
```

`docker build` does not attach `postgres-data`. Do not follow it with `docker compose up` on the Windows store unless you intend to use the existing volume. Do not run `docker compose down -v`.

`scripts/cleanup-local.ps1` may remove containers labelled `cloudcart.lab=mysql-security`. It refuses any argument that names `postgres-data`.

An isolated database trial needs a different Compose project and a volume name other than `postgres-data`. This repository does not provide a second Compose file for that trial, because a copied command against `docker-compose.yml` would select the original volume name.

## What this environment did not do

No `docker build`, no `docker compose up`, no login to a database, and no change to the original EverShop directory.
