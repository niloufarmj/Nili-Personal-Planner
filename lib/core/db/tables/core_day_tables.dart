import 'package:drift/drift.dart';

import '../converters/json_map_converter.dart';
import '../converters/string_list_converter.dart';

/// Tags define day types. `kind`: location | activity | special | partner.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text()(); // hex
  TextColumn get kind =>
      text()(); // 'location' | 'activity' | 'special' | 'partner'
  TextColumn get owner => text().withDefault(const Constant('me'))();
}

/// Many-to-many: which tags apply to which dates.
class DayTags extends Table {
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get tagId => integer().references(Tags, #id)();
  TextColumn get source => text().withDefault(
    const Constant('manual'),
  )(); // 'manual'|'trip'|'recurrence'

  @override
  Set<Column<Object>> get primaryKey => {date, tagId};
}

/// Calendar events (social, appointments, repeating).
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get category =>
      text()(); // 'social'|'appointment'|'partner'|'uni'|'other'
  TextColumn get rrule => text().nullable()(); // iCal RRULE
  TextColumn get notes => text().nullable()();
  TextColumn get owner => text().withDefault(const Constant('me'))();
}

/// Trips: probable or final. Final → auto writes 'travel' day_tags.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get status => text()(); // 'probable'|'final'|'done'|'cancelled'
  TextColumn get startDate => text().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get links => text().nullable().map(
    const NullAwareTypeConverter.wrap(StringListConverter()),
  )();
  IntColumn get budgetCents => integer().nullable()();
  IntColumn get packingCollectionId => integer().nullable()();
  TextColumn get meta => text().nullable().map(
    const NullAwareTypeConverter.wrap(JsonMapConverter()),
  )();
}

/// Reminders with a validity window and priority.
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get windowStart => text()();
  TextColumn get windowEnd => text().nullable()();
  IntColumn get priority =>
      integer().withDefault(const Constant(2))(); // 1 high · 2 normal · 3 low
  TextColumn get notifyRule => text().nullable().map(
    const NullAwareTypeConverter.wrap(JsonMapConverter()),
  )();
  TextColumn get status =>
      text().withDefault(const Constant('open'))(); // 'open'|'done'|'dismissed'
}
