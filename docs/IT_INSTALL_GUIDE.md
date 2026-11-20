# Jitan 0.0.1: installing the first test release

For IT. This release puts the Jitan API and the HR website on your server
`agapp05` (`https://10.1.101.65:8080`), connected to the development database
`jitandev`, and the employee app on a test tablet. It follows the configuration we
agreed on 2026-10-16 ([DEPLOYMENT_CONFIGURATION.md](DEPLOYMENT_CONFIGURATION.md)).

## What you receive

For the existing IT server, extract the complete `jitan-0.0.1.zip`, open a
terminal in the extracted folder, and run `sudo sh install.sh`. This restores
both executables even if they were deleted, restarts the existing `jitan`
service, and starts first-HR setup. The service definition, `svc.dart` account,
`/etc/jitan/app.env` and certificates must still exist. The installer preserves
them. Ensure `DB_PASS` in that configuration contains the updated password.
The ZIP contains no database password. Keep the extracted folder outside
`/opt/jitan` so installation can back up any existing executables.

| File | What it is |
|---|---|
| `jitan-server` | The API, Linux x64. The HR website is built into it: same address, one file to update. |
| `jitan-first-hr` | Sets up the first HR person in one step, Linux x64. |
| `jitan-employee.apk` | The employee app for the tablet. It talks to `https://10.1.101.65:8080`. |
| `SHA256SUMS` | Check that the files arrived intact: `sha256sum -c SHA256SUMS`. |
| `install.sh` | Restores both executables and starts HR setup using the existing IT service. |

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

The working chain identified on 18 November uses server fingerprint
`70:26:23:E5:D0:AE:AA:B2:9B:51:AA:5B:C2:85:51:FF:FD:C3:8A:BD:E1:04:32:0F:4F:6B:D2:BE:08:E3:85:B9`
and CA fingerprint
`BF:A7:1D:DC:14:34:7D:FC:D3:BE:FE:E0:CD:CD:0B:E2:14:DC:75:AD:B1:A4:EE:B6:57:97:84:BD:68:40:B0:95`.
Preserve IT's verified working TLS configuration. If certificates are replaced,
confirm their identity with IT before changing trust settings.

Two more things about the setup:

- **Database mode:** MySQL's `sql_mode` for Jitan's account must not contain
  `NO_BACKSLASH_ESCAPES`. Jitan refuses to start with it, and `/health/ready` says so.
  Check it with `SELECT @@GLOBAL.sql_mode;`.
- **One process:** run a single `jitan-server` (one service, no load balancing over
  copies). Temporary QR codes and the sign-in limit are kept in its memory.

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

Use the updated `jitan-first-hr` (2026-11-18). On the server, with the HR person
beside you, run:

```sh
cd /opt/jitan
chmod +x jitan-first-hr
sudo -u svc.dart ./jitan-first-hr
```

On an empty database it creates the initial **HR** access group and **Employees**
module automatically, together with the employee, their access links and password.
Only the employee code, first name, last name and password are requested. No manual
SQL is needed. Existing access tables are not reset: when active choices exist,
select them as in this example:

```text
$ ./jitan-first-hr
Employee code: SBW
New employee.
First name: Disan
Last name: Ssebowa
Access group:
  1) Admin
  2) HR
Choose 1-2: 2
Now the HR person types their password (it is not shown).
Password (at least 8 characters): ********
Again: ********
Done. SBW can now sign in on the HR website.
```

It uses the same `/etc/jitan/app.env` as the server. In one step it adds the employee
(or uses their row if the code is already in `tblUser`), puts them in the access group,
links that group to a module if it opens none yet (it then asks which one), and sets the
password. Everything happens together or not at all, and each step is in the audit log.
The groups and modules it lists are your rows in `tblCredGroup` and `tblAppModules`.
Only completely empty access tables receive initial rows; inactive or removed
policies are never silently reactivated. The initial group uses the database's
default level; permissions still follow its module links, not its name or level.
Cancelling, invalid input or a failed transaction leaves no partial setup.
It refuses an account that already has a password.

They then sign in on the HR website, and everyone else is set up from there.

## 5. The tablet

Install `jitan-employee.apk`. The tablet needs to reach `10.1.101.65:8080`.

Your certificate `agapp05` is self-signed and names `10.1.101.65`, so the app is built
to accept exactly that certificate, from that address only (SHA-256
`B6:CB:0A:74:75:BF:EA:46:21:B7:15:68:F9:32:86:BA:69:F8:78:CB:7B:09:7D:E7:04:EB:2B:A2:F8:83:BF:C4`;
please confirm it is yours: `openssl x509 -in /etc/jitan/tls/agapp05.crt -noout
-fingerprint -sha256`). **If you replace the certificate, tell us first**: the app needs
a new build, or it will refuse the server.

Browsers will warn about the self-signed certificate on the HR website until the
certificate is trusted on the HR computers (for example pushed to them by policy).

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
2. Is `B6:CB:0A:74:…:83:BF:C4` the fingerprint of your `agapp05.crt` (step 5)?
3. Can phones reach `10.1.101.65:8080` from the office Wi-Fi? And later from outside
   the office, for employees on mobile data?
4. Who is the first HR person (step 4)? The updated tool creates the initial access
   group and module when their tables are empty.
