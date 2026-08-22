#!/usr/bin/env bash
set -euo pipefail

# Deletes the four demo projects and the folder created by bootstrap.sh.
# Run this AFTER `terraform destroy`. Deleting the host project also removes the
# Terraform state bucket it contains, so no separate bucket cleanup is needed.
#
# Projects are recoverable for ~30 days; their IDs cannot be reused until then.
# Usage: ./cleanup.sh          (prompts for confirmation)
#        ./cleanup.sh --yes    (skips the prompt)

cd "$(dirname "${BASH_SOURCE[0]}")"
[[ -f .env ]] || { echo "Missing .env next to cleanup.sh" >&2; exit 1; }
set -a; source .env; set +a

# Same derivation as bootstrap.sh.
PREFIX="${PROJECT_PREFIX:-svpc-psc}"
SUFFIX="${PROJECT_SUFFIX:-}"
HOST="${HOST_PROJECT_ID:-$PREFIX-host-$SUFFIX}"
SVC_A="${SERVICE_A_PROJECT_ID:-$PREFIX-svc-a-$SUFFIX}"
SVC_B="${SERVICE_B_PROJECT_ID:-$PREFIX-svc-b-$SUFFIX}"
PARTNER="${PARTNER_PROJECT_ID:-$PREFIX-partner-$SUFFIX}"
PROJECTS=("$HOST" "$SVC_A" "$SVC_B" "$PARTNER")

echo "This will DELETE (recoverable for ~30 days):"
printf '  project: %s\n' "${PROJECTS[@]}"
[[ -n "${FOLDER_ID:-}" ]] && echo "  folder:  ${FOLDER_ID} (${FOLDER_NAME:-})"
echo "Deleting the host project also removes the Terraform state bucket."
echo

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Type 'delete' to confirm: " ans
  [[ "$ans" == "delete" ]] || { echo "Aborted."; exit 1; }
fi

for p in "${PROJECTS[@]}"; do
  if gcloud projects describe "$p" >/dev/null 2>&1; then
    echo "Deleting project $p"
    gcloud projects delete "$p" --quiet
  else
    echo "Project $p not found, skipping."
  fi
done

# The folder can only be deleted once it holds no active projects. Freshly
# deleted projects may still be draining, so this can fail on the first run.
if [[ -n "${FOLDER_ID:-}" ]]; then
  echo "Deleting folder $FOLDER_ID"
  if ! gcloud resource-manager folders delete "$FOLDER_ID" --quiet; then
    echo
    echo "Folder delete failed — the projects are likely still draining."
    echo "Wait for them to finish, then re-run ./cleanup.sh --yes, or delete manually:"
    echo "  gcloud resource-manager folders delete $FOLDER_ID"
  fi
fi

echo "Done."
