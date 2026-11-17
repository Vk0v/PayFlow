import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/servicios/servicio_corte.dart';
import 'package:payflow/servicios/servicio_suscripcion.dart';
import 'package:payflow/ui/widgets/encabezado.dart';
import 'package:payflow/ui/pantallas/pantalla_ajustes.dart';
import 'package:payflow/ui/pantallas/pantalla_corte.dart';
import 'package:payflow/ui/pantallas/pantalla_gastos.dart';
import 'package:payflow/ui/pantallas/pantalla_panel.dart';
import 'package:payflow/ui/pantallas/pantalla_suscripciones.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _EstadoPantallaInicio();
}

class _EstadoPantallaInicio extends State<PantallaInicio> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arranque());
  }

  /// Al entrar: corte de caja automático (si terminó el mes) y autodébitos.
  Future<void> _arranque() async {
    final app = context.read<EstadoApp>();
    final id = app.idUsuario;
    if (id == null) return;
    final corte = await ServicioCorte.ejecutarSiCorresponde(id);
    await ServicioSuscripcion.procesarAutocobros(id);
    if (!mounted) return;
    app.notificarCambio();
    if (corte != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PantallaCorte(corte: corte)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EncabezadoPF(),
      body: IndexedStack(
        index: _indice,
        children: [
          PantallaPanel(irAjustes: () => setState(() => _indice = 3)),
          const PantallaSuscripciones(),
          const PantallaGastos(),
          const PantallaAjustes(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Panel principal'),
          NavigationDestination(
              icon: Icon(Icons.autorenew),
              selectedIcon: Icon(Icons.autorenew),
              label: 'Suscripciones'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Gastos'),
          NavigationDestination(
              icon: Icon(Icons.tune),
              selectedIcon: Icon(Icons.tune),
              label: 'Ajustes de fondos'),
        ],
      ),
    );
  }
}