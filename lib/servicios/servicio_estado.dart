import 'package:sqflite/sqflite.dart';
import 'package:payflow/utilidades/formato.dart';

class ServicioEstado {
  /// Crítico: saldo < comprometidos. En riesgo: saldo < 10 % del PMT. Si no, Saludable.
  static int calcularId(double saldo, double comprometido, double pmt) {
    if (saldo < comprometido) return 4;
    if (saldo < pmt * 0.10) return 3;
    return 2;
  }

  /// Recalcula presupuestos por categoría y estado financiero. Llamar al final
  /// de cualquier operación que toque saldo, suscripciones o aportaciones.
  static Future<void> recalcular(DatabaseExecutor ex, int idPeriodo) async {
    final filas =
        await ex.query('periodo', where: 'id_periodo = ?', whereArgs: [idPeriodo]);
    if (filas.isEmpty) return;
    final p = filas.first;
    final pmt = (p['presupuesto_mensual_total'] as num).toDouble();
    final ahorro = (p['ahorro_objetivo'] as num).toDouble();
    final saldo = (p['saldo_disponible'] as num).toDouble();
    final anterior = p['id_estado_financiero'] as int?;

    await _redistribuir(ex, idPeriodo, pmt, ahorro);
    if (pmt <= ahorro) return; // déficit: el estado lo maneja ServicioPeriodo

    final r = await ex.rawQuery(
        'SELECT COALESCE(SUM(monto_cobro),0) AS t FROM suscripcion_periodo '
        'WHERE id_periodo = ? AND id_estado_suscripcion = 1',
        [idPeriodo]);
    final comprometido = (r.first['t'] as num).toDouble();
    final nuevo = calcularId(saldo, comprometido, pmt);
    if (nuevo == anterior) return;

    final ahora = fechaHoraSql(DateTime.now());
    await ex.update('periodo', {'id_estado_financiero': nuevo},
        where: 'id_periodo = ?', whereArgs: [idPeriodo]);
    await ex.insert('historial_estado_financiero',
        {'id_periodo': idPeriodo, 'id_estado': nuevo, 'fecha_hora': ahora});
    await ex.update('alerta', {'atendida': 1},
        where: 'id_periodo = ? AND id_tipo_alerta IN (2,3) AND atendida = 0',
        whereArgs: [idPeriodo]);
    if (nuevo == 3) {
      await ex.insert('alerta', {
        'id_periodo': idPeriodo,
        'id_tipo_alerta': 2,
        'mensaje': 'Estado En riesgo: tu saldo es menor al 10 % del PMT',
        'fecha_hora': ahora,
        'atendida': 0,
      });
    } else if (nuevo == 4) {
      await ex.insert('alerta', {
        'id_periodo': idPeriodo,
        'id_tipo_alerta': 3,
        'mensaje': 'Estado Crítico: tu saldo no cubre las suscripciones pendientes',
        'fecha_hora': ahora,
        'atendida': 0,
      });
    }
  }

  /// Regla del equipo: primero las suscripciones activas; lo que sobra
  /// se reparte 50 % Servicios y 50 % Ocio.
  static Future<void> _redistribuir(
      DatabaseExecutor ex, int idPeriodo, double pmt, double ahorro) async {
    double suma(List<Map<String, Object?>> r) => (r.first['t'] as num).toDouble();

    final susc = suma(await ex.rawQuery(
        'SELECT COALESCE(SUM(monto_cobro),0) AS t FROM suscripcion_periodo '
        'WHERE id_periodo = ? AND id_estado_suscripcion <> 4',
        [idPeriodo]));
    final suscPagadas = suma(await ex.rawQuery(
        'SELECT COALESCE(SUM(monto_cobro),0) AS t FROM suscripcion_periodo '
        'WHERE id_periodo = ? AND id_estado_suscripcion = 2',
        [idPeriodo]));
    final aportado = suma(await ex.rawQuery(
        'SELECT COALESCE(SUM(monto),0) AS t FROM aportacion_ahorro WHERE id_periodo = ?',
        [idPeriodo]));
    final gastos = await ex.rawQuery(
        'SELECT id_categoria, COALESCE(SUM(monto),0) AS t FROM gasto_variable '
        'WHERE id_periodo = ? GROUP BY id_categoria',
        [idPeriodo]);
    double gastoDe(int cat) {
      for (final g in gastos) {
        if (g['id_categoria'] == cat) return (g['t'] as num).toDouble();
      }
      return 0;
    }

    final libre = pmt - ahorro - susc;
    final resto = (pmt > ahorro && libre > 0) ? libre : 0.0;
    final servicios = redondear2(resto / 2);
    final ocio = redondear2(resto - servicios);

    final datos = <int, List<double>>{
      1: [ahorro, aportado],
      2: [susc, suscPagadas],
      3: [servicios, gastoDe(3)],
      4: [ocio, gastoDe(4)],
    };
    for (final e in datos.entries) {
      final n = await ex.update(
        'presupuesto_categoria',
        {'monto_asignado': e.value[0], 'monto_ejecutado': e.value[1]},
        where: 'id_periodo = ? AND id_categoria = ?',
        whereArgs: [idPeriodo, e.key],
      );
      if (n == 0) {
        await ex.insert('presupuesto_categoria', {
          'id_periodo': idPeriodo,
          'id_categoria': e.key,
          'monto_asignado': e.value[0],
          'monto_ejecutado': e.value[1],
        });
      }
    }
  }
}