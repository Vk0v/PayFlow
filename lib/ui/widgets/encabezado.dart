import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/servicios/servicio_alerta.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/pantallas/pantalla_alertas.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/dialogo_perfil.dart';

class EncabezadoPF extends StatefulWidget implements PreferredSizeWidget {
  final String? subtitulo;
  final bool atras;
  const EncabezadoPF({super.key, this.subtitulo, this.atras = false});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 9);

  @override
  State<EncabezadoPF> createState() => _EstadoEncabezado();
}

class _EstadoEncabezado extends State<EncabezadoPF> {
  int _revision = -1;
  int _pendientes = 0;

  Future<void> _cargar(int idUsuario) async {
    final n = await ServicioAlerta.contarPendientes(idUsuario);
    if (mounted) setState(() => _pendientes = n);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<EstadoApp>();
    if (app.revision != _revision && app.idUsuario != null) {
      _revision = app.revision;
      _cargar(app.idUsuario!);
    }
    final inicial =
        app.nombreUsuario.isEmpty ? '?' : app.nombreUsuario[0].toUpperCase();

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      titleSpacing: widget.atras ? 0 : 16,
      leading: widget.atras
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: Row(
        children: [
          const LogoPF(tam: 34),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('PayFlow',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                (widget.subtitulo ?? 'GUARDIÁN').toUpperCase(),
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Colores.gris),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, size: 26),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaAlertas()),
              ),
            ),
            if (_pendientes > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colores.rojo,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: () => mostrarPerfil(context),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colores.marino,
              shape: BoxShape.circle,
              border: Border.all(color: Colores.verde, width: 2),
            ),
            child: Text(inicial,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 14),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Colores.borde),
      ),
    );
  }
}