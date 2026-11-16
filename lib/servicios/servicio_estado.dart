import 'package:sqflite/sqflite.dart';
import '../utilidades/formato.dart';

enum EstadoFin { saludable, enRiesgo, critico }

class ServicioEstado {
  /// Regla de CU05: compara saldo, compromisos pendientes y el 10 % del PMT.
  static EstadoFin calcular({
    required double saldo,
    required double comprometidos,
    required double pmt,
  }) {
    if (saldo < comprometidos) return EstadoFin.critico;
    if (saldo < pmt * 0.10) return EstadoFin.enRiesgo;
    return EstadoFin.saludable;
  }

  /// Identificador en la tabla cat_estado_financiero.
  static int idEstado(EstadoFin estado) => switch (estado) {
        EstadoFin.saludable => 2,
        EstadoFin.enRiesgo => 3,
        EstadoFin.critico => 4,
      };

  /// Recalcula el estado del periodo y lo guarda si cambió.
  /// Acepta la base de datos o una transacción.
  Future<EstadoFin?> recalcular(DatabaseExecutor ejecutor, int idPeriodo) async {
    final filas = await ejecutor.query('periodo',
        where: 'id_periodo = ?', whereArgs: [idPeriodo]);
    if (filas.isEmpty) return null;

    final estadoActual = filas.first['id_estado_financiero'] as int?;
    // Sin configurar o en déficit: no se recalcula.
    if (estadoActual == null || estadoActual == 1) return null;

    final saldo = (filas.first['saldo_disponible'] as num).toDouble();
    final pmt = (filas.first['presupuesto_mensual_total'] as num).toDouble();

    // Suscripciones pendientes (estado 1 = PENDIENTE).
    final resultado = await ejecutor.rawQuery(
        'SELECT COALESCE(SUM(monto_cobro), 0) AS total FROM suscripcion_periodo '
        'WHERE id_periodo = ? AND id_estado_suscripcion = 1',
        [idPeriodo]);
    final comprometidos = (resultado.first['total'] as num).toDouble();

    final estado = calcular(saldo: saldo, comprometidos: comprometidos, pmt: pmt);
    final idNuevo = idEstado(estado);

    if (idNuevo != estadoActual) {
      await ejecutor.update('periodo', {'id_estado_financiero': idNuevo},
          where: 'id_periodo = ?', whereArgs: [idPeriodo]);
      await ejecutor.insert('historial_estado_financiero', {
        'id_periodo': idPeriodo,
        'id_estado': idNuevo,
        'fecha_hora': fechaHoraSql(DateTime.now()),
      });
    }
    return estado;
  }
}