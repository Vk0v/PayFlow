import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/meta.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/servicios/servicio_estado.dart';
import 'package:payflow/servicios/servicio_periodo.dart';

class ServicioMeta {
  static Future<List<Meta>> listar(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final f = await db.query('meta_ahorro',
        where: 'id_usuario = ? AND activa = 1',
        whereArgs: [idUsuario],
        orderBy: 'id_meta DESC');
    return f.map(Meta.desdeMapa).toList();
  }

  static Future<void> crear(
      int idUsuario, String nombre, double objetivo, String? fechaLimite) async {
    final db = await BaseDatos.abrir();
    await db.insert('meta_ahorro', {
      'id_usuario': idUsuario,
      'nombre': nombre,
      'monto_objetivo': objetivo,
      'monto_acumulado': 0.0,
      'fecha_creacion': fechaSql(DateTime.now()),
      'fecha_limite': fechaLimite,
      'activa': 1,
    });
  }

  static Future<void> eliminar(int idMeta) async {
    final db = await BaseDatos.abrir();
    await db.update('meta_ahorro', {'activa': 0},
        where: 'id_meta = ?', whereArgs: [idMeta]);
  }

  /// Ahorro del periodo que aún no se ha asignado a ninguna meta.
  static Future<double> ahorroDisponible(int idUsuario) async {
    final p = await ServicioPeriodo.vigente(idUsuario);
    if (p == null || p.enDeficit) return 0;
    final db = await BaseDatos.abrir();
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(monto),0) AS t FROM aportacion_ahorro WHERE id_periodo = ?',
        [p.id]);
    final disp = redondear2(p.ahorroReservado - (r.first['t'] as num).toDouble());
    return disp > 0 ? disp : 0;
  }

  /// Devuelve un mensaje de error, o null si la aportación se registró.
  static Future<String?> aportar(int idUsuario, int idMeta, double monto) async {
    if (monto <= 0) return 'Ingresa un monto mayor a cero.';
    final p = await ServicioPeriodo.vigente(idUsuario);
    if (p == null || p.enDeficit) {
      return 'Configura tus fondos del periodo antes de aportar.';
    }
    final disp = await ahorroDisponible(idUsuario);
    if (monto > disp + 0.001) {
      return 'El monto excede tu ahorro disponible del periodo (${dinero(disp)}).';
    }
    final db = await BaseDatos.abrir();
    final m = await db.query('meta_ahorro',
        where: 'id_meta = ?', whereArgs: [idMeta], limit: 1);
    if (m.isEmpty) return 'La meta ya no existe.';
    final meta = Meta.desdeMapa(m.first);
    if (monto > meta.faltante + 0.001) {
      return 'La meta solo necesita ${dinero(meta.faltante)} para completarse.';
    }
    await db.transaction((txn) async {
      await txn.insert('aportacion_ahorro', {
        'id_periodo': p.id,
        'id_meta': idMeta,
        'monto': monto,
        'fecha_aportacion': fechaHoraSql(DateTime.now()),
      });
      await txn.update('meta_ahorro',
          {'monto_acumulado': redondear2(meta.acumulado + monto)},
          where: 'id_meta = ?', whereArgs: [idMeta]);
      await ServicioEstado.recalcular(txn, p.id);
    });
    return null;
  }

  static Future<List<Aportacion>> aportaciones(int idMeta) async {
    final db = await BaseDatos.abrir();
    final f = await db.query('aportacion_ahorro',
        where: 'id_meta = ?', whereArgs: [idMeta], orderBy: 'id_aportacion DESC');
    return f.map(Aportacion.desdeMapa).toList();
  }
}