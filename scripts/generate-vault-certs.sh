#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="${CERT_DIR:-certs}"
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-devanshu.dev}"
LB_HOSTNAME="${LB_HOSTNAME:-vault.devanshu.dev}"

TARGETS=(
  "s-vault-01:10.21.16.38"
  "s-vault-02:10.21.16.40"
  "s-vault-03:10.21.16.39"
)

mkdir -p "${CERT_DIR}"

timestamp() {
  date +"%Y%m%d%H%M%S"
}

backup_file() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    mv "${file}" "${file}.$(timestamp).bak"
  fi
}

CA_KEY="${CERT_DIR}/vault-root-ca.key"
CA_CERT="${CERT_DIR}/vault-root-ca.crt"

if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
  echo "==> Generating Vault root CA"
  openssl req -x509 -new -nodes \
    -subj "/CN=Vault Root CA" \
    -days "${CERT_DAYS}" \
    -newkey "rsa:${KEY_BITS}" \
    -keyout "${CA_KEY}" \
    -out "${CA_CERT}" \
    -extensions v3_ca \
    -config <(cat <<-EOF
      [req]
      distinguished_name=req
      x509_extensions=v3_ca
      prompt=no
      [v3_ca]
      subjectKeyIdentifier=hash
      authorityKeyIdentifier=keyid:always,issuer
      basicConstraints = critical, CA:true
      keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
    )
else
  echo "==> Reusing existing CA at ${CA_CERT}"
fi

for entry in "${TARGETS[@]}"; do
  host="${entry%%:*}"
  ip="${entry##*:}"

  echo "==> Generating certificate for ${host} (${ip})"
  KEY_FILE="${CERT_DIR}/${host}.key"
  CSR_FILE="${CERT_DIR}/${host}.csr"
  CRT_FILE="${CERT_DIR}/${host}.crt"
  EXT_FILE="${CERT_DIR}/${host}.ext"

  backup_file "${KEY_FILE}"
  backup_file "${CSR_FILE}"
  backup_file "${CRT_FILE}"
  backup_file "${EXT_FILE}"

  openssl genrsa -out "${KEY_FILE}" "${KEY_BITS}"

  cat > "${EXT_FILE}" <<-EOF
    authorityKeyIdentifier=keyid,issuer
    basicConstraints=CA:FALSE
    keyUsage = digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @alt_names
    [alt_names]
    DNS.1 = ${host}
    DNS.2 = ${host}.${CLUSTER_DOMAIN}
    IP.1 = ${ip}
EOF

  if [[ -n "${LB_HOSTNAME}" ]]; then
    cat >> "${EXT_FILE}" <<-EOF
    DNS.3 = ${LB_HOSTNAME}
EOF
  fi

  SAN_VALUE="DNS:${host},DNS:${host}.${CLUSTER_DOMAIN},IP:${ip}"
  if [[ -n "${LB_HOSTNAME}" ]]; then
    SAN_VALUE="${SAN_VALUE},DNS:${LB_HOSTNAME}"
  fi

  openssl req -new -key "${KEY_FILE}" -out "${CSR_FILE}" \
    -subj "/CN=${host}.${CLUSTER_DOMAIN}" \
    -addext "subjectAltName = ${SAN_VALUE}"

  openssl x509 -req -in "${CSR_FILE}" \
    -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
    -out "${CRT_FILE}" -days "${CERT_DAYS}" -sha256 \
    -extfile "${EXT_FILE}"
done

echo "==> Certificates written under ${CERT_DIR}"
