import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/movimiento.dart';
import 'package:payflow/servicios/servicio_gasto.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/encabezado.dart';

class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});

  @override
  State<PantallaHistorial> createState() => _EstadoHistorial();
}

class _EstadoHistorial extends State<PantallaHistorial> {
  FiltroMovimientos _filtro = FiltroMovimientos.todos;
  Future<List<Movimiento>>? _futuro;

  static const _filtros = {
    FiltroMovimientos.todos: 'Todos',
    FiltroMovimientos.asignaciones: 'Asignaciones',
    FiltroMovimientos.cobros: 'Cobros',
    FiltroMovimientos.gastos: 'Gastos',
  };

  static const _iconos = {
    1: Icons.account_balance_wallet_outlined,
    2: Icons.savings_outlined,
    3: Icons.autorenew,
    4: Icons.shopping_bag_outlined,
    5: Icons.undo,
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futuro = ServicioGasto.historial(
        context.read<EstadoApp>().idUsuario!, _filtro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EncabezadoPF(subtitulo: 'Historial', atras: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final e in _filtros.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _filtro == e.key,
                  selectedColor: Colores.marino,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                      color: _filtro == e.key ? Colors.white : Colores.texto,
                      fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() {
                    _filtro = e.key;
                    _cargar();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Movimiento>>(
            future: _futuro,
            builder: (context, snap) {
              if (snap.hasError) {
                return CajaMensaje(
                    nivel: NivelMensaje.error, texto: 'Error: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              final lista = snap.data!;
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Aún no hay movimientos.',
                      style: TextStyle(color: Colores.gris)),
                );
              }
              return Column(
                children: [
                  for (final m in lista)
                    TarjetaPF(
                      separacion: 8,
                      relleno: const EdgeInsets.all(12),
                      hijo: Row(
                        children: [
                          IconoCuadro(_iconos[m.idTipo] ?? Icons.swap_horiz,
                              tam: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.descripcion ?? m.tipoTexto,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(fechaHoraLarga(m.fechaHora),
                                    style: const TextStyle(
                                        color: Colores.gris, fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${m.esAbono ? '+' : '-'}${dinero(m.monto)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: m.esAbono ? Colores.verde : Colores.rojo),
                              ),
                              Text('Saldo ${dinero(m.saldoPosterior)}',
                                  style: const TextStyle(
                                      color: Colores.gris, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}