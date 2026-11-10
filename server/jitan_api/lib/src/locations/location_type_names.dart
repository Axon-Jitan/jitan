/// Names of the `tblLocationType` rows Jitan relies on. Rows are found by
/// name, never by ID; HR adds them on the Lists page.
abstract final class LocationTypeNames {
  /// A project's place (D44): a client site, or the workshop for an internal
  /// project.
  static const projectLocation = 'Project location';

  static const all = [projectLocation];
}
