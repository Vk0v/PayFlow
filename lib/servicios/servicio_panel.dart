import '../datos/base_datos.dart';
import '../modelos/periodo.dart';
import 'servicio_periodo.dart';

/// Todo lo que necesita el panel principal, en un solo objeto.
class DatosPanel {
  final Periodo? periodo;
  final Map<int, List<double>> categorias; // id_categoria -> [asignado, ejecutado]
  final double pendientes;
  final double? proximoCobro;

  DatosPanel(this.periodo, this.categorias, this.pendientes, this.proximoCobro);
}

class ServicioPanel {
  Future<DatosPanel> cargar(int idUsuario) async {
    final periodo = await ServicioPeriodo().vigente(idUsuario);
    if (periodo == null) return DatosPanel(null, {}, 0, null);

    final bd = await BaseDatos.instancia;

    final filasCategorias = await bd.query('presupuesto_categoria',
        where: 'id_periodo = ?', whereArgs: [periodo.id]);
    final categorias = <int, List<double>>{
      for (final fila in filasCategorias)
        fila['id_categoria'] as int: [
          (fila['monto_asignado'] as num).toDouble(),
          (fila['monto_ejecutado'] as num).toDouble(),
        ],
    };

    final sumaPendientes = await bd.rawQuery(
        'SELECT COALESCE(SUM(monto_cobro), 0) AS total FROM suscripcion_periodo '
        'WHERE id_periodo = ? AND id_estado_suscripcion = 1',
        [periodo.id]);

    final siguiente = await bd.rawQuery(
        'SELECT monto_cobro FROM suscripcion_periodo '
        'WHERE id_periodo = ? AND id_estado_suscripcion = 1 '
        'ORDER BY fecha_cobro_programada LIMIT 1',
        [periodo.id]);

    return DatosPanel(
      periodo,
      categorias,
      (sumaPendientes.first['total'] as num).toDouble(),
      siguiente.isEmpty ? null : (siguiente.first['monto_cobro'] as num).toDouble(),
    );
  }
}