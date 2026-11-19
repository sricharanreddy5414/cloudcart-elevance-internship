#!/bin/bash
# Launch-hook contract. This is not an EC2 chaos test.
# The launch hook default is ABANDON, so a crash or a timeout stays out of service.
# CONTINUE is sent only after the schema version matches.
# This script does not migrate the database and does not print parameter values.
set -euo pipefail

HOOK_NAME="cloudcart-warmup"
DRAIN_HOOK="cloudcart-drain"
ASG_NAME="${ASG_NAME}"
REGION="ap-south-1"
LOG=/var/log/cloudcart-bootstrap.log
umask 077
touch "$${LOG}"
exec >>"$${LOG}" 2>&1

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
  local hook="$2"
  local iid
  iid="$(instance_id || true)"
  if [[ -z "$${iid}" ]]; then
    return 1
  fi
  timeout 20 aws autoscaling complete-lifecycle-action \
    --region "$${REGION}" \
    --lifecycle-hook-name "$${hook}" \
    --auto-scaling-group-name "$${ASG_NAME}" \
    --lifecycle-action-result "$${result}" \
    --instance-id "$${iid}"
}

on_error() {
  trap - ERR
  set +e
  echo "bootstrap failed; abandoning launch without starting the ECS agent"
  finish ABANDON "$${HOOK_NAME}"
  exit 1
}
trap on_error ERR

if ! command -v aws >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
  echo "required command missing; abandoning launch"
  finish ABANDON "$${HOOK_NAME}"
  exit 1
fi

systemctl stop ecs || true
mkdir -p /etc/ecs
cat > /etc/ecs/ecs.config <<EOF
ECS_CLUSTER=${ECS_CLUSTER}
ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
EOF

cat > /usr/local/sbin/cloudcart-drain <<'DRAIN'
#!/bin/bash
# Runs at shutdown and on a termination hook. Failure still ends in CONTINUE
# because the hook default is CONTINUE. This does not run a migration.
set +e
CLUSTER="cloudcart"
REGION="ap-south-1"
ASG_NAME="${ASG_NAME}"
TOKEN=$(curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IID=$(curl -sS -m 2 -H "X-aws-ec2-metadata-token: $${TOKEN}" http://169.254.169.254/latest/meta-data/instance-id)
if [[ -n "$${IID}" ]]; then
  ARN=$(aws ecs list-container-instances --region "$${REGION}" --cluster "$${CLUSTER}" --filter "ec2InstanceId == $${IID}" --query "containerInstanceArns[0]" --output text 2>/dev/null || true)
  if [[ -n "$${ARN}" && "$${ARN}" != "None" ]]; then
    aws ecs update-container-instances-state --region "$${REGION}" --cluster "$${CLUSTER}" --container-instances "$${ARN}" --status DRAINING >/dev/null 2>&1 || true
  fi
  timeout 20 aws autoscaling complete-lifecycle-action \
    --region "$${REGION}" \
    --lifecycle-hook-name "cloudcart-drain" \
    --auto-scaling-group-name "$${ASG_NAME}" \
    --lifecycle-action-result CONTINUE \
    --instance-id "$${IID}" >/dev/null 2>&1 || true
fi
DRAIN
chmod 0755 /usr/local/sbin/cloudcart-drain

cat > /etc/systemd/system/cloudcart-drain.service <<'UNIT'
[Unit]
Description=Drain CloudCart tasks before shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cloudcart-drain
TimeoutStartSec=60

[Install]
WantedBy=shutdown.target
UNIT
systemctl enable cloudcart-drain.service

IID="$(instance_id)"
timeout 20 aws autoscaling record-lifecycle-action-heartbeat \
  --region "$${REGION}" \
  --lifecycle-hook-name "$${HOOK_NAME}" \
  --auto-scaling-group-name "$${ASG_NAME}" \
  --instance-id "$${IID}"

EXPECTED_SCHEMA_VERSION="${EXPECTED_SCHEMA_VERSION}"
CURRENT_SCHEMA_VERSION="$(timeout 20 aws ssm get-parameter --region "$${REGION}" --name /cloudcart/production/schema_version --query Parameter.Value --output text || true)"

if [[ -z "$${CURRENT_SCHEMA_VERSION}" || "$${CURRENT_SCHEMA_VERSION}" == "None" || "$${EXPECTED_SCHEMA_VERSION}" != "$${CURRENT_SCHEMA_VERSION}" ]]; then
  echo "schema check failed; abandoning launch without starting the ECS agent"
  trap - ERR
  finish ABANDON "$${HOOK_NAME}"
  exit 1
fi

# The instance becomes InService only after CONTINUE. Start the agent after
# that so a failed completion cannot leave tasks running on a hook that will
# later abandon the instance.
trap - ERR
finish CONTINUE "$${HOOK_NAME}"
systemctl start ecs
