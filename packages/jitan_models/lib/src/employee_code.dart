/// Employee codes (`tblUser.userCode`) as Jitan stores them: trimmed and in
/// capitals, so `sbw` and `SBW` are one code whatever the database's
/// collation (CLARIFY-16). The server applies it; a form may too, to show it.
abstract final class EmployeeCodes {
  static String normalize(String code) => code.trim().toUpperCase();
}
