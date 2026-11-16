import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../estado/estado_app.dart';
import '../../servicios/servicio_auth.dart';
import 'pantalla_crear_cuenta.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  String? _error;

  Future<void> _entrar() async {
    final resultado =
        await ServicioAuth().iniciarSesion(_usuario.text, _contrasena.text);
    if (!mounted) return;
    if (resultado == null) {
      setState(() => _error =
          'Usuario o contraseña incorrectos. Verifica tus datos e inténtalo de nuevo.');
    } else {
      context
          .read<EstadoApp>()
          .iniciarSesion(resultado['id'] as int, resultado['nombre'] as String);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Text('PayFlow · Guardián de suscripciones',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                    controller: _usuario,
                    decoration: const InputDecoration(
                        labelText: 'Nombre de usuario *',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: _contrasena,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Contraseña *',
                        border: OutlineInputBorder())),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _entrar, child: const Text('Iniciar sesión')),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PantallaCrearCuenta())),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      );
}