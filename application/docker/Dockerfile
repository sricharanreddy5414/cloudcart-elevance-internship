# Production image for EverShop on ECS.
# The base is the multi-architecture index digest observed on Docker Hub
# on 17 November 2026. Do not replace this with the tag "latest".
# linux/amd64 image: sha256:1bfc54d2bd0469c85a65e886df247848eeaa99dd484185aa83c09a4b3af6c0d9
# linux/arm64 image: sha256:fc82ae777693f20841adbfceed937bb50e3318520506785a3fc2709903edd0d5

ARG EVERSHOP_DIGEST=sha256:385934128c115f0ea92df17f5d70998532208d4a94b9b6b28149af74b5b3f6b2
FROM evershop/evershop@${EVERSHOP_DIGEST}

ENV NODE_ENV=production
EXPOSE 3000
STOPSIGNAL SIGTERM

LABEL org.opencontainers.image.title="cloudcart-evershop" \
      org.opencontainers.image.description="EverShop storefront. Credentials are not in this image."

# The published EverShop image is built FROM node:18-alpine and does not set USER.
# /app is root-owned. USER node is not set here: it was not verified against a
# built image, and EverShop writes runtime files during startup. Docker was
# not available when this was reviewed. Do not treat the image as non-root.

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/',function(r){process.exit(r.statusCode>=200&&r.statusCode<400?0:1)}).on('error',function(){process.exit(1)})"

# Media is not copied into the image. Product images belong in the private S3 bucket.
# Database credentials are injected at run time by ECS, from Secrets Manager.
