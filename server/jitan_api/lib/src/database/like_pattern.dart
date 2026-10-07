/// A `LIKE '%…%'` pattern that matches [text] literally: MySQL's default
/// escape character `\` is used for `\`, `%` and `_`.
String containsLikePattern(String text) =>
    '%${text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
