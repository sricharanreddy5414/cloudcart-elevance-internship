# Production image

`application/docker/Dockerfile` starts from the pinned EverShop index digest. It does not copy the repository, media, or a database password into the image. ECS is expected to inject `DB_PASSWORD` from Secrets Manager at run time.

The image was not built in the Phase 4 environment. Docker was not installed. Do not describe this file as a built or scanned image.

Build from the repository root so the root `.dockerignore` is the one Docker reads:

```powershell
docker build -f application/docker/Dockerfile -t cloudcart-evershop:local .
```

That command does not start a container and does not attach `postgres-data`.

The upstream image does not set `USER`. This Dockerfile does not add one. A non-root user has not been verified against a running container.
