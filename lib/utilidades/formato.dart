import 'package:intl/intl.dart';

String dinero(double v) =>
    NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2)
        .format(v);

double redondear2(double v) => (v * 100).roundToDouble() / 100;

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaSql(DateTime f) => '${f.year}-${_dos(f.month)}-${_dos(f.day)}';

String fechaHoraSql(DateTime f) =>
    '${fechaSql(f)} ${_dos(f.hour)}:${_dos(f.minute)}:${_dos(f.second)}';

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String nombreMes(int m) => _meses[m - 1];

String nombreMesTitulo(int m) {
  final n = nombreMes(m);
  return n[0].toUpperCase() + n.substring(1);
}

String nombreCategoria(int id) {
  switch (id) {
    case 1:
      return 'Ahorro';
    case 2:
      return 'Suscripciones';
    case 3:
      return 'Servicios';
    default:
      return 'Ocio';
  }
}

String fechaLarga(String s) {
  final f = DateTime.parse(s);
  return '${f.day} de ${nombreMes(f.month)} de ${f.year}';
}

String diaYMes(String s) {
  final f = DateTime.parse(s);
  return '${f.day} ${nombreMes(f.month).substring(0, 3)}';
}

String fechaHoraLarga(String s) {
  final f = DateTime.parse(s);
  return '${f.day} de ${nombreMes(f.month)} de ${f.year}, ${_dos(f.hour)}:${_dos(f.minute)}';
}

String fechaCorta(String s) {
  final f = DateTime.parse(s);
  return '${_dos(f.day)}/${_dos(f.month)}/${f.year}';
}

/// Fecha de cobro del mes; si el día no existe (31 en abril) usa el último día.
String fechaDeCobro(int anio, int mes, int dia) {
  final ultimo = DateTime(anio, mes + 1, 0).day;
  return fechaSql(DateTime(anio, mes, dia > ultimo ? ultimo : dia));
}

int diasHasta(String s) {
  final f = DateTime.parse(s);
  final h = DateTime.now();
  return DateTime(f.year, f.month, f.day)
      .difference(DateTime(h.year, h.month, h.day))
      .inDays;
}

String textoDias(int d) {
  if (d == 0) return 'Hoy';
  if (d == 1) return 'Mañana';
  if (d > 1) return 'En $d días';
  if (d == -1) return 'Ayer';
  return 'Hace ${-d} días';
}