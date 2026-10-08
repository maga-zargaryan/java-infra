#!/usr/bin/env bash
# Waits for the app fleet to finish rolling out, then checks the public health endpoint.
# A new AMI starts an instance refresh that Terraform does not wait for; this fails the
# deploy if the refresh fails or rolls back. Run from an environment's Terraform directory.
set -euo pipefail

ASG=$(terraform output -raw autoscaling_group_name)
URL=$(terraform output -raw url)

while true; do
  REFRESH=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$ASG" \
    --max-records 1 --query 'InstanceRefreshes[0]' --output json)
  STATUS=$(jq -r '.Status // "None"' <<<"$REFRESH")
  ID=$(jq -r '.InstanceRefreshId // ""' <<<"$REFRESH")
  case "$STATUS" in
    None | Successful) break ;;
    Pending | InProgress | Cancelling | RollbackInProgress | Baking)
      echo "$(date -u +%H:%M:%S) instance refresh $ID: $STATUS"
      sleep 30 ;;
    *)
      echo "::error::Instance refresh $ID ended $STATUS: $(jq -r '.StatusReason // ""' <<<"$REFRESH")"
      exit 1 ;;
  esac
done

for _ in $(seq 1 20); do
  if curl -fsS --max-time 10 "$URL/health" >/dev/null; then
    echo "### Rollout healthy: $URL" >> "$GITHUB_STEP_SUMMARY"
    exit 0
  fi
  sleep 15
done
echo "::error::$URL/health did not return 200"
exit 1
