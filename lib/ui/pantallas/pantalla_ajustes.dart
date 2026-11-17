import 'package:flutter/material.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/pantallas/vista_config_periodo.dart';
import 'package:payflow/ui/pantallas/vista_metas.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _EstadoAjustes();
}

class _EstadoAjustes extends State<PantallaAjustes> {
  int _tab = 0;

  Widget _pastilla(String texto, int i) {
    final sel = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? Colores.marino : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colores.borde),
          ),
          child: Text(texto,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : Colores.texto)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _pastilla('Fondos del periodo', 0),
              const SizedBox(width: 8),
              _pastilla('Metas de ahorro', 1),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [VistaConfigPeriodo(), VistaMetas()],
          ),
        ),
      ],
    );
  }
}