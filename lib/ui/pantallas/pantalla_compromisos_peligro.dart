import 'package:flutter/material.dart';
import 'package:payflow/servicios/servicio_gasto.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/encabezado.dart';

class PantallaCompromisosPeligro extends StatelessWidget {
  final ResultadoGasto resultado;
  final String concepto;
  final double monto;

  const PantallaCompromisosPeligro({
    super.key,
    required this.resultado,
    required this.concepto,
    required this.monto,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EncabezadoPF(subtitulo: 'Compromisos en peligro', atras: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CajaMensaje(
            nivel: NivelMensaje.aviso,
            titulo: 'Este gasto pone en riesgo tus suscripciones',
            texto:
                'Si registras **$concepto** por **${dinero(monto)}**, tu saldo no alcanzará para cubrir estos cobros pendientes:',
          ),
          TarjetaPF(
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EtiquetaSeccion('Cobros en riesgo'),
                for (final r in resultado.riesgos)
                  FilaDato('${r.nombre} · ${diaYMes(r.fecha)}', dinero(r.monto),
                      colorValor: Colores.rojo),
              ],
            ),
          ),
          TarjetaPF(
            hijo: Column(
              children: [
                FilaDato('Saldo actual', dinero(resultado.saldo)),
                FilaDato('Gasto de Ocio', '-${dinero(monto)}'),
                FilaDato('Saldo restante', dinero(resultado.saldo - monto),
                    colorValor: Colores.ambar),
                FilaDato('Suscripciones pendientes', dinero(resultado.comprometido)),
              ],
            ),
          ),
          BotonPF(
              texto: 'Cancelar gasto', alPresionar: () => Navigator.pop(context, false)),
          const SizedBox(height: 10),
          BotonPF(
              texto: 'Registrar de todos modos',
              tipo: TipoBoton.peligro,
              alPresionar: () => Navigator.pop(context, true)),
        ],
      ),
    );
  }
}