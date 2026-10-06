#!/usr/bin/env bash
# .codemender/scripts/install.sh
# Installs the official Google CodeMender (cm) CLI, initializes ~/.codemender,
# and configures repository pre-commit hooks.
set -euo pipefail

chmod +x .codemender/scripts/pre-commit
git config core.hooksPath .codemender/scripts

if ! command -v cm >/dev/null 2>&1; then
  echo "==> Downloading official Google CodeMender ('cm') CLI from Artifact Registry..."
  OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH_NAME=$(uname -m)
  if [ "${ARCH_NAME}" = "x86_64" ]; then
    ARCH_NAME="amd64"
  elif [ "${ARCH_NAME}" = "aarch64" ] || [ "${ARCH_NAME}" = "arm64" ]; then
    ARCH_NAME="arm64"
  fi
  PACKAGE_FILE="cm-${OS_NAME}-${ARCH_NAME}.zip"

  gcloud artifacts generic download \
    --project=cmoc-prod \
    --location=us \
    --repository=codemender-cli-production \
    --package=cm \
    --version=stable \
    --name="${PACKAGE_FILE}" \
    --destination=/tmp/

  python3 -m zipfile -e "/tmp/${PACKAGE_FILE}" /tmp/
  chmod +x /tmp/cm
  sudo mv /tmp/cm /usr/local/bin/cm
  rm -f "/tmp/${PACKAGE_FILE}"
fi

cm init -y >/dev/null 2>&1 || true
cp .codemender/config.yaml "${HOME}/.codemender/config.yaml"
echo "✅ CodeMender ($(cm --version 2>/dev/null || echo 'cm')) and pre-commit hooks installed."
