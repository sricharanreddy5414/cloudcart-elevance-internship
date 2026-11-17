#!/bin/bash
# Container instances stay out of the ECS cluster until the schema version
# matches and the lifecycle hook is completed. A failing check exits before
# the ECS agent starts. The hook's default result is ABANDON.
set -euo pipefail

systemctl stop ecs || true
mkdir -p /etc/ecs
echo "ECS_CLUSTER=${ECS_CLUSTER}" >> /etc/ecs/ecs.config

EXPECTED_SCHEMA_VERSION="${EXPECTED_SCHEMA_VERSION}"
CURRENT_SCHEMA_VERSION="$(aws ssm get-parameter --region ap-south-1 --name /cloudcart/production/schema_version --query Parameter.Value --output text)"

if [[ "$${EXPECTED_SCHEMA_VERSION}" != "$${CURRENT_SCHEMA_VERSION}" ]]; then
  echo "schema version mismatch; refusing to register tasks"
  exit 1
fi

# Warm-up is complete when the ECS agent is allowed to start.
systemctl start ecs

TOKEN="$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"
INSTANCE_ID="$(curl -sS -H "X-aws-ec2-metadata-token: $${TOKEN}" http://169.254.169.254/latest/meta-data/instance-id)"

aws autoscaling complete-lifecycle-action \
  --region ap-south-1 \
  --lifecycle-hook-name cloudcart-warmup \
  --auto-scaling-group-name "${ASG_NAME}" \
  --lifecycle-action-result CONTINUE \
  --instance-id "$${INSTANCE_ID}"
