import 'package:flutter/material.dart';
import 'vista_config_periodo.dart';

class PantallaAjustes extends StatelessWidget {
  final VoidCallback irAlPanel;
  const PantallaAjustes({super.key, required this.irAlPanel});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [
              Tab(text: 'Metas de ahorro'),
              Tab(text: 'Ajustes y cortes'),
            ]),
            Expanded(
              child: TabBarView(children: [
                const Center(child: Text('Metas de ahorro (CU08 y CU09)')),
                VistaConfigPeriodo(irAlPanel: irAlPanel),
              ]),
            ),
          ],
        ),
      );
}