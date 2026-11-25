import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/remote/api.dart';
import '../../domain/catalogo.dart';
import '../auth/sessao.dart';
import 'checklist_edicao_controller.dart';
import 'checklist_itens_page.dart';

class ChecklistFormPage extends StatefulWidget {
  final Catalogo catalogo;
  final String? rascunhoId;

  const ChecklistFormPage({super.key, required this.catalogo, this.rascunhoId});

  @override
  State<ChecklistFormPage> createState() => _ChecklistFormPageState();
}

class _ChecklistFormPageState extends State<ChecklistFormPage> {
  late final ChecklistEdicaoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChecklistEdicaoController(
      api: context.read<Api>(),
      catalogo: widget.catalogo,
      usuarioId: context.read<Sessao>().usuarioId!,
      rascunhoId: widget.rascunhoId,
    )..inicializar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _controller,
    child: Consumer<ChecklistEdicaoController>(
      builder: (context, controller, _) {
        if (controller.carregando) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.erro != null && widget.rascunhoId != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rascunho')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(controller.erro!, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        return _CabecalhoChecklist(controller: controller);
      },
    ),
  );
}

class _CabecalhoChecklist extends StatefulWidget {
  final ChecklistEdicaoController controller;
  const _CabecalhoChecklist({required this.controller});

  @override
  State<_CabecalhoChecklist> createState() => _CabecalhoChecklistState();
}

class _CabecalhoChecklistState extends State<_CabecalhoChecklist> {
  late final TextEditingController _horimetroInicial;
  late final TextEditingController _horimetroFinal;
  late final TextEditingController _navio;
  late final TextEditingController _observacao;

  ChecklistEdicaoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _horimetroInicial = TextEditingController(
      text: controller.horimetroInicial,
    );
    _horimetroFinal = TextEditingController(text: controller.horimetroFinal);
    _navio = TextEditingController(text: controller.navio);
    _observacao = TextEditingController(text: controller.observacaoGeral);
    controller.addListener(_sincronizarSugestao);
  }

  void _sincronizarSugestao() {
    final valor = controller.horimetroInicial;
    if (_horimetroInicial.text == valor) return;
    _horimetroInicial.value = TextEditingValue(
      text: valor,
      selection: TextSelection.collapsed(offset: valor.length),
    );
  }

  @override
  void dispose() {
    controller.removeListener(_sincronizarSugestao);
    _horimetroInicial.dispose();
    _horimetroFinal.dispose();
    _navio.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: controller.dataTurno,
      firstDate: DateTime(hoje.year - 2),
      lastDate: DateTime(hoje.year + 2),
    );
    if (data != null) controller.definirData(data);
  }

  Future<void> _selecionarHora({required bool entrada}) async {
    final valor = entrada ? controller.horaEntrada : controller.horaSaida;
    final partes = valor.split(':');
    final hora = await showTimePicker(
      context: context,
      initialTime: partes.length == 2
          ? TimeOfDay(
              hour: int.tryParse(partes[0]) ?? TimeOfDay.now().hour,
              minute: int.tryParse(partes[1]) ?? TimeOfDay.now().minute,
            )
          : TimeOfDay.now(),
    );
    if (hora == null) return;
    final formatada =
        '${hora.hour.toString().padLeft(2, '0')}:'
        '${hora.minute.toString().padLeft(2, '0')}';
    if (entrada) {
      controller.definirHoraEntrada(formatada);
    } else {
      controller.definirHoraSaida(formatada);
    }
  }

  Future<void> _continuar() async {
    if (!controller.validarCabecalho()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.errosValidacao.join('\n'))),
      );
      return;
    }
    await controller.aguardarSalvamento();
    if (!mounted) return;
    if (controller.erroPersistencia != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(controller.erroPersistencia!)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChecklistItensPage(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cabeçalho do checklist')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          controller.catalogo.titulo,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: controller.localId,
          decoration: const InputDecoration(
            labelText: 'Local',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final local in controller.catalogo.locais)
              DropdownMenuItem(value: local.id, child: Text(local.nome)),
          ],
          onChanged: controller.selecionarLocal,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final valor in controller.catalogo.turnos)
              ChoiceChip(
                label: Text(_rotuloTurno(valor)),
                selected: controller.turno == valor,
                onSelected: (_) => controller.definirTurno(valor),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _selecionarData,
          icon: const Icon(Icons.calendar_today),
          label: Text('Data: ${_dataFormatada(controller.dataTurno)}'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: controller.equipamentoId,
          decoration: const InputDecoration(
            labelText: 'Equipamento',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final equipamento in controller.catalogo.equipamentos)
              DropdownMenuItem(
                value: equipamento.id,
                child: Text(equipamento.identificacao),
              ),
          ],
          onChanged: controller.selecionarEquipamento,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _navio,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Navio (opcional)',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.definirNavio,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _horimetroInicial,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_HorimetroInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Horímetro inicial',
            suffixText: 'h',
            border: OutlineInputBorder(),
            helperText: 'Use no máximo uma casa decimal.',
          ),
          onChanged: controller.definirHorimetroInicial,
        ),
        if (controller.buscandoHorimetro) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (controller.sugestaoHorimetro != null) ...[
          TextButton.icon(
            onPressed: controller.aplicarSugestaoHorimetro,
            icon: const Icon(Icons.history),
            label: Text(
              'Usar último horímetro: '
              '${controller.sugestaoHorimetro!.toStringAsFixed(1)}',
            ),
          ),
        ],
        if (controller.avisoHorimetro != null)
          Text(
            controller.avisoHorimetro!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        Text(
          'Combustível: ${controller.combustivelPct}%',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: controller.combustivelPct.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: '${controller.combustivelPct}%',
          onChanged: (valor) => controller.definirCombustivel(valor.round()),
        ),
        OutlinedButton.icon(
          onPressed: () => _selecionarHora(entrada: true),
          icon: const Icon(Icons.login),
          label: Text('Hora de entrada: ${controller.horaEntrada}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _selecionarHora(entrada: false),
          icon: const Icon(Icons.logout),
          label: Text(
            controller.horaSaida.isEmpty
                ? 'Hora de saída (opcional)'
                : 'Hora de saída: ${controller.horaSaida}',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _horimetroFinal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_HorimetroInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Horímetro final (opcional nesta etapa)',
            suffixText: 'h',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.definirHorimetroFinal,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _observacao,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observação geral (opcional)',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.definirObservacaoGeral,
        ),
        if (controller.erroPersistencia != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.erroPersistencia!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: controller.cabecalhoValido ? _continuar : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar para os itens'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

class _HorimetroInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text;
    return RegExp(r'^\d*(?:[.,]\d{0,1})?$').hasMatch(texto)
        ? newValue
        : oldValue;
  }
}

String _rotuloTurno(String turno) => switch (turno) {
  'T_08_14' => '08–14',
  'T_14_20' => '14–20',
  'T_20_02' => '20–02',
  'T_02_08' => '02–08',
  _ => turno,
};

String _dataFormatada(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';
