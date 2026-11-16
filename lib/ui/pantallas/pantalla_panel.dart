import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../estado/estado_app.dart';
import '../../modelos/periodo.dart';
import '../../servicios/servicio_panel.dart';
import '../../utilidades/formato.dart';

class PantallaPanel extends StatefulWidget {
  final void Function(int) irA;
  const PantallaPanel({super.key, required this.irA});

  @override
  State<PantallaPanel> createState() => _PantallaPanelState();
}

class _PantallaPanelState extends State<PantallaPanel> {
  late Future<DatosPanel> _futuro;
  int _revisionVista = -1;

  /// Etiqueta, mensaje y color según el estado financiero del periodo.
  ({String etiqueta, String mensaje, Color color}) _aspectoEstado(
      Periodo? periodo) {
    switch (periodo?.idEstado) {
      case 1:
        return (
          etiqueta: 'Déficit',
          mensaje: 'Tu presupuesto mensual no alcanza para cubrir el monto '
              'destinado a ahorro. Los gastos están bloqueados.',
          color: Colors.red
        );
      case 2:
        return (
          etiqueta: 'Saludable',
          mensaje: 'Tus finanzas del mes van bien. Sigue así.',
          color: Colors.green
        );
      case 3:
        return (
          etiqueta: 'En Riesgo',
          mensaje: 'Tu saldo libre es menor al 10 % de tu presupuesto mensual. '
              'Cuida tus gastos.',
          color: Colors.orange
        );
      case 4:
        return (
          etiqueta: 'Crítico',
          mensaje: 'Tus suscripciones pendientes superan tu saldo libre. Evita '
              'nuevos gastos de ocio y revisa tus próximos cobros para no '
              'incumplir pagos.',
          color: Colors.red
        );
      default:
        return (
          etiqueta: 'Sin configurar',
          mensaje: 'Completa la configuración del periodo para comenzar.',
          color: Colors.grey
        );
    }
  }

  Widget _tarjeta(Widget contenido, {Color? borde}) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borde ?? Colors.transparent, width: 1.5),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: contenido),
      );

  /// Proporción entre 0 y 1 para las barras de progreso.
  double _proporcion(double parte, double total) =>
      total <= 0 ? 0 : (parte / total).clamp(0.0, 1.0);

  Widget _fila(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(etiqueta), Text(valor)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final estadoApp = context.watch<EstadoApp>();
    // Si los datos cambiaron, se vuelven a consultar.
    if (estadoApp.revision != _revisionVista) {
      _revisionVista = estadoApp.revision;
      _futuro = ServicioPanel().cargar(estadoApp.idUsuario!);
    }

    return FutureBuilder<DatosPanel>(
      future: _futuro,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          return const Center(
              child: Text('No fue posible consultar la información financiera.'));
        }
        if (!instantanea.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final datos = instantanea.data!;
        final periodo = datos.periodo;
        final aspecto = _aspectoEstado(periodo);
        // Solo tiene valor cuando el periodo ya está configurado.
        final cfg = (periodo != null && periodo.configurado) ? periodo : null;

        List<double> categoria(int id) => datos.categorias[id] ?? [0, 0];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Estado del mes ----
            _tarjeta(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado del mes',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(aspecto.etiqueta,
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: aspecto.color,
                  ),
                  Text(aspecto.mensaje),
                  if (periodo == null ||
                      periodo.idEstado == null ||
                      periodo.enDeficit) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: () => widget.irA(3),
                        child: const Text('Configurar el periodo')),
                  ],
                  if (periodo?.idEstado == 3 || periodo?.idEstado == 4) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: () => widget.irA(1),
                        child: const Text('Ver mis suscripciones')),
                  ],
                ],
              ),
              borde: aspecto.color,
            ),

            // ---- Saldo disponible ----
            _tarjeta(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo disponible',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(cfg != null ? dinero(cfg.saldo) : '—',
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold)),
                if (cfg == null)
                  const Text('Aparecerá cuando se configure el PMT.')
                else ...[
                  Text('PMT: ${dinero(cfg.pmt)}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: _proporcion(cfg.saldo, cfg.pmt)),
                  Text('${(_proporcion(cfg.saldo, cfg.pmt) * 100).toStringAsFixed(1)} % '
                      'del presupuesto disponible'),
                ],
              ],
            )),

            if (cfg != null) ...[
              // ---- Meta de ahorro ----
              _tarjeta(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Meta de ahorro',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${dinero(cfg.ahorroReservado)} de ${dinero(cfg.ahorroObjetivo)}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: _proporcion(cfg.ahorroReservado, cfg.ahorroObjetivo)),
                  const Text('Monto reservado con éxito'),
                ],
              )),

              // ---- Gastos realizados ----
              _tarjeta(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gastos realizados',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(dinero(redondear2(cfg.pmt - cfg.ahorroReservado - cfg.saldo)),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: _proporcion(cfg.pmt - cfg.ahorroReservado - cfg.saldo,
                          cfg.pmt - cfg.ahorroReservado)),
                  Text(datos.proximoCobro == null
                      ? 'Sin cobros pendientes'
                      : 'Próximo cobro: ${dinero(datos.proximoCobro!)}'),
                ],
              )),

              // ---- Resumen por categoría ----
              _tarjeta(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen por categoría',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _fila('Suscripciones', '${dinero(categoria(2)[0])} / mes'),
                  _fila('Servicios y hogar',
                      '${dinero(categoria(3)[1])} / ${dinero(categoria(3)[0])}'),
                  _fila('Ocio y consumo',
                      '${dinero(categoria(4)[1])} / ${dinero(categoria(4)[0])}'),
                ],
              )),
            ],
          ],
        );
      },
    );
  }
}