class Suscripcion {
  final int id;
  final String nombre;
  final double monto;
  final int idTipo;
  final int diaCobro;
  final bool suspendida;
  final bool autocobro;
  final int? idSp; // id de suscripcion_periodo del periodo vigente
  final int? estadoSp; // 1 pendiente, 2 pagada, 3 vencida, 4 suspendida
  final String? fechaProgramada;
  final String? fechaReal;
  final int intentos;

  const Suscripcion({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.idTipo,
    required this.diaCobro,
    required this.suspendida,
    required this.autocobro,
    this.idSp,
    this.estadoSp,
    this.fechaProgramada,
    this.fechaReal,
    this.intentos = 0,
  });

  factory Suscripcion.desdeMapa(Map<String, Object?> m) => Suscripcion(
        id: m['id_suscripcion'] as int,
        nombre: m['nombre'] as String,
        monto: (m['monto'] as num).toDouble(),
        idTipo: m['id_tipo_suscripcion'] as int,
        diaCobro: m['dia_cobro'] as int,
        suspendida: (m['suspendida'] as int) == 1,
        autocobro: (m['autocobro'] as int) == 1,
        idSp: m['id_sp'] as int?,
        estadoSp: m['estado_sp'] as int?,
        fechaProgramada: m['fecha_prog'] as String?,
        fechaReal: m['fecha_real'] as String?,
        intentos: (m['intentos'] as int?) ?? 0,
      );

  String get tipo => idTipo == 1 ? 'Ocio y consumo' : 'Servicios y hogar';
  bool get pagada => !suspendida && estadoSp == 2;
  bool get vencida => !suspendida && estadoSp == 3;
  bool get pendiente => !suspendida && (estadoSp == null || estadoSp == 1);
  bool get puedePagar =>
      !suspendida && idSp != null && (estadoSp == 1 || estadoSp == 3);

  String get textoEstado => suspendida
      ? 'Suspendida'
      : (pagada ? 'Pagada' : (vencida ? 'Vencida' : 'Pendiente'));
}