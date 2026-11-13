# Jitan: installing the first test release

For IT. This release puts the Jitan API and the HR website on your server
`agapp05` (`https://10.1.101.65:8080`), connected to the development database
`jitandev`, and the employee app on a test tablet. It follows the configuration we
agreed on 2026-10-16 ([DEPLOYMENT_CONFIGURATION.md](DEPLOYMENT_CONFIGURATION.md)).

## What you receive

| File | What it is |
|---|---|
| `jitan-server` | The API, Linux x64. The HR website is built into it: same address, one file to update. |
| `set_first_password` | One-time tool for the first HR person, Linux x64. |
| `jitan-employee.apk` | The employee app for the tablet. It talks to `https://10.1.101.65:8080`. |
| `SHA256SUMS` | Check that the files arrived intact: `sha256sum -c SHA256SUMS`. |

## 1. Settings

Keep `/etc/jitan/app.env` as it is (`BIND_ADDRESS`, `PORT`, `TLS_CERT`, `TLS_KEY`,
`DB_*`) and add:

```ini
JITAN_ENV=production
# At least 32 random characters; keep it secret. Changing it signs everyone out.
JITAN_SESSION_SECRET=<output of: openssl rand -base64 48>
# Both SHA-256 fingerprints of the database's TLS certificates, comma-separated
# (see below). The API refuses a database it can't verify.
JITAN_DB_TLS_FINGERPRINTS=<CA fingerprint>,<server certificate fingerprint>
# Optional: driving distances for trips (a Mapbox token without URL restrictions).
JITAN_MAPBOX_TOKEN=<pk.…>
```

The fingerprints, on the database server `10.1.101.64`:

```sh
sudo openssl x509 -in /var/lib/mysql/ca.pem          -noout -fingerprint -sha256
sudo openssl x509 -in /var/lib/mysql/server-cert.pem -noout -fingerprint -sha256
```

We already have the server certificate's (`70:26:23:E5:…:85:B9`); please send us the
CA's too, so we can confirm both.

## 2. Install the executable

The same routine as every later update: stop the service, keep the previous
executable as a backup, put `jitan-server` at the existing path with its owner and
execute permission, start the service. `/etc/jitan/app.env` and the certificates stay
untouched.

## 3. Check

```sh
curl https://10.1.101.65:8080/health/ready
# {"status":"ok","database":"reachable"}
```

Then open `https://10.1.101.65:8080/` in a browser: the Jitan sign-in page.

If the service doesn't start, its log names the missing or wrong setting (never
its value).

## 4. The first HR person

Nobody can sign in yet. For the first HR person (see "Giving HR access" in
DEPLOYMENT_CONFIGURATION.md):

1. Their `tblUser` row with their employee code, `userPassword` empty.
2. HR access: `tblAppModulesCredGroup` (once per group) and their `tblUserCredGroup` row.
3. On the server, with the same `/etc/jitan/app.env`:
   `./set_first_password <employee code>`, then type a password when asked.

They then sign in on the HR website, and everyone else is set up from there.

## 5. The tablet

Install `jitan-employee.apk`. The tablet needs to reach `10.1.101.65:8080` and to
trust the server's HTTPS certificate:

- The certificate must name `10.1.101.65` (an IP entry in its Subject Alternative
  Name), because the app connects to that address.
- Android apps trust only public certificate authorities. If `agapp05.crt` comes from
  your own CA, send us that CA's certificate (the public part only), and we build the
  app again to trust it.

An employee is set up from the HR website (Employees → the employee → onboarding QR),
and scans that QR in the app with the tablet's camera.

## What Jitan writes in `jitandev`

From this release on, Jitan writes to the database: employees, time registrations,
group and schedule changes, and an audit row in `tblEventLog` for each change. On first
use it also adds the names it needs to six fixed lists (`tblTimeRegType`,
`tblScheduleType`, `tblDays`, `tblLocationType`, `tblDeviceType`, `tblEventType`). It
never changes the database structure and never deletes rows. Test records are named
`[DEV] …`.

## Questions for you

1. The CA fingerprint of the database (step 1).
2. Does `agapp05.crt` name `10.1.101.65`, and who issued it (step 5)?
3. Can phones reach `10.1.101.65:8080` from the office Wi-Fi? And later from outside
   the office, for employees on mobile data?
4. Who is the first HR person (step 4)?
