import 'package:payflow/utilidades/formato.dart';

class Periodo {
  final int id;
  final int anio;
  final int mes;
  final String fechaInicio;
  final String fechaFin;
  final double pmt;
  final double ahorroObjetivo;
  final double ahorroReservado;
  final double saldo;
  final int idEstado;
  final bool cerrado;

  const Periodo({
    required this.id,
    required this.anio,
    required this.mes,
    required this.fechaInicio,
    required this.fechaFin,
    required this.pmt,
    required this.ahorroObjetivo,
    required this.ahorroReservado,
    required this.saldo,
    required this.idEstado,
    required this.cerrado,
  });

  factory Periodo.desdeMapa(Map<String, Object?> m) => Periodo(
        id: m['id_periodo'] as int,
        anio: m['anio'] as int,
        mes: m['mes'] as int,
        fechaInicio: m['fecha_inicio'] as String,
        fechaFin: m['fecha_fin'] as String,
        pmt: (m['presupuesto_mensual_total'] as num).toDouble(),
        ahorroObjetivo: (m['ahorro_objetivo'] as num).toDouble(),
        ahorroReservado: (m['ahorro_reservado'] as num).toDouble(),
        saldo: (m['saldo_disponible'] as num).toDouble(),
        idEstado: (m['id_estado_financiero'] as int?) ?? 1,
        cerrado: (m['cerrado'] as int) == 1,
      );

  bool get enDeficit => idEstado == 1;

  /// Lo que ya se gastó: suscripciones cobradas + gastos variables.
  double get gastado => redondear2(pmt - ahorroReservado - saldo);

  String get textoPeriodo => '${nombreMesTitulo(mes)} $anio';

  String get textoEstado {
    switch (idEstado) {
      case 2:
        return 'Saludable';
      case 3:
        return 'En riesgo';
      case 4:
        return 'Crítico';
      default:
        return 'Alerta de déficit';
    }
  }
}