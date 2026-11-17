class Movimiento {
  final int id;
  final int idTipo;
  final double monto;
  final double saldoAnterior;
  final double saldoPosterior;
  final String fechaHora;
  final String? descripcion;
  final bool esAbono;

  const Movimiento({
    required this.id,
    required this.idTipo,
    required this.monto,
    required this.saldoAnterior,
    required this.saldoPosterior,
    required this.fechaHora,
    required this.descripcion,
    required this.esAbono,
  });

  factory Movimiento.desdeMapa(Map<String, Object?> m) => Movimiento(
        id: m['id_movimiento'] as int,
        idTipo: m['id_tipo_movimiento'] as int,
        monto: (m['monto'] as num).toDouble(),
        saldoAnterior: (m['saldo_anterior'] as num).toDouble(),
        saldoPosterior: (m['saldo_posterior'] as num).toDouble(),
        fechaHora: m['fecha_hora'] as String,
        descripcion: m['descripcion'] as String?,
        esAbono: m['efecto'] == 'A',
      );

  String get tipoTexto {
    switch (idTipo) {
      case 1:
        return 'Asignación del PMT';
      case 2:
        return 'Reserva de ahorro';
      case 3:
        return 'Cobro de suscripción';
      case 4:
        return 'Gasto variable';
      default:
        return 'Reversa';
    }
  }
}