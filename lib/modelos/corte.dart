import 'package:payflow/utilidades/formato.dart';

class DetalleCorte {
  final int idCategoria;
  final double proyectado;
  final double ejecutado;
  final double variacion;

  const DetalleCorte({
    required this.idCategoria,
    required this.proyectado,
    required this.ejecutado,
    required this.variacion,
  });
}

class CorteCaja {
  final int id;
  final String periodoTexto;
  final String fechaHora;
  final double saldoFinal;
  final double totalProyectado;
  final double totalEjecutado;
  final int pagadas;
  final int noPagadas;
  final bool ahorroCumplido;
  final List<DetalleCorte> detalles;

  const CorteCaja({
    required this.id,
    required this.periodoTexto,
    required this.fechaHora,
    required this.saldoFinal,
    required this.totalProyectado,
    required this.totalEjecutado,
    required this.pagadas,
    required this.noPagadas,
    required this.ahorroCumplido,
    required this.detalles,
  });

  static String textoPeriodo(int anio, int mes) => '${nombreMesTitulo(mes)} $anio';
}