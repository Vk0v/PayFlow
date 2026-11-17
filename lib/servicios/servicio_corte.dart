import 'package:sqflite/sqflite.dart';
import 'package:payflow/datos/base_datos.dart';
import 'package:payflow/modelos/corte.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/servicios/servicio_estado.dart';

class ServicioCorte {
  /// Cierra el periodo abierto si ya terminó el mes (o si se fuerza, para la demo).
  static Future<CorteCaja?> ejecutarSiCorresponde(int idUsuario,
      {bool forzar = false}) async {
    final db = await BaseDatos.abrir();
    final idCorte = await db.transaction<int?>((txn) async {
      final f = await txn.query('periodo',
          where: 'id_usuario = ? AND cerrado = 0',
          whereArgs: [idUsuario],
          orderBy: 'id_periodo DESC',
          limit: 1);
      if (f.isEmpty) return null;
      final p = Periodo.desdeMapa(f.first);
      if (!forzar && fechaSql(DateTime.now()).compareTo(p.fechaFin) <= 0) {
        return null;
      }

      await ServicioEstado.recalcular(txn, p.id);
      final c = await txn.rawQuery(
        'SELECT SUM(CASE WHEN id_estado_suscripcion = 2 THEN 1 ELSE 0 END) AS pag, '
        'SUM(CASE WHEN id_estado_suscripcion IN (1,3) THEN 1 ELSE 0 END) AS nopag '
        'FROM suscripcion_periodo WHERE id_periodo = ?',
        [p.id],
      );
      final pagadas = (c.first['pag'] as num?)?.toInt() ?? 0;
      final noPagadas = (c.first['nopag'] as num?)?.toInt() ?? 0;
      final ahora = fechaHoraSql(DateTime.now());
      final cumplido = p.ahorroObjetivo > 0 && p.ahorroReservado >= p.ahorroObjetivo;

      final id = await txn.insert('corte_caja', {
        'id_periodo': p.id,
        'fecha_hora': ahora,
        'saldo_final': p.saldo,
        'total_proyectado': p.pmt,
        'total_ejecutado': p.gastado,
        'suscripciones_pagadas': pagadas,
        'suscripciones_no_pagadas': noPagadas,
        'ahorro_cumplido': cumplido ? 1 : 0,
      });
      final pres = await txn.query('presupuesto_categoria',
          where: 'id_periodo = ?', whereArgs: [p.id], orderBy: 'id_categoria');
      for (final r in pres) {
        final proy = (r['monto_asignado'] as num).toDouble();
        final ej = (r['monto_ejecutado'] as num).toDouble();
        await txn.insert('reporte_variabilidad_detalle', {
          'id_corte': id,
          'id_categoria': r['id_categoria'],
          'monto_proyectado': proy,
          'monto_ejecutado': ej,
          'variacion': redondear2(ej - proy),
        });
      }
      await txn.update('periodo', {'cerrado': 1},
          where: 'id_periodo = ?', whereArgs: [p.id]);
      await txn.insert('alerta', {
        'id_periodo': p.id,
        'id_tipo_alerta': 6,
        'mensaje': 'Corte de caja ejecutado: ${p.textoPeriodo}',
        'fecha_hora': ahora,
        'atendida': 0,
      });
      return id;
    });
    if (idCorte == null) return null;
    return _cargar(db, idCorte);
  }

  static Future<CorteCaja?> ultimo(int idUsuario) async {
    final db = await BaseDatos.abrir();
    final f = await db.rawQuery(
      'SELECT c.id_corte AS id FROM corte_caja c '
      'JOIN periodo p ON p.id_periodo = c.id_periodo '
      'WHERE p.id_usuario = ? ORDER BY c.id_corte DESC LIMIT 1',
      [idUsuario],
    );
    if (f.isEmpty) return null;
    return _cargar(db, f.first['id'] as int);
  }

  static Future<CorteCaja?> _cargar(DatabaseExecutor ex, int idCorte) async {
    final f = await ex.rawQuery(
      'SELECT c.*, p.anio AS anio, p.mes AS mes FROM corte_caja c '
      'JOIN periodo p ON p.id_periodo = c.id_periodo WHERE c.id_corte = ?',
      [idCorte],
    );
    if (f.isEmpty) return null;
    final c = f.first;
    final d = await ex.query('reporte_variabilidad_detalle',
        where: 'id_corte = ?', whereArgs: [idCorte], orderBy: 'id_categoria');
    return CorteCaja(
      id: idCorte,
      periodoTexto: CorteCaja.textoPeriodo(c['anio'] as int, c['mes'] as int),
      fechaHora: c['fecha_hora'] as String,
      saldoFinal: (c['saldo_final'] as num).toDouble(),
      totalProyectado: (c['total_proyectado'] as num).toDouble(),
      totalEjecutado: (c['total_ejecutado'] as num).toDouble(),
      pagadas: c['suscripciones_pagadas'] as int,
      noPagadas: c['suscripciones_no_pagadas'] as int,
      ahorroCumplido: (c['ahorro_cumplido'] as int) == 1,
      detalles: d
          .map((r) => DetalleCorte(
                idCategoria: r['id_categoria'] as int,
                proyectado: (r['monto_proyectado'] as num).toDouble(),
                ejecutado: (r['monto_ejecutado'] as num).toDouble(),
                variacion: (r['variacion'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}