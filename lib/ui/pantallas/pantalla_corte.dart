import 'package:flutter/material.dart';
import 'package:payflow/modelos/corte.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/encabezado.dart';

class PantallaCorte extends StatelessWidget {
  final CorteCaja corte;
  const PantallaCorte({super.key, required this.corte});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EncabezadoPF(subtitulo: 'Corte de caja', atras: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TarjetaPF(
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EtiquetaSeccion('Corte de caja'),
                Text(corte.periodoTexto, style: estiloTitulo),
                Text(fechaHoraLarga(corte.fechaHora),
                    style: const TextStyle(color: Colores.gris, fontSize: 12)),
              ],
            ),
          ),
          TarjetaPF(
            hijo: Column(
              children: [
                FilaDato('Saldo final', dinero(corte.saldoFinal)),
                FilaDato('Total proyectado', dinero(corte.totalProyectado)),
                FilaDato('Total ejecutado', dinero(corte.totalEjecutado)),
                FilaDato('Suscripciones pagadas', '${corte.pagadas}',
                    colorValor: Colores.verde),
                FilaDato('Suscripciones no pagadas', '${corte.noPagadas}',
                    colorValor: corte.noPagadas > 0 ? Colores.rojo : null),
                FilaDato('Ahorro cumplido', corte.ahorroCumplido ? 'Sí' : 'No',
                    colorValor: corte.ahorroCumplido ? Colores.verde : Colores.rojo),
              ],
            ),
          ),
          const EtiquetaSeccion('Reporte de variabilidad'),
          TarjetaPF(
            hijo: Column(
              children: [
                for (final d in corte.detalles)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombreCategoria(d.idCategoria),
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                  'Proyectado ${dinero(d.proyectado)} · Ejecutado ${dinero(d.ejecutado)}',
                                  style: const TextStyle(
                                      color: Colores.gris, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                          '${d.variacion > 0 ? '+' : ''}${dinero(d.variacion)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: d.variacion > 0.001
                                  ? Colores.rojo
                                  : Colores.verde),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const CajaMensaje(
            nivel: NivelMensaje.info,
            texto:
                'Tu periodo se cerró. Configura tus fondos del nuevo periodo en Ajustes de fondos; tus suscripciones activas se reiniciarán como pendientes.',
          ),
          BotonPF(
              texto: 'Entendido', alPresionar: () => Navigator.maybePop(context)),
        ],
      ),
    );
  }
}