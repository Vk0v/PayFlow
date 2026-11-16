import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'estado/estado_app.dart';
import 'ui/pantallas/pantalla_inicio.dart';
import 'ui/pantallas/pantalla_login.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => EstadoApp(),
    child: const AplicacionPayFlow(),
  ));
}

class AplicacionPayFlow extends StatelessWidget {
  const AplicacionPayFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final haySesion = context.watch<EstadoApp>().haySesion;
    return MaterialApp(
      title: 'PayFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B7F5C),
        useMaterial3: true,
      ),
      home: haySesion ? const PantallaInicio() : const PantallaLogin(),
    );
  }
}