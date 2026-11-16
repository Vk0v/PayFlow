import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../estado/estado_app.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_panel.dart';

/// Contenedor principal: barra superior, contenido y barra inferior.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _indice = 0;

  static const _titulos = [
    'Panel principal',
    'Suscripciones',
    'Gastos',
    'Ajustes y fondos',
  ];

  void _irA(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    final nombre = context.watch<EstadoApp>().nombreUsuario;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_indice]),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {}), // CU13: centro de alertas
          PopupMenuButton<String>(
            onSelected: (opcion) {
              if (opcion == 'salir') context.read<EstadoApp>().cerrarSesion();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 8),
              child: CircleAvatar(
                  child: Text(nombre.isEmpty ? '?' : nombre[0].toUpperCase())),
            ),
          ),
        ],
      ),
      // IndexedStack mantiene las 4 secciones vivas al cambiar de pestaña.
      body: IndexedStack(
        index: _indice,
        children: [
          PantallaPanel(irA: _irA),
          const Center(child: Text('Suscripciones (CU06 y CU07)')),
          const Center(child: Text('Gastos (CU10, CU11 y CU12)')),
          PantallaAjustes(irAlPanel: () => _irA(0)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _irA,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Panel'),
          NavigationDestination(
              icon: Icon(Icons.subscriptions_outlined), label: 'Suscripciones'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}