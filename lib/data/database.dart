// lib/data/database.dart
// Drift database definition — sqlite3_flutter_libs backed.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

class Fields extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get crop => intEnum<Crop>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TestReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fieldId => integer().references(Fields, #id)();
  DateTimeColumn get takenAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

@DataClassName('MeasurementRow')
class SensorMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get readingId => integer().references(TestReadings, #id)();
  IntColumn get sensorType => intEnum<SensorType>()();
  RealColumn get value => real()();
  TextColumn get unit => text().withLength(min: 1, max: 20)();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Fields, TestReadings, SensorMeasurements])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // -------------------------------------------------------------------------
  // Field CRUD
  // -------------------------------------------------------------------------

  Stream<List<Field>> watchAllFields() => select(fields).watch();

  Future<int> insertField(FieldsCompanion field) =>
      into(fields).insert(field);

  Future<bool> updateField(Field field) => update(fields).replace(field);

  Future<int> deleteField(int id) =>
      (delete(fields)..where((t) => t.id.equals(id))).go();

  // -------------------------------------------------------------------------
  // Test Reading CRUD
  // -------------------------------------------------------------------------

  Stream<List<TestReading>> watchReadingsForField(int fieldId) {
    return (select(testReadings)
          ..where((t) => t.fieldId.equals(fieldId))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<int> insertReading(TestReadingsCompanion reading) =>
      into(testReadings).insert(reading);

  Future<int> deleteReading(int id) =>
      (delete(testReadings)..where((t) => t.id.equals(id))).go();

  Future<int> updateReadingField(int readingId, int fieldId) {
    return (update(testReadings)..where((t) => t.id.equals(readingId)))
        .write(TestReadingsCompanion(fieldId: Value(fieldId)));
  }

  // -------------------------------------------------------------------------
  // Measurements
  // -------------------------------------------------------------------------

  Future<void> insertMeasurements(
    int readingId,
    List<MeasurementEntry> entries,
  ) async {
    await batch((batch) {
      for (final e in entries) {
        batch.insert(
          sensorMeasurements,
          SensorMeasurementsCompanion.insert(
            readingId: readingId,
            sensorType: e.sensorType,
            value: e.value,
            unit: e.unit,
          ),
        );
      }
    });
  }

  Future<List<MeasurementRow>> getMeasurementsForReading(int readingId) async {
    final rows = await (select(sensorMeasurements)
          ..where((t) => t.readingId.equals(readingId)))
        .get();
    return rows;
  }

  // History: latest N readings for a field with their measurements
  Future<List<FieldHistoryEntry>> getFieldHistory(
    int fieldId, {
    int limit = 20,
  }) async {
    final readings = await (select(testReadings)
          ..where((t) => t.fieldId.equals(fieldId))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)])
          ..limit(limit))
        .get();

    final entries = <FieldHistoryEntry>[];
    for (final r in readings) {
      final measurements = await getMeasurementsForReading(r.id);
      entries.add(FieldHistoryEntry(reading: r, measurements: measurements));
    }
    return entries;
  }
}

// ---------------------------------------------------------------------------
// Helper types
// ---------------------------------------------------------------------------

class MeasurementEntry {
  final SensorType sensorType;
  final double value;
  final String unit;
  MeasurementEntry({
    required this.sensorType,
    required this.value,
    required this.unit,
  });
}

class FieldHistoryEntry {
  final TestReading reading;
  final List<MeasurementRow> measurements;
  FieldHistoryEntry({required this.reading, required this.measurements});
}

// ---------------------------------------------------------------------------
// Connection
// ---------------------------------------------------------------------------

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'soilsense.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
