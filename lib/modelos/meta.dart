class Meta {
  final int id;
  final String nombre;
  final double objetivo;
  final double acumulado;
  final String? fechaLimite;

  const Meta({
    required this.id,
    required this.nombre,
    required this.objetivo,
    required this.acumulado,
    this.fechaLimite,
  });

  factory Meta.desdeMapa(Map<String, Object?> m) => Meta(
        id: m['id_meta'] as int,
        nombre: m['nombre'] as String,
        objetivo: (m['monto_objetivo'] as num).toDouble(),
        acumulado: (m['monto_acumulado'] as num).toDouble(),
        fechaLimite: m['fecha_limite'] as String?,
      );

  double get progreso => objetivo <= 0 ? 0 : acumulado / objetivo;
  double get faltante => objetivo - acumulado;
}

class Aportacion {
  final int id;
  final double monto;
  final String fecha;

  const Aportacion({required this.id, required this.monto, required this.fecha});

  factory Aportacion.desdeMapa(Map<String, Object?> m) => Aportacion(
        id: m['id_aportacion'] as int,
        monto: (m['monto'] as num).toDouble(),
        fecha: m['fecha_aportacion'] as String,
      );
}