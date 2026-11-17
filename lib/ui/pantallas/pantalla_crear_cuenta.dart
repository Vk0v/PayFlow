import 'package:flutter/material.dart';
import 'package:payflow/servicios/servicio_auth.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/cuadros.dart';

class PantallaCrearCuenta extends StatefulWidget {
  const PantallaCrearCuenta({super.key});

  @override
  State<PantallaCrearCuenta> createState() => _EstadoPantallaCrearCuenta();
}

class _EstadoPantallaCrearCuenta extends State<PantallaCrearCuenta> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _repetir = TextEditingController();
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final u = _usuario.text.trim();
    final c = _clave.text;
    String? error;
    if (u.length < 4) {
      error = 'El usuario debe tener al menos 4 caracteres.';
    } else if (!ServicioAuth.contrasenaValida(c)) {
      error = 'La contraseña debe tener mínimo 8 caracteres, con letras y números.';
    } else if (c != _repetir.text) {
      error = 'Las contraseñas no coinciden.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final r = await ServicioAuth.crearCuenta(u, c);
    if (!mounted) return;
    if (r != null) {
      setState(() {
        _ocupado = false;
        _error = r;
      });
      return;
    }
    await mostrarAviso(context,
        titulo: 'Cuenta creada',
        mensaje: 'Ya puedes iniciar sesión con **$u**.');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const LogoPF(tam: 60),
                  const SizedBox(height: 18),
                  TarjetaPF(
                    relleno: const EdgeInsets.all(20),
                    hijo: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nueva cuenta', style: estiloTitulo),
                        const SizedBox(height: 16),
                        CampoPF(etiqueta: 'Usuario', controlador: _usuario),
                        CampoPF(
                            etiqueta: 'Contraseña',
                            controlador: _clave,
                            oculto: true,
                            hint: 'Mínimo 8 caracteres, letras y números'),
                        CampoPF(
                            etiqueta: 'Repetir contraseña',
                            controlador: _repetir,
                            oculto: true),
                        if (_error != null)
                          CajaMensaje(nivel: NivelMensaje.error, texto: _error!),
                        BotonPF(
                            texto: 'Crear cuenta',
                            ocupado: _ocupado,
                            alPresionar: _crear),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}