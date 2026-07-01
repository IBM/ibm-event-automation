#!/usr/bin/env bash
# deploy.sh — deploy a migrated IBM EP flow to Confluent Platform for Apache Flink, using Confluent for Kubernetes
#
# Usage:
#   ./deploy.sh [options]
#
# Options (all optional — omitted values are prompted interactively):
#   --name                <name>       Application name (OpenShift resource name)
#   --image               <image>      Docker image, e.g. myregistry.io/flink-flow:v1
#   --namespace           <namespace>  OpenShift namespace to deploy into
#   --flink-env           <env>        FlinkEnvironment CR name
#   --pvc                 <pvc>        PersistentVolumeClaim name for Flink state storage
#   --savepoint           <path>       Savepoint path for state migration (e.g. file:///opt/flink/...)
#                                      Omit for a fresh deployment (no state restore).
#   --cmfrestclass        <name>       CMFRestClass CR name (default: "default")
#   --cmfrestclass-namespace <ns>      Namespace of the CMFRestClass CR (default: same as --namespace)
#   --dry-run                          Print the rendered YAML instead of submitting it.
#
# Examples:
#   # Interactive (prompts for all values):
#   ./deploy.sh
#
#   # Fully non-interactive:
#   ./deploy.sh --name my-flow --image myregistry.io/flink-flow:v1 \
#     --namespace flink --flink-env my-env --pvc my-pvc
#
#   # With state migration:
#   ./deploy.sh --name my-flow --image myregistry.io/flink-flow:v1 \
#     --namespace flink --flink-env my-env --pvc my-pvc \
#     --savepoint file:///opt/flink/volume/flink-sp/savepoint-e574c6-638b6089cdd2
#
#   # With a non-default CMFRestClass in a different namespace:
#   ./deploy.sh --name my-flow --image myregistry.io/flink-flow:v1 \
#     --namespace flink --flink-env my-env --pvc my-pvc \
#     --cmfrestclass my-class --cmfrestclass-namespace operator
#
# Requires: oc (preferred) or kubectl, logged in and targeting the correct cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/FlinkApplication.yaml"

# =============================================================================
# Detect oc vs kubectl
# =============================================================================
if command -v oc &>/dev/null; then
  KC=oc
elif command -v kubectl &>/dev/null; then
  KC=kubectl
else
  echo "Error: Neither 'oc' nor 'kubectl' found on PATH." >&2
  exit 1
fi

# =============================================================================
# Formatting
# =============================================================================
bold=$(tput bold 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)

header()  { echo ""; echo "${bold}${cyan}$*${reset}"; }
label()   { echo "${bold}$*${reset}"; }
hint()    { echo "  ${yellow}$*${reset}"; }
success() { echo "${green}$*${reset}"; }
br()      { echo ""; }

# =============================================================================
# Parse CLI flags
# =============================================================================
APP_NAME=""
APP_IMAGE=""
NAMESPACE=""
FLINK_ENV=""
PVC_NAME=""
SAVEPOINT_PATH=""
CMF_REST_CLASS=""
CMF_REST_CLASS_NS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)                   APP_NAME="$2";          shift 2 ;;
    --image)                  APP_IMAGE="$2";         shift 2 ;;
    --namespace)              NAMESPACE="$2";         shift 2 ;;
    --flink-env)              FLINK_ENV="$2";         shift 2 ;;
    --pvc)                    PVC_NAME="$2";          shift 2 ;;
    --savepoint)              SAVEPOINT_PATH="$2";    shift 2 ;;
    --cmfrestclass)           CMF_REST_CLASS="$2";    shift 2 ;;
    --cmfrestclass-namespace) CMF_REST_CLASS_NS="$2"; shift 2 ;;
    --dry-run)                DRY_RUN=true;           shift   ;;
    *) echo "Unknown option: $1" >&2; exit 1  ;;
  esac
done

# =============================================================================
# Prompt helpers (only called when a value wasn't supplied via flag)
# =============================================================================
ask() {
  local prompt="$1" default="${2:-}"
  local display_prompt
  if [[ -n "$default" ]]; then
    display_prompt="  > $prompt [${default}]: "
  else
    display_prompt="  > $prompt: "
  fi
  local value
  read -r -p "$display_prompt" value </dev/tty
  value="${value:-$default}"
  while [[ -z "$value" ]]; do
    echo "    Required — please enter a value." >&2
    read -r -p "$display_prompt" value </dev/tty
    value="${value:-$default}"
  done
  echo "$value"
}

ask_yn() {
  local prompt="$1"
  local answer
  read -r -p "  > $prompt [y/N]: " answer </dev/tty
  [[ "${answer:-N}" =~ ^[Yy]$ ]]
}

# =============================================================================
# Collect any missing values interactively
# =============================================================================
interactive=false
[[ -z "$APP_NAME" || -z "$APP_IMAGE" || -z "$NAMESPACE" || -z "$FLINK_ENV" || -z "$PVC_NAME" ]] && interactive=true

if $interactive; then
  echo ""
  echo "${bold}Deploy migrated IBM EP flow to Confluent Platform Flink${reset}"
  echo "────────────────────────────────────────────────────────"
fi

if [[ -z "$APP_NAME" || -z "$APP_IMAGE" ]]; then
  header "Application"
  br
fi

if [[ -z "$APP_NAME" ]]; then
  label "Application name"
  hint "A short OpenShift resource name, e.g. 'customer-orders-flow'."
  hint "Must be unique within the namespace."
  APP_NAME=$(ask "Name")
  br
fi

if [[ -z "$APP_IMAGE" ]]; then
  label "Image"
  hint "The image you built with the provided Dockerfile."
  hint "Must be accessible from your OpenShift cluster, e.g. 'myregistry.io/flink-flow:v1'."
  APP_IMAGE=$(ask "Image")
fi

if [[ -z "$NAMESPACE" ]]; then
  header "OpenShift namespace"
  br
  label "Namespace"
  hint "The OpenShift namespace to deploy the FlinkApplication into."
  hint "List namespaces with: $KC get namespaces"
  NAMESPACE=$(ask "Namespace")
fi

if [[ -z "$FLINK_ENV" ]]; then
  header "Flink environment"
  br
  label "FlinkEnvironment CR name"
  hint "List available environments with: $KC get flinkenvironment -A"
  FLINK_ENV=$(ask "Flink environment name")
fi

if [[ -z "$PVC_NAME" ]]; then
  header "State storage"
  br
  label "PVC name"
  hint "The PersistentVolumeClaim where Flink will store checkpoints and savepoints."
  hint "This PVC must already exist in the target namespace."
  PVC_NAME=$(ask "PVC name")
fi

# Savepoint: only prompt if not supplied via flag
if $interactive && [[ -z "$SAVEPOINT_PATH" ]]; then
  header "State migration (optional)"
  br
  echo "  If you are migrating an existing IBM EP flow and want to preserve its"
  echo "  in-flight state, provide the savepoint path captured when you suspended"
  echo "  the IBM EP FlinkDeployment. Skip for a fresh deployment."
  br
  if ask_yn "Restore from a savepoint?"; then
    br
    label "Savepoint path"
    hint "Found in status.jobStatus.upgradeSavepointPath on the old FlinkDeployment,"
    hint "or spec.savepoint.path on the FlinkStateSnapshot CR."
    hint "The file:/ prefix is required. Both file:/ and file:/// are accepted."
    hint "Example: file:///opt/flink/volume/flink-sp/savepoint-e574c6-638b6089cdd2"
    SAVEPOINT_PATH=$(ask "Savepoint path")
  fi
fi

# Derive upgradeMode from whether a savepoint was provided
if [[ -n "$SAVEPOINT_PATH" ]]; then
  UPGRADE_MODE="savepoint"
else
  UPGRADE_MODE="stateless"
fi

# =============================================================================
# Render template
# =============================================================================
# Apply defaults for optional CMFRestClass fields
CMF_REST_CLASS="${CMF_REST_CLASS:-default}"
CMF_REST_CLASS_NS="${CMF_REST_CLASS_NS:-}"

export APP_NAME APP_IMAGE NAMESPACE FLINK_ENV PVC_NAME UPGRADE_MODE SAVEPOINT_PATH CMF_REST_CLASS CMF_REST_CLASS_NS

rendered=$(envsubst < "$TEMPLATE")

if [[ -z "$SAVEPOINT_PATH" ]]; then
  rendered=$(echo "$rendered" | grep -v '^\s*initialSavepointPath:')
fi

# Strip the cmfRestClassRef namespace line when using the default (same namespace)
if [[ -z "$CMF_REST_CLASS_NS" ]]; then
  rendered=$(echo "$rendered" | grep -v '^\s*namespace:\s*$')
fi

# =============================================================================
# Summary
# =============================================================================
if $interactive || $DRY_RUN; then
  echo ""
  echo "────────────────────────────────────────────────────────"
  echo "${bold}Summary${reset}"
  echo "  Namespace        : ${bold}$NAMESPACE${reset}"
  echo "  Flink environment: ${bold}$FLINK_ENV${reset}"
  echo "  Application name : ${bold}$APP_NAME${reset}"
  echo "  Image            : ${bold}$APP_IMAGE${reset}"
  echo "  PVC              : ${bold}$PVC_NAME${reset}"
  echo "  CMFRestClass     : ${bold}${CMF_REST_CLASS:-default} (ns: ${CMF_REST_CLASS_NS:-$NAMESPACE})${reset}"
  if [[ -n "$SAVEPOINT_PATH" ]]; then
    echo "  Savepoint        : ${bold}$SAVEPOINT_PATH${reset}"
  else
    echo "  Savepoint        : ${bold}none (fresh deployment)${reset}"
  fi
  echo "────────────────────────────────────────────────────────"
fi

if $DRY_RUN; then
  echo ""
  echo "$rendered"
  exit 0
fi

if $interactive; then
  br
  if ! ask_yn "Apply this configuration?"; then
    echo ""
    echo "Aborted."
    exit 0
  fi
fi

# =============================================================================
# Submit
# =============================================================================
br
echo "Submitting FlinkApplication..."

tmpfile=$(mktemp /tmp/flink-application-XXXXXX.yaml)
trap 'rm -f "$tmpfile"' EXIT
echo "$rendered" > "$tmpfile"

$KC apply -f "$tmpfile"

br
success "Done."
echo "Monitor your application with:"
echo "  $KC get flinkApplication $APP_NAME -n $NAMESPACE -o yaml"
