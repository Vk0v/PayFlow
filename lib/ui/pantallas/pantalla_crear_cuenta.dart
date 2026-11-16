import 'package:flutter/material.dart';
import '../../servicios/servicio_auth.dart';

class PantallaCrearCuenta extends StatefulWidget {
  const PantallaCrearCuenta({super.key});

  @override
  State<PantallaCrearCuenta> createState() => _PantallaCrearCuentaState();
}

class _PantallaCrearCuentaState extends State<PantallaCrearCuenta> {
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  String? _error;

  Future<void> _crear() async {
    final error =
        await ServicioAuth().crearCuenta(_usuario.text, _contrasena.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada. Ahora inicia sesión.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      helperText:
                          'Mínimo 8 caracteres, con al menos una letra y un número.',
                      border: OutlineInputBorder())),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _crear, child: const Text('Crear cuenta')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
            ],
          ),
        ),
      );
}