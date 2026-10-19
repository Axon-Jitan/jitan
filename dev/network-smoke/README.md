# Jitan - Network Test 0.1.2

Linux x64 executable displaying **Hello jitan!!**.

Reads `/etc/jitan/app.env` at startup. Keep IT's existing file:

```ini
BIND_ADDRESS=10.1.101.65
HOST=10.1.101.65
PORT=8080
TLS_CERT=/etc/jitan/tls/agapp05.crt
TLS_KEY=/etc/jitan/tls/agapp05.key
```

`BIND_ADDRESS` takes priority over `HOST`. A specific IPv4 address also opens
127.0.0.1 on the same port. `0.0.0.0` listens on all IPv4 interfaces.
With both TLS paths set, the port serves **HTTPS**, not HTTP. Both paths must
contain readable PEM files with a matching, unencrypted private key.

**Update the existing service:** stop it, replace its `jitan-server` with
`bin/jitan-server` from this archive, then start it. Do not overwrite IT's config
or certificates. The service account must be able to read the config and TLS
files. The included systemd unit is an optional example; retain IT's paths/user.

```bash
sudo systemctl restart jitan
sudo journalctl -u jitan -n 20 --no-pager
```

Open **https://10.1.101.65:8080/** or use the hostname covered by IT's certificate.
Health check: `/health/live`. Clients must trust the certificate issuer.

IP, port and certificate changes require a restart, not a rebuild.

**Configuration:** `JITAN_CONFIG_FILE` selects a different config path.
Environment variables override file settings; remove obsolete service overrides.
Legacy `JITAN_HTTP_HOST` / `JITAN_HTTP_PORT` remain supported. Without TLS settings,
the server uses HTTP. Invalid/partial TLS settings stop startup. Existing `DB_*`
entries are ignored by this network-test application.
