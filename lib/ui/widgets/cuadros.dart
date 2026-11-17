import 'package:flutter/material.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';

class VentanaPF extends StatelessWidget {
  final String titulo;
  final IconData? icono;
  final Color colorIcono;
  final Widget contenido;
  final List<Widget> acciones;

  const VentanaPF({
    super.key,
    required this.titulo,
    required this.contenido,
    this.acciones = const [],
    this.icono,
    this.colorIcono = Colores.marino,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icono != null)
                Center(
                  child: IconoCuadro(icono!,
                      color: colorIcono,
                      fondo: colorIcono.withOpacity(0.12),
                      tam: 48),
                ),
              if (icono != null) const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colores.texto),
              ),
              const SizedBox(height: 10),
              contenido,
              const SizedBox(height: 10),
              for (final a in acciones)
                Padding(padding: const EdgeInsets.only(top: 8), child: a),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> mostrarConfirmacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoSi = 'Confirmar',
  String textoNo = 'Cancelar',
  bool peligro = false,
  IconData icono = Icons.help_outline,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => VentanaPF(
      titulo: titulo,
      icono: icono,
      colorIcono: peligro ? Colores.rojo : Colores.marino,
      contenido: textoConNegritas(
        mensaje,
        const TextStyle(fontSize: 14, color: Colores.gris, height: 1.4),
        alineacion: TextAlign.center,
      ),
      acciones: [
        BotonPF(
          texto: textoSi,
          tipo: peligro ? TipoBoton.peligro : TipoBoton.primario,
          alPresionar: () => Navigator.pop(ctx, true),
        ),
        BotonPF(
          texto: textoNo,
          tipo: TipoBoton.secundario,
          alPresionar: () => Navigator.pop(ctx, false),
        ),
      ],
    ),
  );
  return r == true;
}

Future<void> mostrarAviso(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  IconData icono = Icons.check_circle_outline,
  Color color = Colores.verde,
  String textoBoton = 'Aceptar',
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => VentanaPF(
      titulo: titulo,
      icono: icono,
      colorIcono: color,
      contenido: textoConNegritas(
        mensaje,
        const TextStyle(fontSize: 14, color: Colores.gris, height: 1.4),
        alineacion: TextAlign.center,
      ),
      acciones: [
        BotonPF(
          texto: textoBoton,
          tipo: TipoBoton.verde,
          alPresionar: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}