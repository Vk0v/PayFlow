class Alerta {
  final int id;
  final int idTipo;
  final String mensaje;
  final String fechaHora;
  final bool atendida;

  const Alerta({
    required this.id,
    required this.idTipo,
    required this.mensaje,
    required this.fechaHora,
    required this.atendida,
  });

  factory Alerta.desdeMapa(Map<String, Object?> m) => Alerta(
        id: m['id_alerta'] as int,
        idTipo: m['id_tipo_alerta'] as int,
        mensaje: m['mensaje'] as String,
        fechaHora: m['fecha_hora'] as String,
        atendida: (m['atendida'] as int) == 1,
      );
}