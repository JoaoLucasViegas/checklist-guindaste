import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../data/remote/api.dart';
import '../../domain/catalogo.dart';
import '../auth/sessao.dart';
import 'checklist_edicao_controller.dart';
import 'checklist_itens_page.dart';

class ChecklistFormPage extends StatefulWidget {
  final Catalogo catalogo;
  final String? rascunhoId;
  final bool modoEdicao;
  final bool emCorrecaoSolicitada;
  final String? motivoCorrecao;

  const ChecklistFormPage({
    super.key,
    required this.catalogo,
    this.rascunhoId,
    this.modoEdicao = false,
    this.emCorrecaoSolicitada = false,
    this.motivoCorrecao,
  });

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
      modoEdicao: widget.modoEdicao,
      emCorrecaoSolicitada: widget.emCorrecaoSolicitada,
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
        return _CabecalhoChecklist(controller: controller, motivoCorrecao: widget.motivoCorrecao);
      },
    ),
  );
}

class _CabecalhoChecklist extends StatefulWidget {
  final ChecklistEdicaoController controller;
  final String? motivoCorrecao;
  const _CabecalhoChecklist({required this.controller, this.motivoCorrecao});

  @override
  State<_CabecalhoChecklist> createState() => _CabecalhoChecklistState();
}

class _CabecalhoChecklistState extends State<_CabecalhoChecklist> {
  late final TextEditingController _horimetroInicial;
  late final TextEditingController _combustivel;
  late final TextEditingController _navio;

  ChecklistEdicaoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _horimetroInicial = TextEditingController(
      text: controller.horimetroInicial,
    );
    _combustivel = TextEditingController(
      text: controller.combustivelPct.toString(),
    );
    _navio = TextEditingController(text: controller.navio);
    controller.addListener(_sincronizarSugestao);
  }

  void _sincronizarSugestao() {
    final valor = controller.horimetroInicial;
    if (_horimetroInicial.text != valor) {
      _horimetroInicial.value = TextEditingValue(
        text: valor,
        selection: TextSelection.collapsed(offset: valor.length),
      );
    }
  }

  @override
  void dispose() {
    controller.removeListener(_sincronizarSugestao);
    _horimetroInicial.dispose();
    _combustivel.dispose();
    _navio.dispose();
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

  Future<void> _selecionarHoraEntrada() async {
    final partes = controller.horaEntrada.split(':');
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
    controller.definirHoraEntrada(formatada);
  }

  Future<void> _continuar() async {
    if (!controller.validarCabecalho()) {
      await mostrarDialogoErros(
        context,
        titulo: 'Campos pendentes no cabeçalho',
        erros: controller.errosValidacao,
      );
      return;
    }
    await controller.aguardarSalvamento();
    if (!mounted) return;
    if (controller.erroPersistencia != null) {
      await mostrarDialogoErros(
        context,
        titulo: 'Erro ao salvar rascunho',
        erros: [controller.erroPersistencia!],
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChecklistItensPage(
          controller: controller,
          motivoCorrecao: widget.motivoCorrecao,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItens = controller.catalogo.itens.length;

    return Scaffold(
      backgroundColor: TemaApp.fundo,
      appBar: AppBar(
        title: const Text(
          'PASSO 1/3 · CABEÇALHO',
          style: TextStyle(
            color: TemaApp.ambar,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (controller.errosValidacao.isNotEmpty)
            BarraNotificacaoErro(
              mensagem: controller.errosValidacao.join(' · '),
            )
          else if (controller.erroPersistencia != null)
            BarraNotificacaoErro(mensagem: controller.erroPersistencia!),
          if (controller.emCorrecaoSolicitada &&
              widget.motivoCorrecao != null &&
              widget.motivoCorrecao!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: TemaApp.ambarFundo,
                border: Border(
                  bottom: BorderSide(color: TemaApp.ambarEscuro, width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: TemaApp.ambarEscuro,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Correção solicitada: ${widget.motivoCorrecao}',
                      style: const TextStyle(
                        color: TemaApp.textoPrimario,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: Responsivo.paddingPagina(context),
        child: ContainerResponsivo(
          maxWidth: 820,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Equipamento (largura total, igual à ref image_2634bc.png)
                  _rotulo('Equipamento (Guindaste)'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: controller.equipamentoId,
                    hint: const Text('Selecione o guindaste'),
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

                  // Local + Turno (lado a lado)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rotulo('Local'),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: controller.localId,
                              hint: const Text('Cais'),
                              items: [
                                for (final local in controller.catalogo.locais)
                                  DropdownMenuItem(
                                    value: local.id,
                                    child: Text(local.nome),
                                  ),
                              ],
                              onChanged: controller.selecionarLocal,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rotulo('Turno'),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: controller.turno,
                              items: [
                                for (final valor in controller.catalogo.turnos)
                                  DropdownMenuItem(
                                    value: valor,
                                    child: Text(_rotuloTurno(valor)),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) controller.definirTurno(v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data + Hora Entrada (lado a lado)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rotulo('Data'),
                            InkWell(
                              onTap: _selecionarData,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  suffixIcon: Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  _dataFormatada(controller.dataTurno),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rotulo('Hora Entrada'),
                            InkWell(
                              onTap: _selecionarHoraEntrada,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  suffixIcon: Icon(
                                    Icons.schedule_rounded,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  controller.horaEntrada,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Navio (Opcional)
                  _rotulo('Navio (Opcional)'),
                  TextField(
                    controller: _navio,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Ex.: MV Ocean Carrier',
                    ),
                    onChanged: controller.definirNavio,
                  ),
                  const SizedBox(height: 16),

                  // Horímetro Inicial + Combustível (%) (lado a lado)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rotulo('Horímetro Inicial'),
                            TextField(
                              controller: _horimetroInicial,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [_HorimetroInputFormatter()],
                              decoration: const InputDecoration(
                                hintText: 'Ex.: 36466.1',
                              ),
                              onChanged: controller.definirHorimetroInicial,
                            ),
                            if (controller.buscandoHorimetro) ...[
                              const SizedBox(height: 6),
                              const LinearProgressIndicator(),
                            ],
                            if (controller.sugestaoHorimetro != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: InkWell(
                                  onTap: controller.aplicarSugestaoHorimetro,
                                  child: Text(
                                    'Sugerido do último turno (${controller.sugestaoHorimetro!.toStringAsFixed(1)})',
                                    style: const TextStyle(
                                      color: TemaApp.ambarEscuro,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            if (controller.avisoHorimetro != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  controller.avisoHorimetro!,
                                  style: const TextStyle(
                                    color: TemaApp.perigo,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rotulo('Combustível (%)'),
                            TextField(
                              controller: _combustivel,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                hintText: '0 a 100',
                                suffixText: '%',
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v) ?? 0;
                                controller.definirCombustivel(n.clamp(0, 100));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Banner de erros de validação (se o usuário tentar avançar sem preencher)
                  if (controller.errosValidacao.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TemaApp.perigoFundo,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TemaApp.perigoBorda),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final erro in controller.errosValidacao)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '• $erro',
                                style: const TextStyle(
                                  color: TemaApp.perigo,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  if (controller.erroPersistencia != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      controller.erroPersistencia!,
                      style: const TextStyle(
                        color: TemaApp.perigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // BOTÃO SEMPRE CLICÁVEL (não bloqueia silenciosamente; valida ao tocar)
                  SizedBox(
                    height: 58,
                    child: FilledButton(
                      style: TemaApp.botaoAmbar,
                      onPressed: _continuar,
                      child: Text('Avançar para os $totalItens Itens →'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
        ],
      ),
    );
  }

  Widget _rotulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: TemaApp.textoPrimario,
        ),
      ),
    );
  }
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
  'T_08_14' => '08×14',
  'T_14_20' => '14×20',
  'T_20_02' => '20×02',
  'T_02_08' => '02×08',
  _ => turno,
};

String _dataFormatada(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';
