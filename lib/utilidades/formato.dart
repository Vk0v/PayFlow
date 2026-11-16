import 'package:intl/intl.dart';

final _formatoDinero = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

/// Convierte 1500 en "$1,500.00".
String dinero(num valor) => _formatoDinero.format(valor);

/// Redondea a 2 decimales para evitar errores de punto flotante.
double redondear2(double valor) => (valor * 100).roundToDouble() / 100;

/// Fecha en formato de base de datos: 2026-11-15
String fechaSql(DateTime fecha) =>
    '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

/// Fecha y hora en formato de base de datos: 2026-11-15 22:50:31
String fechaHoraSql(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${fechaSql(fecha)} ${dos(fecha.hour)}:${dos(fecha.minute)}:${dos(fecha.second)}';
}