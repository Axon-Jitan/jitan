# Deployment configuration agreement

Recorded 2026-10-16 from IT's configuration request and the project owner's decision
to keep the same convention for the full Jitan application.

## Target and scope

- Ubuntu 26.04, Linux x64, hosted on Hyper-V; standalone executable under systemd.
- Server configuration: `/etc/jitan/app.env`, outside release packages.
- Address, port and certificate changes take effect after restart, without rebuilding.
- Preserve IT's configuration and certificates when replacing application releases.

This contract is server-side. Browser, mobile and terminal clients connect to the
backend HTTPS URL. Never distribute this file, database credentials or TLS private
keys to clients or compiled web assets. Client `JITAN_API_BASE_URL` configuration
remains separate.

## Update method agreed 2026-10-16

IT wants later versions to replace the original `jitan-server` executable at its
existing installed path. Preserve the executable name, systemd service/ExecStart,
configuration path, supported setting names and certificate paths across releases.
Do not require IT to reinstall the service or recreate configuration for routine updates.

Routine update: stop the service, retain a backup of the previous executable, replace
it with the new Linux x64 executable, preserve ownership/execute permissions, start
the service, then verify HTTPS and health. Do not overwrite a running binary in place.
Keep `/etc/jitan/app.env`, secrets and certificates untouched. Rollback restores the
previous executable while the service is stopped, subject to database compatibility.

To retain executable-only replacement when the real web application is delivered,
embed its compiled assets in the executable. This remains implementation work; if
external assets are necessary, agree the expanded update procedure with IT first.
Any new required configuration or database changes must be documented before a
release; they cannot be assumed to happen through replacing a binary. No automatic
schema changes during startup.

The test validates hosting/configuration behavior. It does not guarantee that future
application features, database connections or authentication work: verify each release.

## IT configuration values

These are IT's current environment values, not hardcoded defaults. `jitandev` is
the supplied database name, not a confirmed future production database. The password
below is a placeholder only.

```ini
BIND_ADDRESS=10.1.101.65
HOST=10.1.101.65
PORT=8080
TLS_CERT=/etc/jitan/tls/agapp05.crt
TLS_KEY=/etc/jitan/tls/agapp05.key
DB_HOST=<configured-by-IT>
DB_PORT=3306
DB_USER=<configured-by-IT>
DB_PASS=<configured-by-IT>
DB_NAME=jitandev
```

## Listener and HTTPS contract

- Read `/etc/jitan/app.env` at startup; `JITAN_CONFIG_FILE` can select another file.
- Environment variables override file values. Within each source, address priority
  is `BIND_ADDRESS`, `HOST`, then legacy `JITAN_HTTP_HOST`; port priority is `PORT`,
  then legacy `JITAN_HTTP_PORT`. Remove stale service environment overrides.
- Bind to the specified IP (`localhost` is also accepted). A specific non-loopback
  IPv4 address also opens `127.0.0.1` on the same port. `0.0.0.0` already covers
  all IPv4 interfaces and must not create a duplicate localhost listener.
- Both TLS paths enable HTTPS on `PORT`. With IT's values, use
  `https://10.1.101.65:8080/` or the hostname covered by the certificate. Clients
  must trust its issuer and use a URL matching the certificate identity.
- Use a readable PEM certificate chain and matching unencrypted PEM private key.
  Partial, unreadable or invalid TLS settings must stop startup, with no HTTP
  fallback. The network test uses TLS 1.2 or later.
- With neither TLS setting, the test uses HTTP. For the full app, this is only for
  explicit development or an IT-managed HTTPS reverse proxy; IT's supplied setup
  uses direct HTTPS in the executable.
- Restart to apply configuration/certificate changes; there is no hot reload.
  The service account must be able to read the config and TLS files. Do not make
  private files world-readable or log passwords, private keys or config contents.

The test parser supports blank lines, full-line `#` comments, `KEY=value`, optional
`export` and matching single/double quotes. It performs no shell expansion or
execution. Malformed lines and duplicate keys are rejected.

## Database mapping for the full application

IT's names are used, and the existing development names still work (implemented
2026-10-20):

| IT setting | Existing backend setting |
|---|---|
| `DB_HOST` | `JITAN_DB_HOST` |
| `DB_PORT` | `JITAN_DB_PORT` |
| `DB_USER` | `JITAN_DB_USER` |
| `DB_PASS` | `JITAN_DB_PASSWORD` |
| `DB_NAME` | `JITAN_DB_NAME` |

Use environment before file values and IT names before legacy aliases within each
source, consistently with listener settings.

`TLS_CERT`/`TLS_KEY` configure inbound HTTPS, not MySQL certificate verification.
The database connection has its own settings (SEC-01):

| Setting | Meaning |
|---|---|
| `JITAN_DB_SECURE` | TLS to MySQL, default `true`. `false` is refused in production. |
| `JITAN_DB_TLS_FINGERPRINTS` | SHA-256 fingerprints of the certificates MySQL presents, comma-separated, colons allowed. For MySQL's auto-generated certificates: the CA **and** the server certificate. |
| `JITAN_DB_TLS_CA_FILE` | Or: a PEM file of the CA that issued a certificate for the database's address. |

Production refuses to start without one of the two checks, or with both. Development
may connect unverified and logs a warning. When IT renews the database certificates,
the fingerprints change with them and must be updated in `/etc/jitan/app.env`.

The full application also needs `JITAN_SESSION_SECRET` (at least 32 characters) in
production, and refuses any `JITAN_DEV_*` setting there, from any source. IT's
supplied file is therefore not yet a complete production configuration: it still
needs the session secret and the database fingerprints.

## Implementation status as checked 2026-10-20

| Component | Status |
|---|---|
| Network-test 0.1.2 | File loading, listener aliases, dual IPv4 binding and HTTPS implemented. `DB_*` ignored; no database connection. |
| Linux verification | Ubuntu 26.04 x64 container with test certificates; HTTPS, configuration failures and restart tested. IT VM/certificates/systemd boot unverified here. |
| Full API (`server/jitan_api`) | 2026-10-20: reads `/etc/jitan/app.env` (or `JITAN_CONFIG_FILE`), IT's names, direct HTTPS (TLS 1.2+), dual IPv4 binding, SIGTERM shutdown, `/health/live` and `/health/ready`, verified MySQL TLS. Tested on Windows against the local MySQL; not yet on IT's VM. |
| Client apps | Connect via backend HTTPS URL; never read server config. |

Complete DEPLOY-01 in [BACKLOG.md](BACKLOG.md) before full application delivery,
alongside separately tracked authentication, permissions and database dependencies.
The network test does not establish full application readiness.

Reference: [config loader](../dev/network-smoke/server_config.dart),
[systemd example](../dev/network-smoke/jitan.service),
[configuration example](../dev/network-smoke/app.env.example).

## Giving HR access

In V1, IT decides who opens Jitan HR, in its own tables. Jitan has no screen for it, and HR and
Admin have the same rights, in every company.

1. **Once per credential group that may open HR:** add a row to `tblAppModulesCredGroup` linking
   that `tblCredGroup` row to an active `tblAppModules` row. Do not link the Employee group: a
   group with no module opens nothing.
2. **For each person:** add a row to `tblUserCredGroup` for their `userID` and that group, with
   `userCredGroupActive = 1` and `userCredGroupMFD = 0`.
3. They need a password: an HR person generates their onboarding QR, and they set it up in the
   employee app. The very first HR person has nobody to do that, see below.

To take access away, set `userCredGroupActive = 0`. It applies on their next click, no restart.

### The very first HR person

On a fresh database nobody can generate an onboarding QR yet.

1. Add the person to `tblUser` with their employee code. `userPassword` stays empty.
2. Give them access as above.
3. On the server, with the same configuration as the API, run the tool and type a password when
   asked. It is never taken from the command line:

   ```sh
   dart compile exe bin/set_first_password.dart -o set_first_password   # with the release
   ./set_first_password SBW
   ```

It only works for an active employee with no password, so it can't take over an account. It is
audited as `employee.password.first_set`. The person signs in, and everyone else onboards from
there. Ask them to change this password in the employee app.
