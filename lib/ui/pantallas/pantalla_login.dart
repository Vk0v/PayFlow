import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/servicios/servicio_auth.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/pantallas/pantalla_crear_cuenta.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _EstadoPantallaLogin();
}

class _EstadoPantallaLogin extends State<PantallaLogin> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final u = _usuario.text.trim();
    final c = _clave.text;
    if (u.isEmpty || c.isEmpty) {
      setState(() => _error = 'Ingresa tu usuario y contraseña.');
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final id = await ServicioAuth.iniciarSesion(u, c);
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _ocupado = false;
        _error = 'Usuario o contraseña incorrectos.';
      });
      return;
    }
    context.read<EstadoApp>().iniciarSesion(id, u);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const LogoPF(tam: 76),
                  const SizedBox(height: 14),
                  const Text('PayFlow',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text(
                    'GUARDIÁN DE SUSCRIPCIONES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: Colores.gris),
                  ),
                  const SizedBox(height: 28),
                  TarjetaPF(
                    relleno: const EdgeInsets.all(20),
                    hijo: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Iniciar sesión', style: estiloTitulo),
                        const SizedBox(height: 16),
                        CampoPF(
                            etiqueta: 'Usuario',
                            controlador: _usuario,
                            hint: 'Tu nombre de usuario'),
                        CampoPF(
                            etiqueta: 'Contraseña',
                            controlador: _clave,
                            oculto: true,
                            hint: '••••••••'),
                        if (_error != null)
                          CajaMensaje(nivel: NivelMensaje.error, texto: _error!),
                        BotonPF(
                            texto: 'Iniciar sesión',
                            ocupado: _ocupado,
                            alPresionar: _entrar),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PantallaCrearCuenta())),
                    child: const Text('¿No tienes cuenta? Crear cuenta',
                        style: TextStyle(
                            color: Colores.marino, fontWeight: FontWeight.w700)),
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