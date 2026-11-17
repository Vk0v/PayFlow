import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payflow/estado/estado_app.dart';
import 'package:payflow/modelos/periodo.dart';
import 'package:payflow/servicios/servicio_panel.dart';
import 'package:payflow/utilidades/formato.dart';
import 'package:payflow/utilidades/tema.dart';
import 'package:payflow/ui/widgets/componentes.dart';

class PantallaPanel extends StatefulWidget {
  final VoidCallback irAjustes;
  const PantallaPanel({super.key, required this.irAjustes});

  @override
  State<PantallaPanel> createState() => _EstadoPanel();
}

class _EstadoPanel extends State<PantallaPanel> {
  Future<DatosPanel>? _futuro;
  int _revisionVista = -1;

  static const _iconos = {
    1: Icons.savings_outlined,
    2: Icons.autorenew,
    3: Icons.bolt_outlined,
    4: Icons.celebration_outlined,
  };

  String _mensajeEstado(int id) {
    switch (id) {
      case 2:
        return 'Tus fondos cubren tus compromisos del mes.';
      case 3:
        return 'Tu saldo es menor al 10 % del PMT. Cuida tus gastos.';
      case 4:
        return 'Tu saldo no cubre tus suscripciones pendientes.';
      default:
        return 'El ahorro objetivo es igual o mayor al PMT. Corrige tus fondos en Ajustes.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<EstadoApp>();
    if (_futuro == null || _revisionVista != app.revision) {
      _revisionVista = app.revision;
      _futuro = ServicioPanel.cargar(app.idUsuario!);
    }
    return RefreshIndicator(
      onRefresh: () async => context.read<EstadoApp>().notificarCambio(),
      child: FutureBuilder<DatosPanel>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              CajaMensaje(
                  nivel: NivelMensaje.error, texto: 'Error: ${snap.error}'),
            ]);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: _contenido(snap.data!));
        },
      ),
    );
  }

  List<Widget> _contenido(DatosPanel d) {
    final p = d.periodo;
    if (p == null) {
      return [
        TarjetaPF(
          hijo: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EtiquetaSeccion('Estado del mes'),
              const EtiquetaEstado('Sin configurar', Colores.gris, Colores.grisClaro),
              const SizedBox(height: 12),
              const Text(
                  'Aún no defines tu presupuesto mensual (PMT) ni tu ahorro objetivo.',
                  style: TextStyle(color: Colores.gris)),
              const SizedBox(height: 14),
              BotonPF(texto: 'Configurar fondos', alPresionar: widget.irAjustes),
            ],
          ),
        ),
      ];
    }
    return [
      _tarjetaEstado(p),
      _tarjetaSaldo(p, d),
      _tarjetaMeta(p, d),
      _tarjetaGastos(p, d),
    ];
  }

  Widget _tarjetaEstado(Periodo p) {
    final color = colorEstado(p.idEstado);
    return TarjetaPF(
      borde: color.withOpacity(0.4),
      fondo: fondoEstado(p.idEstado),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Estado del mes'),
          Row(
            children: [
              Icon(Icons.shield_outlined, color: color),
              const SizedBox(width: 8),
              Text(p.textoEstado,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_mensajeEstado(p.idEstado),
              style: const TextStyle(color: Colores.texto)),
          const SizedBox(height: 6),
          Text('Periodo: ${p.textoPeriodo}',
              style: const TextStyle(color: Colores.gris, fontSize: 12)),
          if (p.enDeficit) ...[
            const SizedBox(height: 12),
            BotonPF(
                texto: 'Ir a Ajustes de fondos',
                compacto: true,
                alPresionar: widget.irAjustes),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaSaldo(Periodo p, DatosPanel d) {
    return TarjetaPF(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Saldo disponible'),
          Text(dinero(p.saldo),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('de ${dinero(p.pmt)} de presupuesto mensual (PMT)',
              style: const TextStyle(color: Colores.gris, fontSize: 12)),
          const SizedBox(height: 12),
          BarraProgreso(
              valor: p.pmt > 0 ? p.saldo / p.pmt : 0,
              color: colorEstado(p.idEstado)),
          if (d.pendientes > 0) ...[
            const SizedBox(height: 14),
            FilaDato('Cobros pendientes',
                '${d.pendientes} · ${dinero(d.comprometido)}'),
            if (d.proximoNombre != null)
              FilaDato('Próximo cobro',
                  '${d.proximoNombre} · ${diaYMes(d.proximaFecha!)}'),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaMeta(Periodo p, DatosPanel d) {
    final v = p.ahorroObjetivo > 0 ? d.aportado / p.ahorroObjetivo : 0.0;
    return TarjetaPF(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Meta de ahorro'),
          Text('${dinero(d.aportado)} de ${dinero(p.ahorroObjetivo)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Aportado a tus metas este periodo',
              style: TextStyle(color: Colores.gris, fontSize: 12)),
          const SizedBox(height: 10),
          BarraProgreso(valor: v, color: Colores.verde),
        ],
      ),
    );
  }

  Widget _tarjetaGastos(Periodo p, DatosPanel d) {
    return TarjetaPF(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Gastos realizados'),
          Text(dinero(p.gastado),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final id in [1, 2, 3, 4]) _filaCategoria(id, d),
        ],
      ),
    );
  }

  Widget _filaCategoria(int id, DatosPanel d) {
    final v = d.categorias[id] ?? [0.0, 0.0];
    final asignado = v[0];
    final ejecutado = v[1];
    final pasado = id != 1 && ejecutado > asignado + 0.001;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconoCuadro(_iconos[id]!, tam: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(nombreCategoria(id),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${dinero(ejecutado)} de ${dinero(asignado)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: pasado ? Colores.rojo : Colores.gris)),
                  ],
                ),
                const SizedBox(height: 6),
                BarraProgreso(
                    valor: asignado > 0 ? ejecutado / asignado : 0,
                    color: pasado ? Colores.rojo : Colores.verde),
              ],
            ),
          ),
        ],
      ),
    );
  }
}