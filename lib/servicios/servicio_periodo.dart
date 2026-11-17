import 'package:sqflite/sqflite.dart';
import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/servicios/servicio_estado.dart';

enum ResultadoConfig { ok, deficit, yaConfigurado }

class ServicioPeriodo {
  /// Periodo abierto (no cerrado) del usuario, o null si no hay.
  static Future<Periodo?> vigente(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final f = await db.query('periodo',
        where: 'id_usuario = ? AND cerrado = 0',
        whereArgs: [idUsuario],
        orderBy: 'id_periodo DESC',
        limit: 1);
    return f.isEmpty ? null : Periodo.desdeMapa(f.first);
  }

  static Future<ResultadoConfig> configurar(
      int idUsuario, double pmt, double ahorro) async {
    final db = await BaseDatos.abrir();
    return db.transaction<ResultadoConfig>((txn) async {
      final ahora = DateTime.now();
      final ts = fechaHoraSql(ahora);
      final f = await txn.query('periodo',
          where: 'id_usuario = ? AND cerrado = 0',
          whereArgs: [idUsuario],
          orderBy: 'id_periodo DESC',
          limit: 1);
      final existente = f.isEmpty ? null : f.first;
      if (existente != null && existente['id_estado_financiero'] != 1) {
        return ResultadoConfig.yaConfigurado;
      }

      final deficit = pmt <= ahorro;
      final Map<String, Object?> valores = {
        'presupuesto_mensual_total': pmt,
        'ahorro_objetivo': ahorro,
        'ahorro_reservado': deficit ? 0.0 : ahorro,
        'saldo_disponible': deficit ? 0.0 : redondear2(pmt - ahorro),
        'id_estado_financiero': deficit ? 1 : 2,
      };

      final anio = existente == null ? ahora.year : existente['anio'] as int;
      final mes = existente == null ? ahora.month : existente['mes'] as int;
      int idPeriodo;
      if (existente == null) {
        idPeriodo = await txn.insert('periodo', {
          ...valores,
          'id_usuario': idUsuario,
          'anio': anio,
          'mes': mes,
          'fecha_inicio': fechaSql(DateTime(anio, mes, 1)),
          'fecha_fin': fechaSql(DateTime(anio, mes + 1, 0)),
          'cerrado': 0,
          'fecha_creacion': ts,
        });
      } else {
        idPeriodo = existente['id_periodo'] as int;
        await txn.update('periodo', valores,
            where: 'id_periodo = ?', whereArgs: [idPeriodo]);
      }

      if (deficit) {
        final hay = await txn.query('alerta',
            where: 'id_periodo = ? AND id_tipo_alerta = 1 AND atendida = 0',
            whereArgs: [idPeriodo],
            orderBy: 'id_alerta');
        if (hay.isEmpty) {
          await txn.insert('alerta', {
            'id_periodo': idPeriodo,
            'id_tipo_alerta': 1,
            'mensaje': 'Alerta de déficit presupuestario en Ajustes de fondos',
            'fecha_hora': ts,
            'atendida': 0,
          });
        } else {
          for (var i = 1; i < hay.length; i++) {
            await txn.delete('alerta',
                where: 'id_alerta = ?', whereArgs: [hay[i]['id_alerta']]);
          }
        }
        if (existente == null) {
          await txn.insert('historial_estado_financiero',
              {'id_periodo': idPeriodo, 'id_estado': 1, 'fecha_hora': ts});
        }
        await ServicioEstado.recalcular(txn, idPeriodo);
        return ResultadoConfig.deficit;
      }

      // Configuración correcta
      await txn.update('alerta', {'atendida': 1},
          where: 'id_periodo = ? AND id_tipo_alerta = 1', whereArgs: [idPeriodo]);
      await txn.insert('historial_estado_financiero',
          {'id_periodo': idPeriodo, 'id_estado': 2, 'fecha_hora': ts});
      await txn.insert('movimiento', {
        'id_periodo': idPeriodo,
        'id_tipo_movimiento': 1,
        'monto': pmt,
        'saldo_anterior': 0.0,
        'saldo_posterior': pmt,
        'fecha_hora': ts,
        'descripcion': 'Asignación del PMT',
      });
      if (ahorro > 0) {
        await txn.insert('movimiento', {
          'id_periodo': idPeriodo,
          'id_tipo_movimiento': 2,
          'monto': ahorro,
          'saldo_anterior': pmt,
          'saldo_posterior': redondear2(pmt - ahorro),
          'fecha_hora': ts,
          'descripcion': 'Reserva de ahorro objetivo',
        });
      }
      // Suscripciones activas entran al periodo como pendientes (o suspendidas)
      final subs = await txn.query('suscripcion',
          where: 'id_usuario = ? AND activa = 1', whereArgs: [idUsuario]);
      for (final s in subs) {
        await txn.insert(
          'suscripcion_periodo',
          {
            'id_suscripcion': s['id_suscripcion'],
            'id_periodo': idPeriodo,
            'monto_cobro': s['monto'],
            'fecha_cobro_programada':
                fechaDeCobro(anio, mes, s['dia_cobro'] as int),
            'id_estado_suscripcion': (s['suspendida'] as int) == 1 ? 4 : 1,
            'intentos_cobro': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await ServicioEstado.recalcular(txn, idPeriodo);
      return ResultadoConfig.ok;
    });
  }
}