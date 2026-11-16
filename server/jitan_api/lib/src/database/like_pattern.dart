/// A `LIKE '%…%'` pattern that matches [text] literally: `!`, `%` and `_`
/// are escaped with `!`. Use it with [likeEscape] after the `LIKE`.
///
/// Not MySQL's default escape `\`: the `NO_BACKSLASH_ESCAPES` SQL mode turns
/// that off, and a search for `%` would then match everything (review L13).
String containsLikePattern(String text) =>
    '%${text.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%';

/// Goes right after `LIKE :pattern` for a [containsLikePattern] value.
const likeEscape = "ESCAPE '!'";
