import 'dart:convert';

import 'package:drift/drift.dart';

class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) =>
      json.decode(fromDb) as Map<String, dynamic>;

  @override
  String toSql(Map<String, dynamic> value) => json.encode(value);
}
