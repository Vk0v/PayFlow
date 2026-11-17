import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/servicios/servicio_periodo.dart';

class DatosPanel {
  final Periodo? periodo;
  final Map<int, List<double>> categorias; // id -> [asignado, ejecutado]
  final double aportado;
  final int pendientes;
  final double comprometido;
  final String? proximoNombre;
  final String? proximaFecha;

  const DatosPanel({
    required this.periodo,
    required this.categorias,
    required this.aportado,
    required this.pendientes,
    required this.comprometido,
    this.proximoNombre,
    this.proximaFecha,
  });
}

class ServicioPanel {
  static Future<DatosPanel> cargar(int idUsuario) async {
    final p = await ServicioPeriodo.vigente(idUsuario);
    if (p == null) {
      return const DatosPanel(
          periodo: null,
          categorias: {},
          aportado: 0,
          pendientes: 0,
          comprometido: 0);
    }
    final db = await BaseDatos.abrir();
    final cat = <int, List<double>>{};
    final filas = await db.query('presupuesto_categoria',
        where: 'id_periodo = ?', whereArgs: [p.id]);
    for (final r in filas) {
      cat[r['id_categoria'] as int] = [
        (r['monto_asignado'] as num).toDouble(),
        (r['monto_ejecutado'] as num).toDouble(),
      ];
    }
    final ap = await db.rawQuery(
        'SELECT COALESCE(SUM(monto),0) AS t FROM aportacion_ahorro WHERE id_periodo = ?',
        [p.id]);
    final pend = await db.rawQuery(
      'SELECT s.nombre AS nombre, sp.monto_cobro AS monto, '
      'sp.fecha_cobro_programada AS fecha FROM suscripcion_periodo sp '
      'JOIN suscripcion s ON s.id_suscripcion = sp.id_suscripcion '
      'WHERE sp.id_periodo = ? AND sp.id_estado_suscripcion = 1 '
      'ORDER BY sp.fecha_cobro_programada',
      [p.id],
    );
    var comprometido = 0.0;
    for (final e in pend) {
      comprometido += (e['monto'] as num).toDouble();
    }
    return DatosPanel(
      periodo: p,
      categorias: cat,
      aportado: (ap.first['t'] as num).toDouble(),
      pendientes: pend.length,
      comprometido: comprometido,
      proximoNombre: pend.isEmpty ? null : pend.first['nombre'] as String,
      proximaFecha: pend.isEmpty ? null : pend.first['fecha'] as String,
    );
  }
}