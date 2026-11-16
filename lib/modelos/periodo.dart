/// Representa un periodo mensual (tabla `periodo`).
class Periodo {
  final int id;
  final int idUsuario;
  final int anio;
  final int mes;
  final double pmt;
  final double ahorroObjetivo;
  final double ahorroReservado;
  final double saldo;
  final int? idEstado;
  final bool cerrado;

  Periodo({
    required this.id,
    required this.idUsuario,
    required this.anio,
    required this.mes,
    required this.pmt,
    required this.ahorroObjetivo,
    required this.ahorroReservado,
    required this.saldo,
    required this.idEstado,
    required this.cerrado,
  });

  /// Convierte una fila de la base de datos en un objeto Periodo.
  factory Periodo.desdeMapa(Map<String, Object?> m) => Periodo(
        id: m['id_periodo'] as int,
        idUsuario: m['id_usuario'] as int,
        anio: m['anio'] as int,
        mes: m['mes'] as int,
        pmt: (m['presupuesto_mensual_total'] as num).toDouble(),
        ahorroObjetivo: (m['ahorro_objetivo'] as num).toDouble(),
        ahorroReservado: (m['ahorro_reservado'] as num).toDouble(),
        saldo: (m['saldo_disponible'] as num).toDouble(),
        idEstado: m['id_estado_financiero'] as int?,
        cerrado: (m['cerrado'] as int) == 1,
      );

  /// El estado 1 es ALERTA_DEFICIT.
  bool get enDeficit => idEstado == 1;

  /// Configurado = tiene estado y no está en déficit.
  bool get configurado => idEstado != null && idEstado != 1;
}