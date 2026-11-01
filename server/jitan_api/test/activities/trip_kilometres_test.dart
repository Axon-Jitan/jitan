import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/trip_kilometres.dart';
import 'package:test/test.dart';

const _almeco = 1, _client = 2, _other = 3;

ActivityRow _row(String type, {int? address, int? projectAddress, int minute = 0}) => (
  id: minute,
  typeName: '${ActivityRepository.typePrefix}$type',
  at: DateTime.utc(2026, 11, 2, 8, minute),
  projectId: null,
  companyId: null,
  addressId: address,
  projectAddressId: projectAddress,
);

void main() {
  test('D25: to the client and back are two trips', () {
    final trips = TripKilometres.tripsOf([
      _row('Work', address: _almeco),
      _row('Transport', address: _almeco, projectAddress: _client),
      _row('Client on site', address: _client, projectAddress: _client),
      _row('Transport', address: _client, projectAddress: _client),
      _row('Work', address: _almeco),
    ]);

    expect(trips, [(from: _almeco, to: _client), (from: _client, to: _almeco)]);
  });

  test('a switch by hand: the places come from the activities around it', () {
    final trips = TripKilometres.tripsOf([
      _row('Work', address: _almeco),
      _row('Transport'),
      _row('Client on site', projectAddress: _client),
    ]);

    expect(trips, [(from: _almeco, to: _client)]);
  });

  test('two transports in a row are one trip', () {
    final trips = TripKilometres.tripsOf([
      _row('Work', address: _almeco),
      _row('Transport'),
      _row('Transport', projectAddress: _other),
      _row('Client on site', projectAddress: _client),
    ]);

    expect(trips, [(from: _almeco, to: _client)]);
  });

  test('the day ends on Transport: it arrives at the project it was for', () {
    expect(TripKilometres.tripsOf([_row('Work', address: _almeco), _row('Transport', projectAddress: _client)]), [
      (from: _almeco, to: _client),
    ]);
  });

  test('the day ends on the way back: where it arrives is not known', () {
    expect(
      TripKilometres.tripsOf([
        _row('Client on site', address: _client, projectAddress: _client),
        _row('Transport', address: _client, projectAddress: _client),
      ]),
      [(from: _client, to: null)],
    );
  });

  test('out and back to one place by hand: where they went is not known', () {
    expect(
      TripKilometres.tripsOf([
        _row('Client on site', projectAddress: _client),
        _row('Transport', projectAddress: _client),
        _row('Client on site', projectAddress: _client),
      ]),
      [(from: _client, to: null)],
    );
  });

  test('nothing says where it left from: no guess', () {
    expect(TripKilometres.tripsOf([_row('Transport'), _row('Client on site', projectAddress: _client)]), [
      (from: null, to: _client),
    ]);
  });

  test('no transport, no trip', () {
    expect(TripKilometres.tripsOf([_row('Work', address: _almeco)]), isEmpty);
  });
}
