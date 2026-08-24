#!/usr/bin/env bash
set -euo pipefail

# Creates the four GCP projects and the Terraform state bucket.
# API/service enablement is left to Terraform; the only API enabled here is
# Cloud Storage on the host project, the minimum needed to create the bucket.

cd "$(dirname "${BASH_SOURCE[0]}")"
[[ -f .env ]] || { echo "Missing .env next to bootstrap.sh" >&2; exit 1; }
set -a; source .env; set +a
: "${BILLING_ACCOUNT_ID:?set BILLING_ACCOUNT_ID in .env}"

# A stable suffix keeps project IDs globally unique and reruns idempotent.
# Persisting only the suffix is enough, since every other name derives from it.
if [[ -z "${PROJECT_SUFFIX:-}" ]]; then
  PROJECT_SUFFIX="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c6)"
  perl -i -pe "s/^PROJECT_SUFFIX=.*/PROJECT_SUFFIX=$PROJECT_SUFFIX/" .env
fi

PREFIX="${PROJECT_PREFIX:-svpc-psc}"
HOST="${HOST_PROJECT_ID:-$PREFIX-host-$PROJECT_SUFFIX}"
SVC_A="${SERVICE_A_PROJECT_ID:-$PREFIX-svc-a-$PROJECT_SUFFIX}"
SVC_B="${SERVICE_B_PROJECT_ID:-$PREFIX-svc-b-$PROJECT_SUFFIX}"
PARTNER="${PARTNER_PROJECT_ID:-$PREFIX-partner-$PROJECT_SUFFIX}"
BUCKET="${TF_STATE_BUCKET:-$HOST-tfstate}"

# Parent for the projects. If FOLDER_ID is set, use it as-is. Otherwise, when an
# ORG_ID is given, create (or reuse) a folder under the org and place the
# projects there. This keeps the demo's four projects grouped and easy to clean up.
FOLDER_NAME="${FOLDER_NAME:-shared-vpc-psc}"
if [[ -z "${FOLDER_ID:-}" && -n "${ORG_ID:-}" ]]; then
  FOLDER_ID="$(gcloud resource-manager folders list --organization="$ORG_ID" \
    --filter="displayName=$FOLDER_NAME" --format='value(name)' | head -n1)"
  FOLDER_ID="${FOLDER_ID#folders/}"
  if [[ -z "$FOLDER_ID" ]]; then
    echo "Creating folder '$FOLDER_NAME' under organization $ORG_ID"
    FOLDER_ID="$(gcloud resource-manager folders create --display-name="$FOLDER_NAME" \
      --organization="$ORG_ID" --format='value(name)')"
    FOLDER_ID="${FOLDER_ID#folders/}"
  fi
  perl -i -pe "s|^FOLDER_ID=.*|FOLDER_ID=$FOLDER_ID|" .env
fi

parent=()
[[ -n "${FOLDER_ID:-}" ]] && parent=(--folder="$FOLDER_ID")
[[ -z "${FOLDER_ID:-}" && -n "${ORG_ID:-}" ]] && parent=(--organization="$ORG_ID")

create() { # <project_id> <display name>
  gcloud projects describe "$1" >/dev/null 2>&1 \
    || gcloud projects create "$1" --name="$2" "${parent[@]}"
  gcloud billing projects link "$1" --billing-account="$BILLING_ACCOUNT_ID" >/dev/null
}

echo "Creating projects (suffix: $PROJECT_SUFFIX)"
create "$HOST"    "SVPC PSC Host Network"
create "$SVC_A"   "SVPC PSC Service A Retail"
create "$SVC_B"   "SVPC PSC Service B Analytics"
create "$PARTNER" "SVPC PSC Partner Consumer"

echo "Creating Terraform state bucket gs://$BUCKET"
gcloud services enable storage.googleapis.com --project="$HOST" >/dev/null
gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1 \
  || gcloud storage buckets create "gs://$BUCKET" --project="$HOST" \
       --location="${LOCATION:-US}" --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update "gs://$BUCKET" --versioning >/dev/null

echo "Done. Folder=${FOLDER_ID:-none}  Host=$HOST  State bucket=gs://$BUCKET"
