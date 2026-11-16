/// Una suscripción del usuario junto con el estado de su cobro en el periodo vigente.
class Suscripcion {
  final int id;
  final String nombre;
  final double monto;
  final int idTipo; // 1 = Ocio y consumo, 2 = Servicios y hogar
  final int diaCobro;
  final bool suspendida;
  final int? idCobro; // id en suscripcion_periodo
  final int? idEstadoCobro; // 1 pendiente, 2 pagada, 3 vencida, 4 suspendida
  final String? fechaCobro;

  Suscripcion({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.idTipo,
    required this.diaCobro,
    required this.suspendida,
    required this.idCobro,
    required this.idEstadoCobro,
    required this.fechaCobro,
  });

  factory Suscripcion.desdeMapa(Map<String, Object?> m) => Suscripcion(
        id: m['id_suscripcion'] as int,
        nombre: m['nombre'] as String,
        monto: (m['monto'] as num).toDouble(),
        idTipo: m['id_tipo_suscripcion'] as int,
        diaCobro: m['dia_cobro'] as int,
        suspendida: (m['suspendida'] as int) == 1,
        idCobro: m['id_cobro'] as int?,
        idEstadoCobro: m['id_estado_cobro'] as int?,
        fechaCobro: m['fecha_cobro'] as String?,
      );

  String get textoEstado => switch (idEstadoCobro) {
        1 => 'Pendiente',
        2 => 'Pagada',
        3 => 'Vencida',
        4 => 'Suspendida',
        _ => 'Sin cobro',
      };

  String get textoTipo => idTipo == 1 ? 'Ocio y consumo' : 'Servicios y hogar';

  /// Se puede cobrar si está pendiente o vencida.
  bool get sePuedePagar => idEstadoCobro == 1 || idEstadoCobro == 3;
}