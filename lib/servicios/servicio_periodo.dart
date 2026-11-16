import '../datos/base_datos.dart';
import '../modelos/periodo.dart';
import '../utilidades/formato.dart';
import 'servicio_estado.dart';

enum ResultadoConfig { ok, deficit, yaConfigurado }

class ServicioPeriodo {
  /// Periodo abierto más reciente del usuario, o null si no hay.
  Future<Periodo?> vigente(int idUsuario) async {
    final bd = await BaseDatos.instancia;
    final filas = await bd.query('periodo',
        where: 'id_usuario = ? AND cerrado = 0',
        whereArgs: [idUsuario],
        orderBy: 'id_periodo DESC',
        limit: 1);
    return filas.isEmpty ? null : Periodo.desdeMapa(filas.first);
  }

  /// Registra el periodo (CU03) y evalúa la viabilidad del ahorro (CU04).
  /// Todo ocurre en una sola transacción: si algo falla, no se guarda nada.
  Future<ResultadoConfig> configurar({
    required int idUsuario,
    required double pmt,
    required double ahorro,
  }) async {
    final bd = await BaseDatos.instancia;
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, 1);
    final fin = DateTime(ahora.year, ahora.month + 1, 0);
    final fechaHora = fechaHoraSql(ahora);

    return bd.transaction<ResultadoConfig>((tx) async {
      // ---------- CU03: registrar el periodo ----------
      final existente = await tx.query('periodo',
          where: 'id_usuario = ? AND cerrado = 0',
          whereArgs: [idUsuario],
          orderBy: 'id_periodo DESC',
          limit: 1);

      final Map<String, Object?> datos = {
        'presupuesto_mensual_total': pmt,
        'ahorro_objetivo': ahorro,
      };

      int idPeriodo;
      if (existente.isEmpty) {
        idPeriodo = await tx.insert('periodo', {
          ...datos,
          'id_usuario': idUsuario,
          'anio': ahora.year,
          'mes': ahora.month,
          'fecha_inicio': fechaSql(inicio),
          'fecha_fin': fechaSql(fin),
          'fecha_creacion': fechaHora,
        });
      } else {
        final estado = existente.first['id_estado_financiero'] as int?;
        if (estado != null && estado != 1) return ResultadoConfig.yaConfigurado;
        idPeriodo = existente.first['id_periodo'] as int;
        await tx.update('periodo', datos,
            where: 'id_periodo = ?', whereArgs: [idPeriodo]);
      }

      // ---------- CU04: evaluar viabilidad del ahorro ----------
      if (pmt <= ahorro) {
        await tx.update(
            'periodo',
            {
              'id_estado_financiero': 1, // ALERTA_DEFICIT
              'ahorro_reservado': 0,
              'saldo_disponible': 0,
            },
            where: 'id_periodo = ?',
            whereArgs: [idPeriodo]);
        await tx.insert('alerta', {
          'id_periodo': idPeriodo,
          'id_tipo_alerta': 1, // DEFICIT
          'mensaje':
              'Tu presupuesto mensual no alcanza para cubrir el monto destinado a ahorro.',
          'fecha_hora': fechaHora,
          'atendida': 0,
        });
        await tx.insert('historial_estado_financiero', {
          'id_periodo': idPeriodo,
          'id_estado': 1,
          'fecha_hora': fechaHora,
        });
        return ResultadoConfig.deficit;
      }

      // Hay presupuesto suficiente: se reserva primero el ahorro.
      final saldo = redondear2(pmt - ahorro);

      await tx.update(
          'periodo',
          {
            'ahorro_reservado': ahorro,
            'saldo_disponible': saldo,
            'id_estado_financiero': 2, // SALUDABLE (luego se recalcula)
          },
          where: 'id_periodo = ?',
          whereArgs: [idPeriodo]);

      await tx.insert('movimiento', {
        'id_periodo': idPeriodo,
        'id_tipo_movimiento': 2, // RESERVA_AHORRO
        'monto': ahorro,
        'saldo_anterior': pmt,
        'saldo_posterior': saldo,
        'fecha_hora': fechaHora,
        'descripcion': 'Reserva de ahorro del periodo',
      });

      // Distribución del saldo por categoría.
      // REGLA DEL EQUIPO: primero las suscripciones activas;
      // lo que sobre se reparte 50 % Servicios y 50 % Ocio.
      final sumaSuscripciones = await tx.rawQuery(
          'SELECT COALESCE(SUM(monto), 0) AS total FROM suscripcion '
          'WHERE id_usuario = ? AND activa = 1 AND suspendida = 0',
          [idUsuario]);
      final suscripciones = (sumaSuscripciones.first['total'] as num).toDouble();
      final resto =
          (saldo - suscripciones) < 0 ? 0.0 : redondear2(saldo - suscripciones);
      final servicios = redondear2(resto / 2);
      final ocio = redondear2(resto - servicios);

      await tx.delete('presupuesto_categoria',
          where: 'id_periodo = ?', whereArgs: [idPeriodo]);
      final asignaciones = {1: ahorro, 2: suscripciones, 3: servicios, 4: ocio};
      for (final entrada in asignaciones.entries) {
        await tx.insert('presupuesto_categoria', {
          'id_periodo': idPeriodo,
          'id_categoria': entrada.key,
          'monto_asignado': entrada.value,
          'monto_ejecutado': 0,
        });
      }

      // Historial inicial y recálculo del estado (CU05).
      await tx.insert('historial_estado_financiero', {
        'id_periodo': idPeriodo,
        'id_estado': 2,
        'fecha_hora': fechaHora,
      });
      await ServicioEstado().recalcular(tx, idPeriodo);

      return ResultadoConfig.ok;
    });
  }
}