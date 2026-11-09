#!/usr/bin/env bash
set -euo pipefail

# Install only the client. Never install/start an etcd server or restart K3s.
version='v3.6.7'
archive="etcd-${version}-linux-arm64.tar.gz"
sha256='ef5fc443cf7cc5b82738f3c28363704896551900af90a6d622cae740b5644270'
target='/usr/local/bin/etcdctl'

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) printf 'This installer supports Linux ARM64 only.\n' >&2; exit 1 ;;
esac
[[ "$(uname -s)" == Linux ]] || { printf 'Linux is required.\n' >&2; exit 1; }
[[ "$EUID" -eq 0 ]] || { printf 'Run as root (Ansible become).\n' >&2; exit 1; }

if [[ -x "$target" ]] && "$target" version | grep -Fxq "etcdctl version: ${version#v}"; then
  printf 'etcdctl %s is already installed.\n' "$version"
  exit 0
fi

for command in curl sha256sum tar install mktemp; do
  command -v "$command" >/dev/null || { printf 'Missing prerequisite: %s\n' "$command" >&2; exit 1; }
done

stage=$(mktemp -d /var/tmp/install-etcdctl.XXXXXXXX)
trap 'rm -rf -- "$stage"' EXIT
curl --fail --location --silent --show-error --retry 3 \
  --connect-timeout 15 --max-time 300 \
  "https://github.com/etcd-io/etcd/releases/download/${version}/${archive}" \
  --output "$stage/$archive"
(
  cd "$stage"
  printf '%s  %s\n' "$sha256" "$archive" | sha256sum --check --strict -
)
# Extract only the required client after verifying the entire archive.
tar -xzf "$stage/$archive" -C "$stage" --no-same-owner \
  "etcd-${version}-linux-arm64/etcdctl"
install -o root -g root -m 0755 \
  "$stage/etcd-${version}-linux-arm64/etcdctl" "$target"
"$target" version
