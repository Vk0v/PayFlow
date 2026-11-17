import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/movimiento.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/servicios/servicio_estado.dart';

enum EstadoValidacion { ok, sinPeriodo, bloqueado, saldoInsuficiente, riesgo }

enum FiltroMovimientos { todos, asignaciones, cobros, gastos }

class CobroEnRiesgo {
  final int idSp;
  final String nombre;
  final double monto;
  final String fecha;
  const CobroEnRiesgo(this.idSp, this.nombre, this.monto, this.fecha);
}

class ResultadoGasto {
  final EstadoValidacion estado;
  final double saldo;
  final double comprometido;
  final List<CobroEnRiesgo> riesgos;
  const ResultadoGasto(this.estado, this.saldo, this.comprometido, this.riesgos);
}

class ServicioGasto {
  /// Valida y registra un gasto de Servicios (3) u Ocio (4).
  /// Si es de Ocio y deja sin cubrir suscripciones pendientes, devuelve
  /// `riesgo` sin guardar; se guarda al llamar de nuevo con aceptaRiesgo.
  static Future<ResultadoGasto> registrar(
    int idUsuario, {
    required int idCategoria,
    required String concepto,
    required double monto,
    required DateTime fecha,
    bool aceptaRiesgo = false,
  }) async {
    final db = await BaseDatos.abrir();
    return db.transaction<ResultadoGasto>((txn) async {
      final f = await txn.query('periodo',
          where: 'id_usuario = ? AND cerrado = 0',
          whereArgs: [idUsuario],
          orderBy: 'id_periodo DESC',
          limit: 1);
      if (f.isEmpty) {
        return const ResultadoGasto(EstadoValidacion.sinPeriodo, 0, 0, []);
      }
      final p = Periodo.desdeMapa(f.first);
      if (p.enDeficit) {
        return ResultadoGasto(EstadoValidacion.bloqueado, p.saldo, 0, const []);
      }

      final pend = await txn.rawQuery(
        'SELECT sp.id_suscripcion_periodo AS id, s.nombre AS nombre, '
        'sp.monto_cobro AS monto, sp.fecha_cobro_programada AS fecha '
        'FROM suscripcion_periodo sp '
        'JOIN suscripcion s ON s.id_suscripcion = sp.id_suscripcion '
        'WHERE sp.id_periodo = ? AND sp.id_estado_suscripcion = 1 '
        'ORDER BY sp.fecha_cobro_programada, sp.id_suscripcion_periodo',
        [p.id],
      );
      var comprometido = 0.0;
      for (final e in pend) {
        comprometido += (e['monto'] as num).toDouble();
      }

      if (monto > p.saldo + 0.001) {
        return ResultadoGasto(
            EstadoValidacion.saldoInsuficiente, p.saldo, comprometido, const []);
      }

      final riesgos = <CobroEnRiesgo>[];
      if (idCategoria == 4) {
        var disponible = p.saldo - monto;
        for (final e in pend) {
          final m = (e['monto'] as num).toDouble();
          if (disponible + 0.001 >= m) {
            disponible -= m;
          } else {
            riesgos.add(CobroEnRiesgo(
                e['id'] as int, e['nombre'] as String, m, e['fecha'] as String));
          }
        }
      }
      if (riesgos.isNotEmpty && !aceptaRiesgo) {
        return ResultadoGasto(
            EstadoValidacion.riesgo, p.saldo, comprometido, riesgos);
      }

      final ahora = fechaHoraSql(DateTime.now());
      final idGasto = await txn.insert('gasto_variable', {
        'id_periodo': p.id,
        'id_categoria': idCategoria,
        'concepto': concepto,
        'monto': monto,
        'fecha_gasto': fechaSql(fecha),
        'fecha_registro': ahora,
        'genera_advertencia': riesgos.isEmpty ? 0 : 1,
        'id_suscripcion_periodo_riesgo':
            riesgos.isEmpty ? null : riesgos.first.idSp,
      });
      final nuevo = redondear2(p.saldo - monto);
      await txn.update('periodo', {'saldo_disponible': nuevo},
          where: 'id_periodo = ?', whereArgs: [p.id]);
      await txn.insert('movimiento', {
        'id_periodo': p.id,
        'id_tipo_movimiento': 4,
        'monto': monto,
        'saldo_anterior': p.saldo,
        'saldo_posterior': nuevo,
        'fecha_hora': ahora,
        'descripcion': concepto,
        'id_gasto': idGasto,
      });
      if (riesgos.isNotEmpty) {
        await txn.insert('alerta', {
          'id_periodo': p.id,
          'id_tipo_alerta': 5,
          'mensaje':
              'Gasto de Ocio registrado con riesgo para: ${riesgos.map((r) => r.nombre).join(', ')}',
          'fecha_hora': ahora,
          'atendida': 0,
          'id_gasto': idGasto,
          'id_suscripcion_periodo': riesgos.first.idSp,
        });
      }
      await ServicioEstado.recalcular(txn, p.id);
      return ResultadoGasto(EstadoValidacion.ok, nuevo, comprometido, riesgos);
    });
  }

  static Future<List<Movimiento>> historial(
      int idUsuario, FiltroMovimientos filtro) async {
    final db = await BaseDatos.abrir();
    var extra = '';
    if (filtro == FiltroMovimientos.asignaciones) {
      extra = 'AND m.id_tipo_movimiento IN (1,2,5)';
    } else if (filtro == FiltroMovimientos.cobros) {
      extra = 'AND m.id_tipo_movimiento = 3';
    } else if (filtro == FiltroMovimientos.gastos) {
      extra = 'AND m.id_tipo_movimiento = 4';
    }
    final f = await db.rawQuery(
      'SELECT m.*, t.efecto_saldo AS efecto FROM movimiento m '
      'JOIN periodo p ON p.id_periodo = m.id_periodo '
      'JOIN cat_tipo_movimiento t ON t.id_tipo_movimiento = m.id_tipo_movimiento '
      'WHERE p.id_usuario = ? $extra ORDER BY m.id_movimiento DESC LIMIT 200',
      [idUsuario],
    );
    return f.map(Movimiento.desdeMapa).toList();
  }

  static Future<List<String>> sugerencias(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final f = await db.rawQuery(
      'SELECT g.concepto AS c, MAX(g.id_gasto) AS u FROM gasto_variable g '
      'JOIN periodo p ON p.id_periodo = g.id_periodo WHERE p.id_usuario = ? '
      'GROUP BY g.concepto ORDER BY u DESC LIMIT 5',
      [idUsuario],
    );
    return f.map((e) => e['c'] as String).toList();
  }
}