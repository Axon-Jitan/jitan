import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('a group overview round-trips', () {
    const list = GroupOverviewListResponse(groups: [
      GroupOverview(id: 5, name: 'Drivers', isActive: false, employeeCount: 0),
    ]);

    final back = GroupOverviewListResponse.fromJson(list.toJson()).groups.single;

    expect((back.id, back.name, back.isActive, back.employeeCount), (5, 'Drivers', false, 0));
  });

  test('the group name request carries the column limit', () {
    expect(GroupNameRequest.fromJson(const GroupNameRequest(name: 'Drivers').toJson()).name, 'Drivers');
    expect(GroupNameRequest.maxNameLength, 100);
  });
}
