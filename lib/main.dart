import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'estado/estado_app.dart';
import 'ui/pantallas/pantalla_inicio.dart';
import 'ui/pantallas/pantalla_login.dart';
import 'utilidades/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(ChangeNotifierProvider(
    create: (_) => EstadoApp(),
    child: const PayFlowApp(),
  ));
}

class PayFlowApp extends StatelessWidget {
  const PayFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayFlow',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: Consumer<EstadoApp>(
        builder: (context, app, _) =>
            app.haySesion ? const PantallaInicio() : const PantallaLogin(),
      ),
    );
  }
}