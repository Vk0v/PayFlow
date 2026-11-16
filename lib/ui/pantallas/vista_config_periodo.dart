import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../estado/estado_app.dart';
import '../../modelos/periodo.dart';
import '../../servicios/servicio_periodo.dart';
import '../../utilidades/formato.dart';

class VistaConfigPeriodo extends StatefulWidget {
  final VoidCallback irAlPanel;
  const VistaConfigPeriodo({super.key, required this.irAlPanel});

  @override
  State<VistaConfigPeriodo> createState() => _VistaConfigPeriodoState();
}

class _VistaConfigPeriodoState extends State<VistaConfigPeriodo> {
  final _pmt = TextEditingController();
  final _ahorro = TextEditingController();
  bool _intentado = false; // el usuario ya presionó "Confirmar"
  bool _cargando = true;
  bool _guardando = false;
  Periodo? _periodo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pmt.dispose();
    _ahorro.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final idUsuario = context.read<EstadoApp>().idUsuario!;
    final periodo = await ServicioPeriodo().vigente(idUsuario);
    if (!mounted) return;
    setState(() {
      _periodo = periodo;
      _cargando = false;
    });
  }

  // Valores calculados: se recalculan en cada redibujado.
  double get _pmtValor => double.tryParse(_pmt.text) ?? 0;
  double get _ahorroValor => double.tryParse(_ahorro.text) ?? 0;
  bool get _pmtVacio => _pmt.text.trim().isEmpty;
  bool get _ahorroVacio => _ahorro.text.trim().isEmpty;
  bool get _hayDeficit =>
      !_pmtVacio && !_ahorroVacio && _pmtValor <= _ahorroValor;

  Future<void> _confirmar() async {
    setState(() => _intentado = true);
    if (_pmtVacio || _ahorroVacio || _hayDeficit) return;

    final acepto = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('¿Confirmar configuración del periodo?'),
        content: Text(
          'Presupuesto Mensual Total: ${dinero(_pmtValor)}\n'
          'Ahorro y metas (reserva): ${dinero(_ahorroValor)}\n'
          'Fondos disponibles para gastos: ${dinero(_pmtValor - _ahorroValor)}\n\n'
          'La reserva quedará apartada y no podrá usarse para gastos. '
          'Después se habilitará el registro de gastos.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(contextoDialogo, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(contextoDialogo, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (acepto != true || !mounted) return;

    final estadoApp = context.read<EstadoApp>();
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      final resultado = await ServicioPeriodo().configurar(
          idUsuario: estadoApp.idUsuario!, pmt: _pmtValor, ahorro: _ahorroValor);
      if (!mounted) return;
      estadoApp.notificarCambio();
      if (resultado == ResultadoConfig.ok) {
        widget.irAlPanel();
      } else {
        await _cargar();
      }
    } catch (_) {
      mensajero.showSnackBar(const SnackBar(
          content: Text(
              'No fue posible guardar la información. Intenta nuevamente.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _cancelar() {
    _pmt.clear();
    _ahorro.clear();
    setState(() => _intentado = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final periodo = _periodo;
    if (periodo != null && periodo.configurado) return _resumen(periodo);
    return _formulario();
  }

  // ---------- Periodo ya configurado: solo lectura ----------
  Widget _resumen(Periodo periodo) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Periodo configurado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _fila('Presupuesto Mensual Total', dinero(periodo.pmt)),
                  _fila('Reserva para ahorro y metas',
                      dinero(periodo.ahorroReservado)),
                  _fila('Saldo disponible', dinero(periodo.saldo)),
                ],
              ),
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('Cortes de caja'),
              subtitle: Text('Ver corte del periodo anterior (próximamente)'),
            ),
          ),
        ],
      );

  Widget _fila(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiqueta),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ---------- Formulario de configuración ----------
  Widget _formulario() {
    final faltantes = <String>[
      if (_intentado && _pmtVacio) 'Presupuesto Mensual Total',
      if (_intentado && _ahorroVacio) 'Monto destinado a ahorro y metas',
    ];
    // Solo dígitos y un punto decimal con máximo 2 decimales.
    final soloMontos = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Configuración del periodo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('* Campo obligatorio'),
                const SizedBox(height: 16),
                TextField(
                  controller: _pmt,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: soloMontos,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Presupuesto Mensual Total *',
                    prefixText: '\$ ',
                    border: const OutlineInputBorder(),
                    errorText: (_intentado && _pmtVacio) ? 'Obligatorio' : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ahorro,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: soloMontos,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Monto destinado a ahorro y metas *',
                    prefixText: '\$ ',
                    border: const OutlineInputBorder(),
                    errorText:
                        (_intentado && _ahorroVacio) ? 'Obligatorio' : null,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    _fila('Monto reservado para ahorro', dinero(_ahorroValor)),
                    _fila('Fondos disponibles para gastos',
                        dinero(_pmtValor - _ahorroValor)),
                  ]),
                ),
                if (_hayDeficit) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'Tu presupuesto mensual no alcanza para cubrir el monto '
                      'destinado a ahorro.\nLos gastos están bloqueados mientras '
                      'el presupuesto no alcance para tu ahorro.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                if (faltantes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Campos obligatorios pendientes',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold)),
                        for (final campo in faltantes) Text('• $campo'),
                        const Text(
                            'Completa los campos marcados con * para continuar.'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_hayDeficit || _guardando) ? null : _confirmar,
                  child: _guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Confirmar configuración'),
                ),
                TextButton(onPressed: _cancelar, child: const Text('Cancelar')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}