import 'json_reading.dart';

/// One row of the HR/Admin company list.
///
/// Sources (see docs/database/ERD.md):
/// - [id], [name], [isActive]: `tblCompany`
/// - [employeeCount]: `tblUserCompany` memberships of non-MFD users
/// - [lastUpdatedAt]: most recent `tblEventLog` entry referencing the company,
///   `null` when none exists. The value is the database wall-clock time;
///   its timezone is pending ERD GAP-02.
///
/// There is no location count: no company → address relationship exists
/// in the ERD (ERD GAP-03).
class CompanySummary {
  const CompanySummary({
    required this.id,
    required this.name,
    required this.isActive,
    required this.employeeCount,
    required this.lastUpdatedAt,
  });

  factory CompanySummary.fromJson(Map<String, Object?> json) => CompanySummary(
        id: json.readInt('id'),
        name: json.readString('name'),
        isActive: json.readBool('isActive'),
        employeeCount: json.readInt('employeeCount'),
        lastUpdatedAt: json.readOptionalDateTime('lastUpdatedAt'),
      );

  final int id;
  final String name;
  final bool isActive;
  final int employeeCount;
  final DateTime? lastUpdatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'isActive': isActive,
        'employeeCount': employeeCount,
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      };
}

/// Response body of `GET /companies`.
class CompanyListResponse {
  const CompanyListResponse({required this.companies});

  factory CompanyListResponse.fromJson(Map<String, Object?> json) => CompanyListResponse(
        companies: json.readObjectList('companies').map(CompanySummary.fromJson).toList(),
      );

  final List<CompanySummary> companies;

  Map<String, Object?> toJson() => {
        'companies': [for (final company in companies) company.toJson()],
      };
}
