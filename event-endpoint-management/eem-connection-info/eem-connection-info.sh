#!/bin/bash
#
# © Copyright IBM Corp. 2026
#

#
# Use this script to retrieve the Kafka client connection information (URLs and certificates)
# for a given virtual topic.
#
# The Catalog in the Event Endpoint Management UI shows the aggregated addresses and certificate
# for the external endpoints, but does not show them for the internal endpoints. The main purpose
# of this script is to provide the internal endpoint information.
#
# A gateway group can contain several gateways, each exposing several addresses. The script
# aggregates them: the addresses of all the gateways in the group are gathered into one
# bootstrap.servers list, and the distinct CA certificates into one ca.pem file.
#
# This script uses the Event Endpoint Management Admin REST API (https://ibm.biz/eem-api-saas).
#
# Prerequisites: curl and jq must be installed and on PATH. Access token for the Admin API.
#
#   1.0.0  Initial release

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "Error: $*" >&2; exit 1; }

# Prints the error, then each hint on its own line. An empty hint is skipped.
# $1 - the error message, $2... - the hints
die_with_hint() {
    local message="$1" hint
    shift
    echo "Error: ${message}" >&2
    for hint in "$@"; do
        [[ -z "$hint" ]] || echo "       ${hint}" >&2
    done
    exit 1
}

ADMIN_URL_HINT="Check that --url is the Admin API URL shown under Profile > Access tokens (it ends with /admin)."

die_unexpected_response() { die_with_hint "unexpected response from the manager." "$ADMIN_URL_HINT"; }

# Fails unless the option has a value. Call it as: require_value "$@"
require_value() {
    [[ $# -gt 1 && -n "$2" ]] || die "$1 requires an argument."
}

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

MANAGER_URL=""
TOKEN=""
CACERT=""
FILE=""
TOPIC=""
ALIAS=""
GROUP=""
OUTPUT_DIR="."

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage:
  eem-connection-info.sh -u <manager-url> -c <ca-file> -k <token> \
                         -t <source-topic> -a <alias> -g <group> [-o <dir>]

Options:
  -u, --url <manager-url>        Event Endpoint Management Admin API base URL (from the manager UI)
  -c, --cacert <ca-file>         PEM root certificate of the manager (download link in the manager UI)
  -k, --token <token>            Access token (from the manager UI)
  -t, --topic <source-topic>     Source topic name (as shown in the Catalog)
  -a, --virtual-topic <alias>    Virtual topic alias (as shown in the Catalog)
  -g, --gateway-group <group>    Gateway group name (as shown in the Catalog)
  -o, --output-dir <dir>         Output directory for output files (default: current directory)
  -h, --help                     Show this help

You obtain the Admin API base URL, root certificate and access token from the Event Endpoint Management UI.

Output:
  For the internal (in-cluster) and the external addresses of the gateway group:
    <output-dir>/internalEndpoints/bootstrap-server.txt  and  ca.pem
    <output-dir>/endpoints/bootstrap-server.txt          and  ca.pem
  The matching Kafka client properties are also printed to stdout.

EOF
    exit "${1:-1}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            require_value "$@"; MANAGER_URL="$2"; shift 2 ;;
        -c|--cacert)
            require_value "$@"; CACERT="$2"; shift 2 ;;
        -k|--token)
            require_value "$@"; TOKEN="$2"; shift 2 ;;
        -f)
            require_value "$@"; FILE="$2"; shift 2 ;;
        -t|--topic)
            require_value "$@"; TOPIC="$2"; shift 2 ;;
        -a|--virtual-topic)
            require_value "$@"; ALIAS="$2"; shift 2 ;;
        -g|--gateway-group)
            require_value "$@"; GROUP="$2"; shift 2 ;;
        -o|--output-dir)
            require_value "$@"; OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            usage 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate required arguments
# ---------------------------------------------------------------------------

if [[ -z "$TOPIC" || -z "$ALIAS" || -z "$GROUP" ]]; then
    echo "Error: --topic, --virtual-topic, and --gateway-group are required." >&2
    usage
fi

if [[ -z "$MANAGER_URL" && -z "$FILE" ]]; then
    echo "Error: supply --url <manager-url>, --cacert <ca-file> and --token <token>." >&2
    usage
fi

if [[ -n "$MANAGER_URL" && -z "$TOKEN" ]]; then
    echo "Error: --token <token> is required when --url is set." >&2
    usage
fi

if [[ -n "$MANAGER_URL" ]]; then
    MANAGER_URL="${MANAGER_URL%/}"
    [[ "$MANAGER_URL" == https://* ]] || die "--url must start with https://"
    [[ -n "$CACERT" ]] || die_with_hint "--cacert <ca-file> is required when --url is set." \
        "In the manager UI, open Profile > Access tokens and click \"Download root certificate\"."
    [[ -r "$CACERT" && -f "$CACERT" ]] || die "CA certificate file not found or not readable: $CACERT"
fi

# ---------------------------------------------------------------------------
# Prerequisites check
# ---------------------------------------------------------------------------

for tool in curl jq; do
    command -v "$tool" >/dev/null 2>&1 \
        || die_with_hint "'$tool' is required but not found on PATH." "Install it and try again."
done

# ---------------------------------------------------------------------------
# Fetch or read JSON
# ---------------------------------------------------------------------------

# Calls the Admin API of the manager and sets JSON to the response body.
# Every failure stops the script with a message and a hint.
fetch_event_endpoints() {
    local endpoint="${MANAGER_URL}/eventendpoints" http_body http_code body hint="" token_escaped curl_rc=0

    http_body=$(mktemp)  # temp file to capture response body separately from the status code

    # --config reads the Authorization header from stdin, so the token does not show in the
    # process list (printf is a shell builtin). \ and " are escaped for the curl config syntax.
    token_escaped="${TOKEN//\\/\\\\}"
    token_escaped="${token_escaped//\"/\\\"}"

    # -o writes body to file
    # -w prints only the HTTP status code to stdout
    # --cacert verifies the manager certificate against the given CA
    # Accept selects the v3 response. Without it the API answers in the v1 format, which silently
    # omits every virtual topic that uses OAuth.
    # the exit code is captured so that set -e does not exit and the failure can be reported precisely
    http_code=$(printf 'header = "Authorization: Bearer %s"\n' "$token_escaped" | curl -s --config - \
        -o "$http_body" -w "%{http_code}" --cacert "$CACERT" \
        -H "Accept: application/vnd.ibm.eem.v3+json" \
        "$endpoint") || curl_rc=$?

    if [[ "$curl_rc" -ne 0 ]]; then
        rm -f "$http_body"
        case "$curl_rc" in
            # 35 handshake failed, 51 peer certificate or fingerprint, 58 local certificate,
            # 60 certificate not trusted by the CA, 77 CA file problem
            35|51|58|60|77)
                die_with_hint "TLS verification failed for ${endpoint} (curl exit code ${curl_rc})." \
                    "Check that --cacert is the root certificate downloaded from this manager (Profile > Access tokens)" \
                    "and that the host name in --url matches the certificate of the manager." ;;
            *)
                die_with_hint "could not connect to ${endpoint} (curl exit code ${curl_rc})." \
                    "Check the URL and that the manager is reachable." ;;
        esac
    fi

    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        body=$(cat "$http_body"); rm -f "$http_body"
        case "$http_code" in
            401|403) hint="Check that --token is a valid access token (Profile > Access tokens in the manager UI)." ;;
            404)     hint="$ADMIN_URL_HINT" ;;
        esac
        die_with_hint "manager returned HTTP ${http_code} from ${endpoint}" "${body:+Response: $body}" "$hint"
    fi

    JSON=$(cat "$http_body"); rm -f "$http_body"
    [[ -n "$JSON" ]] || die "empty response from ${endpoint}"
    if ! printf '%s' "$JSON" | jq empty 2>/dev/null; then
        echo "Error: response from manager is not valid JSON:" >&2
        printf '%s\n' "$JSON" | head -5 >&2
        exit 1
    fi
}

if [[ -n "$MANAGER_URL" ]]; then
    fetch_event_endpoints
else
    [[ -f "$FILE" ]] || die "file not found: $FILE"
    JSON=$(cat "$FILE")
fi

# ---------------------------------------------------------------------------
# Locate the source topic
# ---------------------------------------------------------------------------

printf '%s' "$JSON" | jq -e 'type == "array" and all(.[]; type == "object")' >/dev/null 2>&1 \
    || die_unexpected_response

# jq streams all matching objects as concatenated JSON; a unique source topic name produces exactly one
EP=$(printf '%s' "$JSON" | jq -r \
    --arg topic "$TOPIC" \
    '.[] | select(.name == $topic)')

[[ -n "$EP" ]] || die_with_hint "no source topic named '$TOPIC' found." \
    "Verify the source topic name (as shown in the Catalog, not the Kafka topic name) and that the token has read access."

printf '%s' "$EP" | jq -e '.virtualTopics | type == "array"' >/dev/null 2>&1 \
    || die_unexpected_response

# ---------------------------------------------------------------------------
# Locate the virtual topic
# ---------------------------------------------------------------------------

VT=$(printf '%s' "$EP" | jq -r \
    --arg alias "$ALIAS" \
    '.virtualTopics[] | select(.alias == $alias)')

[[ -n "$VT" ]] || die_with_hint "no virtual topic with alias '$ALIAS' under source topic '$TOPIC'." \
    "Check the virtual topic alias, as shown in the Catalog under that source topic."

# ---------------------------------------------------------------------------
# Locate the gateway group
# ---------------------------------------------------------------------------

# A group can contain several gateways; collect all of them into one array
GW=$(printf '%s' "$VT" | jq -c \
    --arg group "$GROUP" \
    '[.gatewaysPublishedTo[] | select(.group == $group)]')

[[ "$GW" != "[]" ]] || die_with_hint "no gateway group '$GROUP' for alias '$ALIAS'." \
    "Check the gateway group name the virtual topic is published to."

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

SEPARATOR_DOUBLE="==========================================================="
SEPARATOR_SINGLE="-----------------------------------------------------------"

# ---------------------------------------------------------------------------
# Aggregates the addresses and CA certificates of one endpoint type across all the
# gateways of the group, writes them to <output-dir>/<type>/ and prints them.
# An empty set is not an error: a notice is printed instead.
#
# $1 - endpoint type, the key in the API response: 'internalEndpoints' or 'endpoints'
# $2 - section title
# $3 - notice to print when the group has no address of this type
# ---------------------------------------------------------------------------
print_endpoints() {
    local type="$1" title="$2" empty_message="$3" entries bootstrap ca_pem dir

    echo ""
    echo "$SEPARATOR_SINGLE"
    echo "$title"
    echo "$SEPARATOR_SINGLE"

    # .[$type] uses the shell variable as a JSON key name; the entries of every gateway
    # in the group are flattened into a single array (a gateway may not have the key at all)
    entries=$(printf '%s' "$GW" | jq -c --arg type "$type" '[.[] | (.[$type] // [])[]]')
    if [[ "$(printf '%s' "$entries" | jq 'length')" -eq 0 ]]; then
        echo "$empty_message"
        return 0
    fi

    bootstrap=$(printf '%s' "$entries" | jq -r '[.[] | .host + ":" + (.port | tostring)] | join(",")')

    # unique[] collapses identical PEM blocks, so ca.pem holds each distinct certificate once,
    # regardless of how many gateways or brokers in the group share it
    ca_pem=$(printf '%s' "$entries" | jq -r '[.[] | (.certificates // [])[].pem] | unique | .[]')
    [[ -n "$ca_pem" ]] || die "no CA certificates found in '$type' for group '$GROUP'"

    dir="${OUTPUT_DIR}/${type}"
    mkdir -p "$dir" || die "cannot create the output directory: $dir"
    printf '%s\n' "$bootstrap" > "${dir}/bootstrap-server.txt"
    printf '%s\n' "$ca_pem" > "${dir}/ca.pem"  # printf preserves embedded newlines in PEM blocks; echo would not on all platforms

    echo "bootstrap.servers          written to: ${dir}/bootstrap-server.txt"
    echo "ssl.truststore.location    written to: ${dir}/ca.pem"
    echo ""
    echo "Kafka client properties:"
    echo "bootstrap.servers=${bootstrap}"
    echo "ssl.truststore.location=${dir}/ca.pem"
}

echo ""
echo "$SEPARATOR_DOUBLE"
echo "Kafka client connection details for:"
echo "- virtual topic: ${ALIAS} (source topic: ${TOPIC})"
echo "- gateway group: ${GROUP}"
echo "$SEPARATOR_DOUBLE"

print_endpoints "internalEndpoints" "Internal endpoints (for in-cluster Kafka clients)" \
    "Gateways in group '${GROUP}' are not configured to expose internal addresses."
print_endpoints "endpoints" "External endpoints" \
    "Gateways in group '${GROUP}' do not expose external addresses."

echo "$SEPARATOR_DOUBLE"
echo ""
