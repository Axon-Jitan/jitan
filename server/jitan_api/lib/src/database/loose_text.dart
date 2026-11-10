/// Put after a column to compare it ignoring capitals and accents, whatever
/// the column's own collation (CLARIFY-16): IT's database is
/// `utf8mb4_0900_as_cs`, so `SBW` ≠ `sbw` and `René` ≠ `Rene` there.
/// Fixed SQL text; the value it is compared with stays a bound parameter.
const ignoringCaseAndAccents = 'COLLATE utf8mb4_0900_ai_ci';
