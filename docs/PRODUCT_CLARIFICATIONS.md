# Product Clarifications

Product behaviour that is not yet defined. Per [ENGINEERING_RULES.md](ENGINEERING_RULES.md)
§0, each item stops **only** the behaviour it describes. All other work continues.

Database-structure questions live in [database/ERD_GAPS.md](database/ERD_GAPS.md).

Status values: `OPEN` · `RESOLVED (date, decision)` · `WITHDRAWN (reason)`

---

## PRODUCT-CLARIFY-OFFLINE: Offline registration semantics
Status: `OPEN`

**Affects:** final offline-capable registration in Employee Mobile (§41) and Jitan
Terminal (§26–§27).

**Does not block:** backend, Employee Web, HR/Admin Web, foundation work, or online-only
mobile/terminal flows.

To define before offline registration is implemented:

- what can be queued (geofence arrival/departure? terminal QR scans? manual corrections?)
- what cannot be queued (e.g. anything needing a server decision first)
- which timestamp is authoritative: device clock at the event, or server receipt (and how
  device clock drift is handled)
- retry behaviour (backoff, maximum age of a queued event)
- duplicate prevention (same scan sent twice, same geofence transition from two sources)
- conflict handling (queued event contradicts what the server already has, e.g. an HR
  correction made while the device was offline)
- UI pending state (how the employee or terminal user sees "recorded, not yet confirmed")
- server reconciliation (what the server does with a late event that changes an already
  calculated day)

Related: [ENGINEERING_RULES.md](ENGINEERING_RULES.md) §21 (no fake success) and §26
(offline behaviour must be explicit).

---

## PRODUCT-CLARIFY-COMPANY-LIST: What the company list columns count
Status: `OPEN` · implemented with the interpretation below, easy to change

**Affects:** HR/Admin Companies list (Figma `153:35` / `153:804`), columns "Employees" and
"Last updated".

Current interpretation (in `CompanyRepository.listCompanies`):

- **Employees** = users with a `tblUserCompany` membership in the company and
  `userMFD = 0`. This **includes inactive users** and **includes HR/Admin users** who are
  members. Should it count only active users? Only users whose credential group is
  "Employee"?
- **Last updated** = the latest `tblEventLog.eventLogTimestamp` whose `companyID` is the
  company, or "—" when there is none. Should every event referencing the company count
  (e.g. an employee being added), or only changes to the company record itself? The
  displayed day also depends on the timezone of `eventLogTimestamp` (ERD GAP-02).
