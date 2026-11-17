import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

class BaseDatos {
  static Database? _bd;

  static Future<Database> abrir() async {
    if (_bd != null) return _bd!;
    final ruta = '${await getDatabasesPath()}/payflow.db';
    final esquema = await rootBundle.loadString('assets/payflow_schema.sql');
    _bd = await openDatabase(
      ruta,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, version) async {
        final limpio = esquema
            .split('\n')
            .where((l) => !l.trim().startsWith('--'))
            .join('\n');
        for (final bloque in limpio.split(RegExp(r';\s*\n'))) {
          final sentencia = bloque.trim();
          if (sentencia.isNotEmpty) await d.execute(sentencia);
        }
      },
    );
    return _bd!;
  }
}