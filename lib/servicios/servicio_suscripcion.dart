import 'package:sqflite/sqflite.dart';
import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/suscripcion.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/servicios/servicio_estado.dart';
import 'package:payflow/servicios/servicio_periodo.dart';

enum ResultadoCobro { pagado, rechazado, noAplica }

class ServicioSuscripcion {
  static Future<List<Suscripcion>> listar(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final p = await ServicioPeriodo.vigente(idUsuario);
    final f = await db.rawQuery(
      'SELECT s.*, sp.id_suscripcion_periodo AS id_sp, '
      'sp.id_estado_suscripcion AS estado_sp, '
      'sp.fecha_cobro_programada AS fecha_prog, '
      'sp.fecha_cobro_real AS fecha_real, sp.intentos_cobro AS intentos '
      'FROM suscripcion s LEFT JOIN suscripcion_periodo sp '
      'ON sp.id_suscripcion = s.id_suscripcion AND sp.id_periodo = ? '
      'WHERE s.id_usuario = ? AND s.activa = 1 '
      'ORDER BY sp.fecha_cobro_programada, s.nombre',
      [p?.id ?? -1, idUsuario],
    );
    return f.map(Suscripcion.desdeMapa).toList();
  }

  /// suscripcion_periodo del periodo abierto (con anio, mes y usuario).
  static Future<Map<String, Object?>?> _spAbierto(
      DatabaseExecutor ex, int idSuscripcion) async {
    final f = await ex.rawQuery(
      'SELECT sp.*, p.anio AS anio, p.mes AS mes FROM suscripcion_periodo sp '
      'JOIN periodo p ON p.id_periodo = sp.id_periodo '
      'WHERE sp.id_suscripcion = ? AND p.cerrado = 0 '
      'ORDER BY sp.id_periodo DESC LIMIT 1',
      [idSuscripcion],
    );
    return f.isEmpty ? null : f.first;
  }

  static Future<void> _bitacora(DatabaseExecutor ex, int idSp, int anterior,
      int nuevo, String motivo) async {
    await ex.insert('bitacora_estado_suscripcion', {
      'id_suscripcion_periodo': idSp,
      'id_estado_anterior': anterior,
      'id_estado_nuevo': nuevo,
      'fecha_hora': fechaHoraSql(DateTime.now()),
      'motivo': motivo,
    });
  }

  static Future<void> crear(
    int idUsuario, {
    required String nombre,
    required double monto,
    required int idTipo,
    required int dia,
    required bool autocobro,
  }) async {
    final db = await BaseDatos.abrir();
    await db.transaction((txn) async {
      final id = await txn.insert('suscripcion', {
        'id_usuario': idUsuario,
        'nombre': nombre,
        'monto': monto,
        'id_tipo_suscripcion': idTipo,
        'dia_cobro': dia,
        'activa': 1,
        'suspendida': 0,
        'fecha_alta': fechaSql(DateTime.now()),
        'autocobro': autocobro ? 1 : 0,
      });
      final per = await txn.query('periodo',
          where: 'id_usuario = ? AND cerrado = 0',
          whereArgs: [idUsuario],
          orderBy: 'id_periodo DESC',
          limit: 1);
      if (per.isNotEmpty) {
        final idPeriodo = per.first['id_periodo'] as int;
        await txn.insert('suscripcion_periodo', {
          'id_suscripcion': id,
          'id_periodo': idPeriodo,
          'monto_cobro': monto,
          'fecha_cobro_programada': fechaDeCobro(
              per.first['anio'] as int, per.first['mes'] as int, dia),
          'id_estado_suscripcion': 1,
          'intentos_cobro': 0,
        });
        await ServicioEstado.recalcular(txn, idPeriodo);
      }
    });
  }

  static Future<void> editar(
    int id, {
    required String nombre,
    required double monto,
    required int idTipo,
    required int dia,
    required bool autocobro,
  }) async {
    final db = await BaseDatos.abrir();
    await db.transaction((txn) async {
      await txn.update(
        'suscripcion',
        {
          'nombre': nombre,
          'monto': monto,
          'id_tipo_suscripcion': idTipo,
          'dia_cobro': dia,
          'autocobro': autocobro ? 1 : 0,
        },
        where: 'id_suscripcion = ?',
        whereArgs: [id],
      );
      final sp = await _spAbierto(txn, id);
      if (sp != null) {
        final estado = sp['id_estado_suscripcion'] as int;
        // Un cobro ya pagado no se modifica; el cambio aplica desde el siguiente periodo.
        if (estado == 1 || estado == 3) {
          await txn.update(
            'suscripcion_periodo',
            {
              'monto_cobro': monto,
              'fecha_cobro_programada':
                  fechaDeCobro(sp['anio'] as int, sp['mes'] as int, dia),
            },
            where: 'id_suscripcion_periodo = ?',
            whereArgs: [sp['id_suscripcion_periodo']],
          );
        }
        await ServicioEstado.recalcular(txn, sp['id_periodo'] as int);
      }
    });
  }

  /// Baja lógica: el cobro del periodo queda como suspendido (no se cobra).
  static Future<void> eliminar(int id) async {
    final db = await BaseDatos.abrir();
    await db.transaction((txn) async {
      await txn.update(
          'suscripcion', {'activa': 0, 'fecha_baja': fechaSql(DateTime.now())},
          where: 'id_suscripcion = ?', whereArgs: [id]);
      await _suspenderCobro(txn, id, 'Eliminada por el usuario');
    });
  }

  static Future<void> suspender(int id) async {
    final db = await BaseDatos.abrir();
    await db.transaction((txn) async {
      await txn.update('suscripcion', {'suspendida': 1},
          where: 'id_suscripcion = ?', whereArgs: [id]);
      await _suspenderCobro(txn, id, 'Suspendida por el usuario');
    });
  }

  static Future<void> _suspenderCobro(
      DatabaseExecutor ex, int id, String motivo) async {
    final sp = await _spAbierto(ex, id);
    if (sp == null) return;
    final estado = sp['id_estado_suscripcion'] as int;
    final idSp = sp['id_suscripcion_periodo'] as int;
    if (estado == 1 || estado == 3) {
      await ex.update('suscripcion_periodo', {'id_estado_suscripcion': 4},
          where: 'id_suscripcion_periodo = ?', whereArgs: [idSp]);
      await _bitacora(ex, idSp, estado, 4, motivo);
    }
    await ServicioEstado.recalcular(ex, sp['id_periodo'] as int);
  }

  static Future<void> reactivar(int id) async {
    final db = await BaseDatos.abrir();
    await db.transaction((txn) async {
      await txn.update('suscripcion', {'suspendida': 0},
          where: 'id_suscripcion = ?', whereArgs: [id]);
      final sp = await _spAbierto(txn, id);
      if (sp == null) return;
      final idSp = sp['id_suscripcion_periodo'] as int;
      if (sp['id_estado_suscripcion'] == 4) {
        await txn.update('suscripcion_periodo', {'id_estado_suscripcion': 1},
            where: 'id_suscripcion_periodo = ?', whereArgs: [idSp]);
        await _bitacora(txn, idSp, 4, 1, 'Reactivada por el usuario');
      }
      await ServicioEstado.recalcular(txn, sp['id_periodo'] as int);
    });
  }

  /// Cobro (manual con "Pagar ahora" o automático por autodébito). Todo o nada.
  static Future<ResultadoCobro> cobrar(int idSp) async {
    final db = await BaseDatos.abrir();
    return db.transaction<ResultadoCobro>((txn) async {
      final f = await txn.rawQuery(
        'SELECT sp.*, s.nombre AS nombre, p.saldo_disponible AS saldo, '
        'p.id_estado_financiero AS estado_p, p.cerrado AS cerrado '
        'FROM suscripcion_periodo sp '
        'JOIN suscripcion s ON s.id_suscripcion = sp.id_suscripcion '
        'JOIN periodo p ON p.id_periodo = sp.id_periodo '
        'WHERE sp.id_suscripcion_periodo = ?',
        [idSp],
      );
      if (f.isEmpty) return ResultadoCobro.noAplica;
      final sp = f.first;
      final estado = sp['id_estado_suscripcion'] as int;
      if ((estado != 1 && estado != 3) ||
          sp['estado_p'] == 1 ||
          sp['cerrado'] == 1) {
        return ResultadoCobro.noAplica;
      }

      final idPeriodo = sp['id_periodo'] as int;
      final monto = (sp['monto_cobro'] as num).toDouble();
      final saldo = (sp['saldo'] as num).toDouble();
      final nombre = sp['nombre'] as String;
      final ahora = fechaHoraSql(DateTime.now());
      final intentos = (sp['intentos_cobro'] as int) + 1;

      if (saldo + 0.0001 >= monto) {
        final nuevo = redondear2(saldo - monto);
        await txn.update('periodo', {'saldo_disponible': nuevo},
            where: 'id_periodo = ?', whereArgs: [idPeriodo]);
        await txn.update(
          'suscripcion_periodo',
          {
            'id_estado_suscripcion': 2,
            'fecha_cobro_real': ahora,
            'intentos_cobro': intentos,
          },
          where: 'id_suscripcion_periodo = ?',
          whereArgs: [idSp],
        );
        await _bitacora(txn, idSp, estado, 2, 'Cobro confirmado');
        await txn.insert('movimiento', {
          'id_periodo': idPeriodo,
          'id_tipo_movimiento': 3,
          'monto': monto,
          'saldo_anterior': saldo,
          'saldo_posterior': nuevo,
          'fecha_hora': ahora,
          'descripcion': 'Cobro de suscripción: $nombre',
          'id_suscripcion_periodo': idSp,
        });
        await txn.update('alerta', {'atendida': 1},
            where: 'id_suscripcion_periodo = ? AND id_tipo_alerta = 4',
            whereArgs: [idSp]);
        await ServicioEstado.recalcular(txn, idPeriodo);
        return ResultadoCobro.pagado;
      }

      await txn.update(
        'suscripcion_periodo',
        {'id_estado_suscripcion': 3, 'intentos_cobro': intentos},
        where: 'id_suscripcion_periodo = ?',
        whereArgs: [idSp],
      );
      if (estado != 3) {
        await _bitacora(txn, idSp, estado, 3, 'Saldo insuficiente');
      }
      final hay = await txn.query('alerta',
          where: 'id_suscripcion_periodo = ? AND id_tipo_alerta = 4 AND atendida = 0',
          whereArgs: [idSp]);
      if (hay.isEmpty) {
        await txn.insert('alerta', {
          'id_periodo': idPeriodo,
          'id_tipo_alerta': 4,
          'mensaje': 'Cobro rechazado por saldo insuficiente: $nombre',
          'fecha_hora': ahora,
          'atendida': 0,
          'id_suscripcion_periodo': idSp,
        });
      }
      await ServicioEstado.recalcular(txn, idPeriodo);
      return ResultadoCobro.rechazado;
    });
  }

  /// Autodébito: cobra las pendientes con autocobro cuya fecha ya llegó.
  static Future<void> procesarAutocobros(int idUsuario) async {
    final p = await ServicioPeriodo.vigente(idUsuario);
    if (p == null || p.enDeficit) return;
    final db = await BaseDatos.abrir();
    final filas = await db.rawQuery(
      'SELECT sp.id_suscripcion_periodo AS id FROM suscripcion_periodo sp '
      'JOIN suscripcion s ON s.id_suscripcion = sp.id_suscripcion '
      'WHERE sp.id_periodo = ? AND sp.id_estado_suscripcion = 1 '
      'AND s.autocobro = 1 AND s.suspendida = 0 AND s.activa = 1 '
      'AND sp.fecha_cobro_programada <= ? '
      'ORDER BY sp.fecha_cobro_programada, sp.id_suscripcion_periodo',
      [p.id, fechaSql(DateTime.now())],
    );
    for (final f in filas) {
      await cobrar(f['id'] as int);
    }
  }
}