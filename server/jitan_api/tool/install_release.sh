#!/bin/sh
# Install the complete package into IT's existing Jitan service.
set -eu
if [ "$(id -u)" -ne 0 ]; then
  echo "Run: sudo sh install.sh" >&2
  exit 1
fi
cd -- "$(dirname -- "$0")"
sha256sum -c SHA256SUMS
id svc.dart >/dev/null
sudo -u svc.dart test -r /etc/jitan/app.env || {
  echo "Restore /etc/jitan/app.env and allow svc.dart to read it first." >&2
  exit 1
}
systemctl cat jitan.service >/dev/null
install -d -m 0755 /opt/jitan
backup=$(mktemp -d /opt/jitan/backup.XXXXXX)
stage=$(mktemp -d /opt/jitan/update.XXXXXX)
trap 'rm -f -- "$stage/jitan-server" "$stage/jitan-first-hr"; rmdir -- "$stage"' EXIT
for name in jitan-server jitan-first-hr; do
  if [ -e "/opt/jitan/$name" ]; then
    cp -p -- "/opt/jitan/$name" "$backup/$name"
  fi
  install -m 0755 -- "$name" "$stage/$name"
done
systemctl stop jitan.service
for name in jitan-server jitan-first-hr; do
  mv -f -- "$stage/$name" "/opt/jitan/$name"
done
systemctl start jitan.service
sleep 2
if ! systemctl is-active --quiet jitan.service; then
  echo "Jitan did not stay running. Check: sudo journalctl -u jitan -n 50" >&2
  echo "Any previous executables are saved in $backup" >&2
  exit 1
fi
echo "Both executables installed. Existing configuration and certificates preserved."
echo "Service is running; database readiness still needs confirmation."
echo "Starting first HR setup. An existing account password will not be overwritten."
cd /opt/jitan
sudo -u svc.dart ./jitan-first-hr
