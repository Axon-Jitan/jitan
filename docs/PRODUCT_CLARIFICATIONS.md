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

---

## PRODUCT-CLARIFY-EMPLOYEES-LIST: Company context and the Type/Policy columns
Status: `OPEN` · **blocks the Employees list slice** (Figma `Admin / Employees` `153:137`)

1. **How is "the selected company" chosen?** The page reads "Manage employees for the
   selected company", but the frame has no company selector, and the Companies list rows
   are not clickable in Figma. The app must not silently pick a company
   (ENGINEERING_RULES §20). Options: a company selector on the page, clickable company
   rows leading to that company's employees, or a global company switcher. Whichever is
   chosen should be added to Figma.
2. **Type when a user has several groups.** `tblUserGroup` allows more than one group per
   user. Show all of them, or is exactly one Blue/White collar group expected (and
   several a data error)?
3. **What is "Policy" (Office / Field)?** There is no policy table. Candidates and why
   none fits cleanly:
   - `tblGroup`: already used for Type (Blue/White collar), and nothing distinguishes a
     "type" group from a "policy" group.
   - `tblScheduleType`: describes periods (Work/Break/Lunch/Travel), not employees.
   - `tblFunction`: per-user capabilities, not a working pattern.

   Which ERD concept is "Office"/"Field"? If none, this is an ERD gap.

Also blocked for this page: **Location** (ERD GAP-11) and **Onboarding** (ERD GAP-04).
