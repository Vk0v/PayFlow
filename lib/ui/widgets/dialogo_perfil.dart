import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/servicios/servicio_periodo.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';

Future<void> mostrarPerfil(BuildContext context) async {
  final app = context.read<EstadoApp>();
  final periodo = await ServicioPeriodo.vigente(app.idUsuario!);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => VentanaPF(
      titulo: 'Perfil de auditoría',
      icono: Icons.verified_user_outlined,
      contenido: Column(
        children: [
          FilaDato('Usuario', app.nombreUsuario),
          FilaDato('Periodo', periodo?.textoPeriodo ?? 'Sin configurar'),
          FilaDato('PMT', periodo == null ? '—' : dinero(periodo.pmt)),
          FilaDato('Saldo disponible',
              periodo == null ? '—' : dinero(periodo.saldo)),
          FilaDato('Estado financiero', periodo?.textoEstado ?? 'Sin configurar',
              colorValor: periodo == null ? null : colorEstado(periodo.idEstado)),
        ],
      ),
      acciones: [
        BotonPF(
          texto: 'Aceptar',
          tipo: TipoBoton.verde,
          alPresionar: () => Navigator.pop(ctx),
        ),
        BotonPF(
          texto: 'Cerrar sesión',
          tipo: TipoBoton.secundario,
          alPresionar: () {
            Navigator.pop(ctx);
            Navigator.of(context).popUntil((r) => r.isFirst);
            app.cerrarSesion();
          },
        ),
      ],
    ),
  );
}