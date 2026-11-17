import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/alerta.dart';
import 'package:payflow/servicios/servicio_alerta.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';
import 'package:payflow/ui/widgets/encabezado.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _EstadoAlertas();
}

class _EstadoAlertas extends State<PantallaAlertas> {
  Future<List<Alerta>>? _futuro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futuro = ServicioAlerta.listar(context.read<EstadoApp>().idUsuario!);
  }

  Future<void> _atender(int id) async {
    await ServicioAlerta.marcarAtendida(id);
    if (!mounted) return;
    context.read<EstadoApp>().notificarCambio();
    setState(_cargar);
  }

  Future<void> _atenderTodas() async {
    await ServicioAlerta.marcarTodas(context.read<EstadoApp>().idUsuario!);
    if (!mounted) return;
    context.read<EstadoApp>().notificarCambio();
    setState(_cargar);
  }

  IconData _icono(int t) {
    switch (t) {
      case 1:
      case 3:
        return Icons.error_outline;
      case 4:
        return Icons.payments_outlined;
      case 6:
        return Icons.fact_check_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _color(int t) {
    switch (t) {
      case 1:
      case 3:
      case 4:
        return Colores.rojo;
      case 6:
        return Colores.azul;
      default:
        return Colores.ambar;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EncabezadoPF(subtitulo: 'Alertas', atras: true),
      body: FutureBuilder<List<Alerta>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
                padding: const EdgeInsets.all(16),
                child: CajaMensaje(
                    nivel: NivelMensaje.error, texto: 'Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snap.data!;
          final hayPendientes = lista.any((a) => !a.atendida);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No tienes alertas.',
                      style: TextStyle(color: Colores.gris)),
                ),
              if (hayPendientes)
                BotonPF(
                    texto: 'Marcar todas como atendidas',
                    tipo: TipoBoton.secundario,
                    compacto: true,
                    alPresionar: _atenderTodas),
              if (hayPendientes) const SizedBox(height: 12),
              for (final a in lista)
                TarjetaPF(
                  borde: a.atendida ? null : _color(a.idTipo).withOpacity(0.4),
                  hijo: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconoCuadro(_icono(a.idTipo),
                              color: _color(a.idTipo),
                              fondo: _color(a.idTipo).withOpacity(0.12),
                              tam: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.mensaje,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(fechaHoraLarga(a.fechaHora),
                                    style: const TextStyle(
                                        color: Colores.gris, fontSize: 11)),
                              ],
                            ),
                          ),
                          EtiquetaEstado(
                            a.atendida ? 'Atendida' : 'Pendiente',
                            a.atendida ? Colores.verde : Colores.ambar,
                            a.atendida ? Colores.verdeClaro : Colores.ambarClaro,
                          ),
                        ],
                      ),
                      if (!a.atendida)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _atender(a.id),
                            child: const Text('Marcar como atendida'),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}