# Import employees: sample files

Development data for testing **Employees → Import CSV / Excel** (local or dev
database only). Names start with `[DEV]`, codes with `DEVIMP`.

| File | What it shows |
|---|---|
| `employees-ready.xlsx` / `.csv` | 10 employees, all ready. The CSV uses `;` (Belgian Excel); phones from several countries, one with two groups, one with nothing optional |
| `employees-with-problems.xlsx` / `.csv` | 3 ready rows, then one row per problem: last name missing, code missing, code already used (`SBW`), code repeated in the file, unknown group (`Cleaners`), phone without `+` code, phone with letters, impossible phone, invalid email. The CSV uses `,` |
| `employees-missing-column.csv` | No "Employee code" column: the file can't be used |

Groups used: `Blue collar`, `White collar` (they must exist).

A code can be imported once. To import the same rows again, write new files
with another code prefix:

```sh
python -I dev/import-samples/make_samples.py DEVIMP2
```

`apps/admin_web/test/employees/import/employee_import_file_test.dart` reads
these files, so a change to them must keep that test passing.
