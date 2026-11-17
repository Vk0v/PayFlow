import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/alerta.dart';

class ServicioAlerta {
  static Future<List<Alerta>> listar(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final f = await db.rawQuery(
      'SELECT a.* FROM alerta a JOIN periodo p ON p.id_periodo = a.id_periodo '
      'WHERE p.id_usuario = ? ORDER BY a.id_alerta DESC LIMIT 100',
      [idUsuario],
    );
    return f.map(Alerta.desdeMapa).toList();
  }

  static Future<int> contarPendientes(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final f = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM alerta a JOIN periodo p ON p.id_periodo = a.id_periodo '
      'WHERE p.id_usuario = ? AND a.atendida = 0',
      [idUsuario],
    );
    return (f.first['n'] as num).toInt();
  }

  static Future<void> marcarAtendida(int idAlerta) async {
    final db = await BaseDatos.abrir();
    await db.update('alerta', {'atendida': 1},
        where: 'id_alerta = ?', whereArgs: [idAlerta]);
  }

  static Future<void> marcarTodas(int idUsuario) async {
    final db = await BaseDatos.abrir();
    await db.rawUpdate(
      'UPDATE alerta SET atendida = 1 WHERE atendida = 0 AND id_periodo IN '
      '(SELECT id_periodo FROM periodo WHERE id_usuario = ?)',
      [idUsuario],
    );
  }
}