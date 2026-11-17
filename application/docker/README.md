# Docker

The development Compose file is the one already on the Windows machine. It will be read before it is edited.

The production Dockerfile will be added here in a later step. It must leave media outside the image so more than one ECS task can share the S3 bucket.
