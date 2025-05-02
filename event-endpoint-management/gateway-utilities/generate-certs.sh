#!/bin/bash
#
# © Copyright IBM Corp. 2025
#

set -e
HOSTNAME=${1:-localhost}
CA_HOSTNAME=${2:-localhost}
CERT_DIR=${3:-./certs/gateway}
CA_DIR=${3:-./certs/ca}

# Some versions of OpenSSL use flag for PKCS#1 RSA keys. Use it if present
openssl version
use_traditional=""
if [[ -n "$(openssl genrsa -help 2>&1 | grep -- -traditional)" ]]; then
  use_traditional="1"
  echo "Using OpenSSL '-traditional' flag for PKCS#1 RSA keys"
fi

openssl_genrsa() {
  if [[ -n "${use_traditional}" ]]; then
    openssl genrsa -traditional "$@"
  else
    openssl genrsa "$@"
  fi
}

setupdir() {
  if [ ! -d "${1}" ]; then
    echo "Creating working directory : ${1}"
    mkdir -p "${1}"
  else
    echo "Deleting working directory : ${1}"
    rm -f "${1}"/*
    ls "${1}"
  fi
}

generate() {
  local COMMON_NAME="${1}"
  local ALT_NAMES="${2:-localhost}"
  local ADDITIONAL_SUBJECT_FIELDS="${3}"
  echo "Generating certificate/key pair for ${COMMON_NAME} (${ALT_NAMES}) (${ADDITIONAL_SUBJECT_FIELDS})"

  SUBJECT_ALT_NAMES=""
  alt_names=$(echo $ALT_NAMES | tr "," "\n")
  # SANs start indexing at 1 not 0
  counter=1
  for name in $alt_names
  do
      SUBJECT_ALT_NAMES="${SUBJECT_ALT_NAMES}DNS:${name},"
      counter=$((counter+1))
  done

  SUBJECT_ALT_NAMES=${SUBJECT_ALT_NAMES%,}

  echo "${SUBJECT_ALT_NAMES}"

  openssl_genrsa -out "${CERT_DIR}"/"${COMMON_NAME}"-key.pem 2048
  openssl pkcs8 -topk8 -inform PEM -in "${CERT_DIR}"/"${COMMON_NAME}"-key.pem -out "${CERT_DIR}"/"${COMMON_NAME}"-pkcs8.pem -nocrypt
  openssl req -new \
    -key "${CERT_DIR}"/"${COMMON_NAME}"-key.pem \
    -out "${CERT_DIR}"/"${COMMON_NAME}".csr \
    -passin pass:password \
    -subj "/CN=${COMMON_NAME}${ADDITIONAL_SUBJECT_FIELDS}" \
    -reqexts SAN \
    -extensions SAN \
    -config <(cat /etc/ssl/openssl.cnf <(printf "\nx509_extensions = SAN\n[SAN]\nsubjectAltName=${SUBJECT_ALT_NAMES}"))

  openssl x509 -req \
    -in "${CERT_DIR}"/"${COMMON_NAME}".csr \
    -CA "${CA_DIR}"/cluster-ca.pem \
    -CAkey "${CA_DIR}"/cluster-ca-key.pem \
    -CAcreateserial \
    -extensions SAN \
    -extfile <(cat /etc/ssl/openssl.cnf \
        <(printf "\n[SAN]\nsubjectAltName=${SUBJECT_ALT_NAMES}")) \
    -out "${CERT_DIR}"/"${COMMON_NAME}".pem
  openssl pkcs12 -export -in "${CERT_DIR}"/"${COMMON_NAME}".pem -inkey "${CERT_DIR}"/"${COMMON_NAME}"-key.pem -out "${CERT_DIR}"/"${COMMON_NAME}".p12 -passout pass:password
}


# Naming convention :
#  Certificates/keys are named according to the following convention
#
#  <component hosting cert>-<component connecting to cert>-[client]      client is an optional designator that it is used for mutual TLS
#
#  e.g. gateway-apim.cert    is the certificate hosted by Gateway for APIM to connect to.
#

echo "Setting up/creating working directories"
setupdir ${CERT_DIR}
setupdir ${CA_DIR}

echo "1) Creating CA"
openssl req -x509 -out "${CA_DIR}"/cluster-ca.pem -keyout "${CA_DIR}"/cluster-ca-key.pem -newkey rsa:2048 -nodes -sha256 -subj "/CN=${CA_HOSTNAME}" -extensions EXT -config <( printf "[dn]\nCN=${CA_HOSTNAME}\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:${CA_HOSTNAME}\nbasicConstraints=critical,CA:TRUE\nkeyUsage=digitalSignature,keyCertSign\nextendedKeyUsage=serverAuth")
cat < "${CA_DIR}"/cluster-ca.pem | base64 > "${CA_DIR}"/cluster-ca.b64
keytool -import -trustcacerts -alias root -file "${CA_DIR}"/cluster-ca.pem -keystore "${CA_DIR}"/keystore.jks -noprompt -storepass password
cp "${CA_DIR}"/cluster-ca.pem "${CA_DIR}"/tls.crt
cp "${CA_DIR}"/cluster-ca-key.pem "${CA_DIR}"/tls.key

echo "2) Creating Kafka client certificate for Gateway"
generate "gateway-kafka-client" $HOSTNAME

# Example providing overrides to additional subjects
# generate "example" "*.<cluster-host-dns>" "/C=UK/ST=England/L=Hampshire/O=IBM/OU=EEM/STREET=DWEST/DC=GWCLIENT/UID=TEST"


# OpenSSL on Linux generates keys with restricted permissions. We need to open them up
# so that they can be mounted in the containers.
chmod 775 "${CERT_DIR}"/*
chmod 775 "${CA_DIR}"/*