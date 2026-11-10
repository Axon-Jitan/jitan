import 'json_reading.dart';
import 'location.dart';

/// A project as HR sees it (D43, D44, Figma `1512:2`): a `tblAddress` row of
/// the kind "Project location", named `<SAP number> <name>`. A client site
/// has its own address, pin and area; an internal project sits at one of the
/// workshops and has no area of its own. Its id is the address's.
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.sapNumber,
    required this.name,
    required this.isClientSite,
    required this.isActive,
    this.placeName,
    this.lastUsed,
  });

  factory ProjectSummary.fromJson(Map<String, Object?> json) => ProjectSummary(
    id: json.readInt('id'),
    sapNumber: json.readString('sapNumber'),
    name: json.readString('name'),
    isClientSite: json.readBool('isClientSite'),
    isActive: json.readBool('isActive'),
    placeName: json.readOptionalString('placeName'),
    lastUsed: json.readOptionalDateTime('lastUsed')?.toUtc(),
  );

  final int id;
  final String sapNumber;
  final String name;

  /// A client site; `false` for an internal project at a workshop.
  final bool isClientSite;
  final bool isActive;

  /// The client site's town, or the workshop's name.
  final String? placeName;

  /// The last registration made for it.
  final DateTime? lastUsed;

  /// "P-1042 Office refurbishment", as stored.
  String get fullName => ProjectRequest.fullName(sapNumber, name);

  Map<String, Object?> toJson() => {
    'id': id,
    'sapNumber': sapNumber,
    'name': name,
    'isClientSite': isClientSite,
    'isActive': isActive,
    'placeName': placeName,
    'lastUsed': lastUsed?.toUtc().toIso8601String(),
  };
}

/// `GET /projects`.
class ProjectListResponse {
  const ProjectListResponse({required this.projects});

  factory ProjectListResponse.fromJson(Map<String, Object?> json) =>
      ProjectListResponse(projects: json.readObjectList('projects').map(ProjectSummary.fromJson).toList());

  final List<ProjectSummary> projects;

  Map<String, Object?> toJson() => {
    'projects': [for (final p in projects) p.toJson()],
  };
}

/// One project with what its form shows: the client site's address, pin and
/// area, or the workshop it sits at.
class ProjectDetails {
  const ProjectDetails({required this.summary, this.site, this.workshopId});

  factory ProjectDetails.fromJson(Map<String, Object?> json) => ProjectDetails(
    summary: ProjectSummary.fromJson(json),
    site: json['site'] == null ? null : Location.fromJson(json.readObject('site')),
    workshopId: json.readOptionalInt('workshopId'),
  );

  final ProjectSummary summary;

  /// A client site; `null` for an internal project.
  final Location? site;

  /// The workshop of an internal project, when it can still be told.
  final int? workshopId;

  Map<String, Object?> toJson() => {...summary.toJson(), 'site': site?.toJson(), 'workshopId': workshopId};
}

/// Body of adding or changing a project (Figma `1512:114`, `1512:305`):
/// either a client [site] (its name is ignored) or a [workshopId].
class ProjectRequest {
  const ProjectRequest({required this.sapNumber, required this.name, this.site, this.workshopId});

  factory ProjectRequest.fromJson(Map<String, Object?> json) => ProjectRequest(
    sapNumber: json.readString(fieldSapNumber),
    name: json.readString(fieldName),
    site: json['site'] == null ? null : LocationRequest.fromJson(json.readObject('site')),
    workshopId: json.readOptionalInt(fieldWorkshop),
  );

  static const fieldSapNumber = 'sapNumber';
  static const fieldName = 'name';
  static const fieldWorkshop = 'workshopId';

  /// `tblAddress.addressLogicalName` holds both, so together at most this.
  static const maxFullNameLength = 100;
  static const maxSapNumberLength = 20;

  final String sapNumber;
  final String name;
  final LocationRequest? site;
  final int? workshopId;

  /// The SAP number first, so the link to SAP survives a rename there (D44).
  static String fullName(String sapNumber, String name) => '$sapNumber $name';

  /// Splits a stored name back into its SAP number and name.
  static (String sapNumber, String name) split(String fullName) {
    final space = fullName.indexOf(' ');
    return space < 0 ? (fullName, '') : (fullName.substring(0, space), fullName.substring(space + 1));
  }

  ProjectRequest trimmed() => ProjectRequest(sapNumber: sapNumber.trim(), name: name.trim(), site: site, workshopId: workshopId);

  Map<String, Object?> toJson() => {
    fieldSapNumber: sapNumber,
    fieldName: name,
    'site': site?.toJson(),
    fieldWorkshop: workshopId,
  };
}
