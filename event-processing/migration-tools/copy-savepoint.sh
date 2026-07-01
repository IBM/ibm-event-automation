#!/usr/bin/env bash
# copy-savepoint.sh — copy Flink state from a PVC in one namespace to a PVC in another.
#
# Uses a temporary pod in each namespace to stage the copy via local disk.
# Works with any storage class and access mode.
#
# Usage:
#   ./copy-savepoint.sh [options]
#
# Options (all optional — omitted values are prompted interactively):
#   --src-namespace  <ns>    Namespace containing the source PVC (e.g. event-automation)
#   --src-pvc        <pvc>   Source PVC name
#   --src-path       <path>  Path inside the source PVC to copy (e.g. /flink-sp)
#   --dst-namespace  <ns>    Namespace containing the destination PVC (e.g. confluent)
#   --dst-pvc        <pvc>   Destination PVC name
#   --dst-path       <path>  Path inside the destination PVC to write to (default: same as --src-path)
#   --dry-run                Show what would be done without executing
#
# Example:
#   ./copy-savepoint.sh \
#     --src-namespace event-automation --src-pvc basic-datagen --src-path /flink-sp \
#     --dst-namespace confluent        --dst-pvc flink-state
#
# Requires: kubectl (or oc), and sufficient local disk for a temporary copy of the data. 

set -euo pipefail

# =============================================================================
# Formatting
# =============================================================================
bold=$(tput bold 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
red=$(tput setaf 1 2>/dev/null || true)

header()  { echo ""; echo "${bold}${cyan}$*${reset}"; }
label()   { echo "${bold}$*${reset}"; }
hint()    { echo "  ${yellow}$*${reset}"; }
success() { echo "${green}$*${reset}"; }
err()     { echo "${red}Error: $*${reset}" >&2; }
br()      { echo ""; }
kc()      { echo "  ${bold}+ $KC $*${reset}" >&2; $KC "$@"; }

# =============================================================================
# Detect kubectl vs oc
# =============================================================================
if command -v oc &>/dev/null; then
  KC=oc
elif command -v kubectl &>/dev/null; then
  KC=kubectl
else
  err "Neither 'oc' nor 'kubectl' found on PATH."
  exit 1
fi

# =============================================================================
# Parse CLI flags
# =============================================================================
SRC_NAMESPACE=""
SRC_PVC=""
SRC_PATH=""
DST_NAMESPACE=""
DST_PVC=""
DST_PATH=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-namespace) SRC_NAMESPACE="$2"; shift 2 ;;
    --src-pvc)       SRC_PVC="$2";       shift 2 ;;
    --src-path)      SRC_PATH="$2";      shift 2 ;;
    --dst-namespace) DST_NAMESPACE="$2"; shift 2 ;;
    --dst-pvc)       DST_PVC="$2";       shift 2 ;;
    --dst-path)      DST_PATH="$2";      shift 2 ;;
    --dry-run)       DRY_RUN=true;       shift   ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# =============================================================================
# Prompt helpers
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

# =============================================================================
# Collect missing values interactively
# =============================================================================
interactive=false
[[ -z "$SRC_NAMESPACE" || -z "$SRC_PVC" || -z "$SRC_PATH" || -z "$DST_NAMESPACE" || -z "$DST_PVC" ]] \
  && interactive=true

if $interactive; then
  echo ""
  echo "${bold}Copy Flink state between PVCs${reset}"
  echo "────────────────────────────────────────────────────────"
fi

if [[ -z "$SRC_NAMESPACE" || -z "$SRC_PVC" || -z "$SRC_PATH" ]]; then
  header "Source"
  br
fi

if [[ -z "$SRC_NAMESPACE" ]]; then
  label "Source namespace"
  hint "The namespace where the IBM EP FlinkDeployment was running."
  SRC_NAMESPACE=$(ask "Source namespace")
  br
fi

if [[ -z "$SRC_PVC" ]]; then
  label "Source PVC name"
  hint "The PVC mounted by the IBM EP FlinkDeployment."
  SRC_PVC=$(ask "Source PVC name")
  br
fi

if [[ -z "$SRC_PATH" ]]; then
  label "Source path"
  hint "Path inside the source PVC to copy, relative to the PVC root."
  hint "IBM's template by default stores savepoints under /flink-sp."
  hint "To copy everything, use: /"
  SRC_PATH=$(ask "Source path" "/")
  br
fi

if [[ -z "$DST_NAMESPACE" || -z "$DST_PVC" ]]; then
  header "Destination"
  br
fi

if [[ -z "$DST_NAMESPACE" ]]; then
  label "Destination namespace"
  hint "The namespace where Confluent Platform Flink is installed."
  DST_NAMESPACE=$(ask "Destination namespace")
  br
fi

if [[ -z "$DST_PVC" ]]; then
  label "Destination PVC name"
  hint "The PVC that will be mounted by the Confluent FlinkApplication."
  DST_PVC=$(ask "Destination PVC name")
fi

# Default dst path to src path
DST_PATH="${DST_PATH:-$SRC_PATH}"

# Normalise: ensure leading slash, strip trailing slash (but preserve bare /)
normalise_path() {
  local p="/${1#/}"   # ensure leading slash
  p="${p%/}"          # strip trailing slash
  echo "${p:-/}"      # if stripping left empty, restore /
}
SRC_PATH="$(normalise_path "$SRC_PATH")"
DST_PATH="$(normalise_path "$DST_PATH")"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "────────────────────────────────────────────────────────"
echo "${bold}Summary${reset}"
echo "  Source : ${bold}$SRC_NAMESPACE/$SRC_PVC:/data$SRC_PATH${reset}"
echo "  Dest   : ${bold}$DST_NAMESPACE/$DST_PVC:/data$DST_PATH${reset}"
echo "  Tool   : ${bold}$KC${reset}"
echo "────────────────────────────────────────────────────────"

if $DRY_RUN; then
  br
  echo "Dry run — no changes made."
  exit 0
fi

if $interactive; then
  br
  read -r -p "  > Proceed? [y/N]: " answer </dev/tty
  if [[ ! "${answer:-N}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# =============================================================================
# Helpers: spin up / tear down reader/writer pods
# =============================================================================
READER_POD="pvc-copy-reader-$$"
WRITER_POD="pvc-copy-writer-$$"

POD_SPEC_TEMPLATE='{
  "spec": {
    "containers": [{
      "name": "copy-agent",
      "image": "busybox",
      "command": ["sleep", "3600"],
      "volumeMounts": [{"mountPath": "/data", "name": "v"}]
    }],
    "volumes": [{"name": "v", "persistentVolumeClaim": {"claimName": "PVC_PLACEHOLDER"}}],
    "restartPolicy": "Never"
  }
}'

cleanup() {
  br
  echo "Cleaning up temporary pods..."
  kc delete pod "$READER_POD" -n "$SRC_NAMESPACE" --ignore-not-found --wait=false 2>/dev/null || true
  kc delete pod "$WRITER_POD" -n "$DST_NAMESPACE" --ignore-not-found --wait=false 2>/dev/null || true
  [[ -n "${LOCAL_TMPDIR:-}" && -d "$LOCAL_TMPDIR" ]] && rm -rf "$LOCAL_TMPDIR"
}
trap cleanup EXIT

wait_for_pod() {
  local pod="$1" ns="$2"
  echo "  Waiting for pod $pod to be ready..."
  kc wait pod "$pod" -n "$ns" --for=condition=Ready --timeout=120s
}

# =============================================================================
# Step 1: start reader pod in source namespace
# =============================================================================
header "Step 1 of 4 — Starting reader pod in $SRC_NAMESPACE"
br

READER_SPEC="${POD_SPEC_TEMPLATE/PVC_PLACEHOLDER/$SRC_PVC}"
kc run "$READER_POD" --image=busybox --restart=Never \
  --namespace="$SRC_NAMESPACE" \
  --overrides="$READER_SPEC" \
  -- sleep 3600

wait_for_pod "$READER_POD" "$SRC_NAMESPACE"

# =============================================================================
# Step 2: copy data to local temp dir
# =============================================================================
header "Step 2 of 4 — Copying from source PVC to local disk"
br

LOCAL_TMPDIR=$(mktemp -d)

echo "  $SRC_NAMESPACE/$SRC_PVC:/data$SRC_PATH  →  $LOCAL_TMPDIR"

# Use tar inside the pod — handles all paths including / cleanly
kc exec "$READER_POD" -n "$SRC_NAMESPACE" -- \
  tar cf - -C "/data$SRC_PATH" . \
  | tar xf - -C "$LOCAL_TMPDIR" --no-same-owner

echo "  Done. Local size: $(du -sh "$LOCAL_TMPDIR" | cut -f1)"

echo ""
echo "  Files copied from source:"
find "$LOCAL_TMPDIR" -type f | sort | while read -r f; do
  echo "    /data$SRC_PATH/${f#"$LOCAL_TMPDIR/"}"
done

# =============================================================================
# Step 3: start writer pod in destination namespace
# =============================================================================
header "Step 3 of 4 — Starting writer pod in $DST_NAMESPACE"
br

WRITER_SPEC="${POD_SPEC_TEMPLATE/PVC_PLACEHOLDER/$DST_PVC}"
kc run "$WRITER_POD" --image=busybox --restart=Never \
  --namespace="$DST_NAMESPACE" \
  --overrides="$WRITER_SPEC" \
  -- sleep 3600

wait_for_pod "$WRITER_POD" "$DST_NAMESPACE"

# Ensure destination directory exists on the target PVC
kc exec "$WRITER_POD" -n "$DST_NAMESPACE" -- mkdir -p "/data$DST_PATH"

# =============================================================================
# Step 4: copy data from local disk to destination PVC
# =============================================================================
header "Step 4 of 4 — Copying from local disk to destination PVC"
br

echo "  $LOCAL_TMPDIR  →  $DST_NAMESPACE/$DST_PVC:/data$DST_PATH"

tar cf - -C "$LOCAL_TMPDIR" . \
  | kc exec -i "$WRITER_POD" -n "$DST_NAMESPACE" -- \
      tar xf - -C "/data$DST_PATH" --no-same-owner

# List every file now present at destination
echo ""
echo "  Files written to $DST_NAMESPACE/$DST_PVC:"
kc exec "$WRITER_POD" -n "$DST_NAMESPACE" -- \
  find "/data$DST_PATH" -type f | sort | while read -r f; do
  echo "    $f"
done

br
success "Done."
echo "State copied to $DST_NAMESPACE/$DST_PVC at path $DST_PATH"

