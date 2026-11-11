import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('a project report goes to JSON and back unchanged', () {
    const report = ProjectReport(
      month: '2026-10',
      projects: [
        ProjectReportProject(
          project: ProjectSummary(
            id: 3,
            sapNumber: 'P-1042',
            name: 'Office refurbishment',
            isClientSite: true,
            isActive: true,
            placeName: 'Mouscron',
          ),
          workedMinutes: 600,
          travelMinutes: 50,
          trips: 2,
          distanceMetres: 36400,
          tripsWithoutDistance: 1,
          employees: [
            ProjectReportEmployee(
              employeeId: 7,
              firstName: 'Hanne',
              lastName: 'Claes',
              code: 'CLH',
              days: 2,
              workedMinutes: 600,
              travelMinutes: 50,
              trips: 2,
            ),
          ],
        ),
      ],
    );

    final back = ProjectReport.fromJson(report.toJson());

    expect(back.month, '2026-10');
    final project = back.projects.single;
    expect((project.project.fullName, project.project.placeName), ('P-1042 Office refurbishment', 'Mouscron'));
    expect((project.workedMinutes, project.travelMinutes, project.trips), (600, 50, 2));
    expect((project.distanceMetres, project.tripsWithoutDistance), (36400, 1));
    final employee = project.employees.single;
    expect((employee.code, employee.days, employee.workedMinutes, employee.travelMinutes, employee.trips), ('CLH', 2, 600, 50, 2));
  });

  test('a missing field is refused', () {
    expect(() => ProjectReport.fromJson({'month': '2026-10'}), throwsFormatException);
  });
}
