import 'dart:math';
import '../datos/base_datos.dart';
import '../modelos/suscripcion.dart';
import '../utilidades/formato.dart';
import 'servicio_estado.dart';
import 'servicio_periodo.dart';

enum ResultadoCobro { pagado, rechazado, noAplica }

class ServicioSuscripcion {
  // Condición reutilizable: solo periodos abiertos.
  static const _periodosAbiertos =
      'id_periodo IN (SELECT id_periodo FROM periodo WHERE cerrado = 0)';

  /// Fecha de cobro dentro del mes del periodo (si el mes no tiene ese día, usa el último).
  String _fechaCobro(int anio, int mes, int dia) {
    final ultimoDia = DateTime(anio, mes + 1, 0).day;
    return fechaSql(DateTime(anio, mes, min(dia, ultimoDia)));
  }

  // ------------------------- CONSULTAS -------------------------

  Future<List<Suscripcion>> listar(int idUsuario) async {
    final periodo = await ServicioPeriodo().vigente(idUsuario);
    final bd = await BaseDatos.instancia;
    final filas = await bd.rawQuery('''
      SELECT s.*,
             sp.id_suscripcion_periodo AS id_cobro,
             sp.id_estado_suscripcion  AS id_estado_cobro,
             sp.fecha_cobro_programada AS fecha_cobro
      FROM suscripcion s
      LEFT JOIN suscripcion_periodo sp
             ON sp.id_suscripcion = s.id_suscripcion AND sp.id_periodo = ?
      WHERE s.id_usuario = ? AND s.activa = 1
      ORDER BY s.nombre
    ''', [periodo?.id ?? -1, idUsuario]);
    return filas.map(Suscripcion.desdeMapa).toList();
  }

  // ------------------------- CU06: ALTA, EDICIÓN, BAJA -------------------------

  /// Devuelve null si salió bien, o el mensaje de error.
  Future<String?> crear({
    required int idUsuario,
    required String nombre,
    required double monto,
    required int idTipo,
    required int diaCobro,
  }) async {
    final error = _validar(nombre, monto, diaCobro);
    if (error != null) return error;

    final periodo = await ServicioPeriodo().vigente(idUsuario);
    if (periodo == null || !periodo.configurado) {
      return 'Configura primero el periodo en Ajustes para registrar suscripciones.';
    }

    final bd = await BaseDatos.instancia;
    final repetida = await bd.query('suscripcion',
        where: 'id_usuario = ? AND activa = 1 AND LOWER(nombre) = ?',
        whereArgs: [idUsuario, nombre.trim().toLowerCase()]);
    if (repetida.isNotEmpty) return 'Ya tienes una suscripción con ese nombre.';

    final ahora = DateTime.now();
    await bd.transaction((tx) async {
      final idSuscripcion = await tx.insert('suscripcion', {
        'id_usuario': idUsuario,
        'nombre': nombre.trim(),
        'monto': monto,
        'id_tipo_suscripcion': idTipo,
        'dia_cobro': diaCobro,
        'fecha_alta': fechaSql(ahora),
      });
      await tx.insert('suscripcion_periodo', {
        'id_suscripcion': idSuscripcion,
        'id_periodo': periodo.id,
        'monto_cobro': monto,
        'fecha_cobro_programada': _fechaCobro(periodo.anio, periodo.mes, diaCobro),
        'id_estado_suscripcion': 1, // PENDIENTE
      });
      await ServicioEstado().recalcular(tx, periodo.id);
    });
    return null;
  }

  Future<String?> editar({
    required int idUsuario,
    required int id,
    required String nombre,
    required double monto,
    required int idTipo,
    required int diaCobro,
  }) async {
    final error = _validar(nombre, monto, diaCobro);
    if (error != null) return error;

    final bd = await BaseDatos.instancia;
    final repetida = await bd.query('suscripcion',
        where:
            'id_usuario = ? AND activa = 1 AND LOWER(nombre) = ? AND id_suscripcion <> ?',
        whereArgs: [idUsuario, nombre.trim().toLowerCase(), id]);
    if (repetida.isNotEmpty) return 'Ya tienes una suscripción con ese nombre.';

    final periodo = await ServicioPeriodo().vigente(idUsuario);
    await bd.transaction((tx) async {
      await tx.update(
          'suscripcion',
          {
            'nombre': nombre.trim(),
            'monto': monto,
            'id_tipo_suscripcion': idTipo,
            'dia_cobro': diaCobro,
          },
          where: 'id_suscripcion = ?',
          whereArgs: [id]);

      // El cambio aplica solo a cobros que todavía no se han hecho.
      if (periodo != null) {
        await tx.update(
            'suscripcion_periodo',
            {
              'monto_cobro': monto,
              'fecha_cobro_programada':
                  _fechaCobro(periodo.anio, periodo.mes, diaCobro),
            },
            where:
                'id_suscripcion = ? AND id_periodo = ? AND id_estado_suscripcion IN (1, 3)',
            whereArgs: [id, periodo.id]);
        await ServicioEstado().recalcular(tx, periodo.id);
      }
    });
    return null;
  }

  String? _validar(String nombre, double monto, int diaCobro) {
    if (nombre.trim().isEmpty) {
      return 'Completa los campos marcados con * para continuar.';
    }
    if (monto <= 0) return 'El monto debe ser mayor a cero.';
    if (diaCobro < 1 || diaCobro > 31) {
      return 'El día de cobro debe estar entre 1 y 31.';
    }
    return null;
  }

  /// Baja lógica: la suscripción deja de mostrarse y se quitan sus cobros
  /// que no se han realizado. Los cobros ya pagados se conservan en el historial.
  Future<void> eliminar(int id) async {
    final bd = await BaseDatos.instancia;
    await bd.transaction((tx) async {
      await tx.update('suscripcion',
          {'activa': 0, 'fecha_baja': fechaSql(DateTime.now())},
          where: 'id_suscripcion = ?', whereArgs: [id]);

      final cobros = await tx.query('suscripcion_periodo',
          where:
              'id_suscripcion = ? AND id_estado_suscripcion IN (1, 3, 4) AND $_periodosAbiertos',
          whereArgs: [id]);

      for (final cobro in cobros) {
        final idCobro = cobro['id_suscripcion_periodo'] as int;
        await tx.delete('bitacora_estado_suscripcion',
            where: 'id_suscripcion_periodo = ?', whereArgs: [idCobro]);
        await tx.delete('alerta',
            where: 'id_suscripcion_periodo = ?', whereArgs: [idCobro]);
        await tx.update('gasto_variable', {'id_suscripcion_periodo_riesgo': null},
            where: 'id_suscripcion_periodo_riesgo = ?', whereArgs: [idCobro]);
        await tx.delete('suscripcion_periodo',
            where: 'id_suscripcion_periodo = ?', whereArgs: [idCobro]);
      }
      for (final idPeriodo in cobros.map((c) => c['id_periodo'] as int).toSet()) {
        await ServicioEstado().recalcular(tx, idPeriodo);
      }
    });
  }

  // ------------------------- SUSPENDER Y REACTIVAR (solo por decisión del usuario) -------------------------

  Future<void> suspender(int id) async {
    final bd = await BaseDatos.instancia;
    final ahora = fechaHoraSql(DateTime.now());
    await bd.transaction((tx) async {
      await tx.update('suscripcion', {'suspendida': 1},
          where: 'id_suscripcion = ?', whereArgs: [id]);

      final cobros = await tx.query('suscripcion_periodo',
          where:
              'id_suscripcion = ? AND id_estado_suscripcion = 1 AND $_periodosAbiertos',
          whereArgs: [id]);
      for (final cobro in cobros) {
        final idCobro = cobro['id_suscripcion_periodo'] as int;
        await tx.update('suscripcion_periodo', {'id_estado_suscripcion': 4},
            where: 'id_suscripcion_periodo = ?', whereArgs: [idCobro]);
        await tx.insert('bitacora_estado_suscripcion', {
          'id_suscripcion_periodo': idCobro,
          'id_estado_anterior': 1,
          'id_estado_nuevo': 4,
          'fecha_hora': ahora,
          'motivo': 'Suspendida por el usuario',
        });
      }
      for (final idPeriodo in cobros.map((c) => c['id_periodo'] as int).toSet()) {
        await ServicioEstado().recalcular(tx, idPeriodo);
      }
    });
  }

  Future<void> reactivar(int id) async {
    final bd = await BaseDatos.instancia;
    final ahora = fechaHoraSql(DateTime.now());
    await bd.transaction((tx) async {
      await tx.update('suscripcion', {'suspendida': 0},
          where: 'id_suscripcion = ?', whereArgs: [id]);

      final cobros = await tx.query('suscripcion_periodo',
          where:
              'id_suscripcion = ? AND id_estado_suscripcion = 4 AND $_periodosAbiertos',
          whereArgs: [id]);
      for (final cobro in cobros) {
        final idCobro = cobro['id_suscripcion_periodo'] as int;
        await tx.update('suscripcion_periodo', {'id_estado_suscripcion': 1},
            where: 'id_suscripcion_periodo = ?', whereArgs: [idCobro]);
        await tx.insert('bitacora_estado_suscripcion', {
          'id_suscripcion_periodo': idCobro,
          'id_estado_anterior': 4,
          'id_estado_nuevo': 1,
          'fecha_hora': ahora,
          'motivo': 'Reactivada por el usuario',
        });
      }
      for (final idPeriodo in cobros.map((c) => c['id_periodo'] as int).toSet()) {
        await ServicioEstado().recalcular(tx, idPeriodo);
      }
    });
  }

  // ------------------------- CU07: COBRO -------------------------

  /// Cobra un periodo de suscripción (lo usan "Pagar ahora" y el cobro automático).
  /// Todo en una transacción: o se registra completo, o no se registra nada.
  Future<ResultadoCobro> cobrar(int idCobro) async {
    final bd = await BaseDatos.instancia;
    final ahora = fechaHoraSql(DateTime.now());

    return bd.transaction<ResultadoCobro>((tx) async {
      final cobros = await tx.query('suscripcion_periodo',
          where: 'id_suscripcion_periodo = ?', whereArgs: [idCobro]);
      if (cobros.isEmpty) return ResultadoCobro.noAplica;

      final cobro = cobros.first;
      final estadoAnterior = cobro['id_estado_suscripcion'] as int;
      // Solo se cobra lo pendiente o vencido.
      if (estadoAnterior != 1 && estadoAnterior != 3) {
        return ResultadoCobro.noAplica;
      }

      final idPeriodo = cobro['id_periodo'] as int;
      final monto = (cobro['monto_cobro'] as num).toDouble();
      final intentos = (cobro['intentos_cobro'] as int) + 1;

      final periodos = await tx.query('periodo',
          where: 'id_periodo = ?', whereArgs: [idPeriodo]);
      final saldo = (periodos.first['saldo_disponible'] as num).toDouble();

      // ---------- Con saldo suficiente: se cobra ----------
      if (saldo >= monto) {
        final saldoNuevo = redondear2(saldo - monto);

        await tx.update(
            'suscripcion_periodo',
            {
              'id_estado_suscripcion': 2, // PAGADA
              'fecha_cobro_real': ahora,
              'intentos_cobro': intentos,
            },
            where: 'id_suscripcion_periodo = ?',
            whereArgs: [idCobro]);

        await tx.update('periodo', {'saldo_disponible': saldoNuevo},
            where: 'id_periodo = ?', whereArgs: [idPeriodo]);

        await tx.insert('movimiento', {
          'id_periodo': idPeriodo,
          'id_tipo_movimiento': 3, // COBRO_SUSCRIPCION
          'monto': monto,
          'saldo_anterior': saldo,
          'saldo_posterior': saldoNuevo,
          'fecha_hora': ahora,
          'descripcion': 'Cobro de suscripción',
          'id_suscripcion_periodo': idCobro,
        });

        await tx.rawUpdate(
            'UPDATE presupuesto_categoria SET monto_ejecutado = monto_ejecutado + ? '
            'WHERE id_periodo = ? AND id_categoria = 2',
            [monto, idPeriodo]);

        await tx.insert('bitacora_estado_suscripcion', {
          'id_suscripcion_periodo': idCobro,
          'id_estado_anterior': estadoAnterior,
          'id_estado_nuevo': 2,
          'fecha_hora': ahora,
          'motivo': 'Cobro realizado',
        });

        await ServicioEstado().recalcular(tx, idPeriodo);
        return ResultadoCobro.pagado;
      }

      // ---------- Sin saldo: queda vencida y se avisa ----------
      await tx.update(
          'suscripcion_periodo',
          {'id_estado_suscripcion': 3, 'intentos_cobro': intentos}, // VENCIDA
          where: 'id_suscripcion_periodo = ?',
          whereArgs: [idCobro]);

      // La alerta y la bitácora se registran solo la primera vez que falla.
      if (estadoAnterior == 1) {
        final datos = await tx.rawQuery(
            'SELECT s.nombre FROM suscripcion s '
            'JOIN suscripcion_periodo sp ON sp.id_suscripcion = s.id_suscripcion '
            'WHERE sp.id_suscripcion_periodo = ?',
            [idCobro]);
        final nombre = datos.first['nombre'] as String;

        await tx.insert('alerta', {
          'id_periodo': idPeriodo,
          'id_tipo_alerta': 4, // COBRO_RECHAZADO
          'mensaje':
              'No se pudo cobrar "$nombre" (${dinero(monto)}) por saldo insuficiente.',
          'fecha_hora': ahora,
          'atendida': 0,
          'id_suscripcion_periodo': idCobro,
        });
        await tx.insert('bitacora_estado_suscripcion', {
          'id_suscripcion_periodo': idCobro,
          'id_estado_anterior': 1,
          'id_estado_nuevo': 3,
          'fecha_hora': ahora,
          'motivo': 'Cobro rechazado por saldo insuficiente',
        });
      }

      await ServicioEstado().recalcular(tx, idPeriodo);
      return ResultadoCobro.rechazado;
    });
  }

  /// Cobra todas las suscripciones pendientes cuya fecha ya se cumplió.
  /// Se llama al abrir la app y al jalar la lista hacia abajo.
  /// Devuelve cuántos cobros se procesaron.
  Future<int> procesarCobrosPendientes(int idUsuario) async {
    final periodo = await ServicioPeriodo().vigente(idUsuario);
    if (periodo == null || !periodo.configurado) return 0;

    final bd = await BaseDatos.instancia;
    final pendientes = await bd.query('suscripcion_periodo',
        columns: ['id_suscripcion_periodo'],
        where:
            'id_periodo = ? AND id_estado_suscripcion = 1 AND fecha_cobro_programada <= ?',
        whereArgs: [periodo.id, fechaSql(DateTime.now())],
        orderBy: 'fecha_cobro_programada');

    for (final fila in pendientes) {
      await cobrar(fila['id_suscripcion_periodo'] as int);
    }
    return pendientes.length;
  }
}