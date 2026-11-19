# Container review

Reviewed 19 November 2026 (Asia/Calcutta). The image was not built. Findings that need a running daemon stay open.

| Item | Result |
| --- | --- |
| Base image | `evershop/evershop` pinned to index digest `sha256:385934128c115f0ea92df17f5d70998532208d4a94b9b6b28149af74b5b3f6b2`. The tag `latest` is not used. |
| Platform digests | The Dockerfile comments record the amd64 and arm64 image digests observed with that index. They were not re-pulled. |
| Non-root | Not set. The upstream Dockerfile uses `node:18-alpine` and does not set `USER`. Adding `USER node` without inspecting a built image can stop EverShop writing under `/app`. Left unchanged. `STOPSIGNAL SIGTERM` is declared and has not been observed in a running container. |
| Ports | The image exposes 3000. Compose publishes `127.0.0.1:3000` only. PostgreSQL is not published. |
| Health | The process is healthy only when `/` returns 200–399. A connection error fails the check. This was not executed. |
| Secrets | No password or access key is in the Dockerfile. `DB_PASSWORD` is a Compose environment value from `.env`, which is gitignored. ECS is expected to use Secrets Manager. |
| Build context | The documented build uses the repository root. Docker was ignoring `application/docker/.dockerignore`. The root `.dockerignore` now excludes `.env`, keys, state, and evidence. The Dockerfile has no `COPY`, so those files are not layers either. |
| Size | Unknown. The image was not built. |
| MySQL lab | `mysql:8.0.40` is now pinned to its index digest. It was not started. Its volume is `cloudcart-mysql-lab`, not `postgres-data`. |
| ECR | Task 4 sets the repository tag mutability to `IMMUTABLE` and the task image to a digest. No image has been pushed. |

The official MySQL and PostgreSQL entrypoints start as root so they can initialize the data directory. That is unchanged.
