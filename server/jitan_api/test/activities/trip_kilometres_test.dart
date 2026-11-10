import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/trip_kilometres.dart';
import 'package:test/test.dart';

const _almeco = 1, _client = 2;

/// An activity row; [address] is its place or project (D44).
ActivityRow _row(String type, {int? address, int minute = 0}) =>
    (id: minute, typeName: '${ActivityRepository.typePrefix}$type', at: DateTime.utc(2026, 11, 2, 8, minute), addressId: address);

void main() {
  test('D25: to the client and back are two trips', () {
    final trips = TripKilometres.tripsOf([
      _row('Work', address: _almeco),
      _row('Transport', address: _almeco),
      _row('Client on site', address: _client),
      _row('Transport', address: _client),
      _row('Work', address: _almeco),
    ]);

    expect(trips, [(from: _almeco, to: _client), (from: _client, to: _almeco)]);
  });

  test('a switch by hand: the places come from the activities around it (a client project is its site)', () {
    final trips = TripKilometres.tripsOf([_row('Work', address: _almeco), _row('Transport'), _row('Client on site', address: _client)]);

    expect(trips, [(from: _almeco, to: _client)]);
  });

  test('two transports in a row are one trip', () {
    final trips = TripKilometres.tripsOf([
      _row('Work', address: _almeco),
      _row('Transport'),
      _row('Transport'),
      _row('Client on site', address: _client),
    ]);

    expect(trips, [(from: _almeco, to: _client)]);
  });

  test('the day ends on the way: where it arrives is not known', () {
    expect(TripKilometres.tripsOf([_row('Client on site', address: _client), _row('Transport', address: _client)]), [
      (from: _client, to: null),
    ]);
  });

  test('out and back to one place: where they went is not known', () {
    expect(
      TripKilometres.tripsOf([_row('Client on site', address: _client), _row('Transport'), _row('Client on site', address: _client)]),
      [(from: _client, to: null)],
    );
  });

  test('nothing says where it left from: no guess', () {
    expect(TripKilometres.tripsOf([_row('Transport'), _row('Client on site', address: _client)]), [(from: null, to: _client)]);
  });

  test('no transport, no trip', () {
    expect(TripKilometres.tripsOf([_row('Work', address: _almeco)]), isEmpty);
  });
}
