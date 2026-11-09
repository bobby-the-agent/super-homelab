# Run a script on inventory machines

Keep this simple: paste reviewed commands into a Bash script in this directory,
then let Ansible copy and execute it on the selected machines.

From `ansible-k8s/`, preview the targets:

```bash
ansible-playbook -i inventory.ini playbook/run_script.yaml \
  --limit master -e script=install_etcdctl.sh --list-hosts
```

Test on one server, then run on the three control-plane servers:

```bash
ansible-playbook -i inventory.ini playbook/run_script.yaml \
  --limit ahoy1 -e script=install_etcdctl.sh

ansible-playbook -i inventory.ini playbook/run_script.yaml \
  --limit master -e script=install_etcdctl.sh

ansible master -i inventory.ini -b -m ansible.builtin.command \
  -a '/usr/local/bin/etcdctl version'
```

The runner targets all inventory machines unless narrowed with `--limit`.
Always specify `--limit` deliberately. Commands run as root, in parallel by default.
Only filenames ending in `.sh` are accepted, not paths or command-line arguments.
If sudo requires a password, add `--ask-become-pass`.

## Add another installation

Create `scripts/install_example.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Paste installation commands here; make them safe to repeat.
apt-get update
apt-get install -y jq
```

Run it with the same playbook, changing only `-e script=install_example.sh`.
No executable bit is required: the runner explicitly invokes Bash.

## Included etcdctl installer

- Pins upstream etcdctl v3.7.3 for Linux ARM64; other architectures fail safely.
- Verifies the archive against a pinned SHA-256 before extraction.
- Installs only `/usr/local/bin/etcdctl`, not an etcd server or service.
- Skips an already-installed matching client version. Replaces a different version.
- Requires curl, sha256sum, tar, install, and mktemp on the target.
- Does not restart K3s or change cluster membership.

Installation method: [official v3.7 prebuilt binary instructions](https://etcd.io/docs/v3.7/install/).
No Go compiler or source build is required. This updates the client only, not
K3s's embedded etcd server. Client/server compatibility must be verified against
the actual cluster before relying on upgrade health gates; this installer does
not perform that check.

Source: https://github.com/etcd-io/etcd/releases/tag/v3.7.3
Checksum: https://github.com/etcd-io/etcd/releases/download/v3.7.3/SHA256SUMS

## Limitations and safety

Scripts execute on every invocation unless they contain their own skip logic.
Ansible reports the script task as changed even if the script skips installation.
`--check` is not a meaningful test of arbitrary shell scripts; inspect the script
and test on a suitable machine instead. Do not store credentials in scripts.
Pin versions and verify checksums for downloaded executables; avoid piping mutable
remote installers into a root shell.

Use the dedicated rolling-upgrade playbook for K3s upgrades. This generic runner
has no quorum checks or rolling restart safeguards.
