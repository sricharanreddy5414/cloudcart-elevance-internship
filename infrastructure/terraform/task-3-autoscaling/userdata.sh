#!/bin/bash
# Launch-hook contract. This is not an EC2 chaos test.
# default_result on the hook is ABANDON, so a crash or a timeout still
# keeps the instance out of service.
# CONTINUE is sent only after the schema version matches.
# A mismatch sends ABANDON immediately. The group then launches a replacement.
# This script does not migrate the database.
set -euo pipefail

HOOK_NAME="cloudcart-warmup"
ASG_NAME="${ASG_NAME}"
REGION="ap-south-1"

metadata_token() {
  curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"
}

instance_id() {
  local token
  token="$(metadata_token)"
  curl -sS -m 2 -H "X-aws-ec2-metadata-token: $${token}" http://169.254.169.254/latest/meta-data/instance-id
}

finish() {
  local result="$1"
  local iid
  iid="$(instance_id || true)"
  if [[ -z "$${iid}" ]]; then
    return 1
  fi
  timeout 20 aws autoscaling complete-lifecycle-action \
    --region "$${REGION}" \
    --lifecycle-hook-name "$${HOOK_NAME}" \
    --auto-scaling-group-name "$${ASG_NAME}" \
    --lifecycle-action-result "$${result}" \
    --instance-id "$${iid}"
}

on_error() {
  trap - ERR
  set +e
  finish ABANDON
  exit 1
}
trap on_error ERR

systemctl stop ecs || true
mkdir -p /etc/ecs
echo "ECS_CLUSTER=${ECS_CLUSTER}" >> /etc/ecs/ecs.config

IID="$(instance_id)"
timeout 20 aws autoscaling record-lifecycle-action-heartbeat \
  --region "$${REGION}" \
  --lifecycle-hook-name "$${HOOK_NAME}" \
  --auto-scaling-group-name "$${ASG_NAME}" \
  --instance-id "$${IID}"

EXPECTED_SCHEMA_VERSION="${EXPECTED_SCHEMA_VERSION}"
CURRENT_SCHEMA_VERSION="$(timeout 20 aws ssm get-parameter --region "$${REGION}" --name /cloudcart/production/schema_version --query Parameter.Value --output text)"

if [[ "$${EXPECTED_SCHEMA_VERSION}" != "$${CURRENT_SCHEMA_VERSION}" ]]; then
  echo "schema version mismatch; abandoning launch without starting the ECS agent"
  trap - ERR
  finish ABANDON
  exit 1
fi

# The instance becomes InService only after CONTINUE. Start the agent after
# that so a failed completion cannot leave tasks running on a hook that will
# later abandon the instance.
trap - ERR
finish CONTINUE
systemctl start ecs
