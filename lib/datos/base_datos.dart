import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abre la base de datos local y la crea la primera vez.
class BaseDatos {
  static Database? _baseDatos;

  static Future<Database> get instancia async {
    if (_baseDatos != null) return _baseDatos!;

    // Solo en escritorio (para probar en Windows). En Android no se usa.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final ruta = join(await getDatabasesPath(), 'payflow.db');
    _baseDatos = await openDatabase(
      ruta,
      version: 1,
      onConfigure: (bd) => bd.execute('PRAGMA foreign_keys = ON'),
      onCreate: (bd, version) async {
        final script = await rootBundle.loadString('assets/payflow_schema.sql');
        // Quita las líneas de comentario y separa por ";" al final de línea.
        final limpio = script
            .split('\n')
            .where((linea) => !linea.trim().startsWith('--'))
            .join('\n');
        for (final bloque in limpio.split(RegExp(r';\s*\n'))) {
          final sentencia = bloque.trim();
          if (sentencia.isNotEmpty) await bd.execute(sentencia);
        }
      },
    );
    return _baseDatos!;
  }
}