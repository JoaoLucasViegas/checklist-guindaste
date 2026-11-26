import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../data/local/banco_local.dart';
import '../../sync/sincronizador.dart';
import 'checklist_edicao_controller.dart';

class ChecklistFinalizacaoPage extends StatefulWidget {
  final ChecklistEdicaoController controller;
  final String? motivoCorrecao;

  const ChecklistFinalizacaoPage({super.key, required this.controller, this.motivoCorrecao});

  @override
  State<ChecklistFinalizacaoPage> createState() =>
      _ChecklistFinalizacaoPageState();
}

class _ChecklistFinalizacaoPageState extends State<ChecklistFinalizacaoPage> {
  late final SignatureController _assinatura;
  late final TextEditingController _horimetroFinal;
  late final TextEditingController _observacao;
  String? _erroSincronizacao;

  ChecklistEdicaoController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.prepararFinalizacao();
    _assinatura = SignatureController(
      penStrokeWidth: 3.2,
      penColor: TemaApp.textoPrimario,
    );
    _horimetroFinal = TextEditingController(text: controller.horimetroFinal);
    _observacao = TextEditingController(text: controller.observacaoGeral);
  }

  @override
  void dispose() {
    _assinatura.dispose();
    _horimetroFinal.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _selecionarHoraSaida() async {
    final partes = controller.horaSaida.split(':');
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(partes.first) ?? TimeOfDay.now().hour,
        minute: partes.length > 1
            ? int.tryParse(partes[1]) ?? TimeOfDay.now().minute
            : TimeOfDay.now().minute,
      ),
    );
    if (hora == null) return;
    controller.definirHoraSaida(
      '${hora.hour.toString().padLeft(2, '0')}:'
      '${hora.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _finalizar() async {
    final bytes = _assinatura.isNotEmpty
        ? await _assinatura.toPngBytes()
        : null;
    final assinaturaBase64 = bytes == null ? '' : base64Encode(bytes);
    final valido = await controller.finalizar(assinaturaBase64);
    if (!mounted) return;
    if (!valido) {
      final listaErros = controller.errosValidacao.isNotEmpty
          ? controller.errosValidacao
          : [controller.erro ?? 'Revise os campos obrigatórios.'];
      await mostrarDialogoErros(
        context,
        titulo: 'Não foi possível finalizar',
        erros: listaErros,
      );
      return;
    }

    final sincronizador = context.read<Sincronizador>();
    try {
      await sincronizador.sincronizar();
    } catch (e) {
      _erroSincronizacao = 'Salvo no aparelho, mas a sincronização falhou: $e';
    }

    final registro = await BancoLocal.lerChecklist(controller.id);
    if (!mounted) return;
    final status = registro?['status'] as String?;
    final mensagem = switch (status) {
      'SINCRONIZADO' => 'Checklist enviado com sucesso.',
      'ERRO_VALIDACAO' =>
        'Checklist salvo, mas precisa de correção antes do envio: '
            '${registro?['ultimo_erro'] ?? 'erro de validação'}',
      _ =>
        _erroSincronizacao ??
            'Checklist salvo no aparelho. Aguardando conexão para envio.',
    };

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          status == 'SINCRONIZADO'
              ? Icons.check_circle_outline_rounded
              : status == 'ERRO_VALIDACAO'
              ? Icons.error_outline_rounded
              : Icons.cloud_upload_outlined,
          size: 36,
          color: status == 'SINCRONIZADO'
              ? TemaApp.sucesso
              : status == 'ERRO_VALIDACAO'
              ? TemaApp.perigo
              : TemaApp.ambarEscuro,
        ),
        title: Text(
          status == 'SINCRONIZADO'
              ? 'Checklist enviado'
              : status == 'ERRO_VALIDACAO'
              ? 'Revisão necessária'
              : 'Salvo no aparelho',
        ),
        content: Text(mensagem),
        actions: [
          FilledButton(
            style: TemaApp.botaoAmbar,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String get _horimetroInicialVisivel {
    final inicial = ChecklistEdicaoController.parseHorimetro(
      controller.horimetroInicial,
    );
    return inicial == null ? 'não informado' : '${inicial.toString()} h';
  }

  bool get _horimetroFinalMenorQueInicial {
    final inicial = ChecklistEdicaoController.parseHorimetro(
      controller.horimetroInicial,
    );
    final finalValue = ChecklistEdicaoController.parseHorimetro(
      _horimetroFinal.text,
    );
    return inicial != null && finalValue != null && finalValue < inicial;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final ehTablet = Responsivo.ehTablet(context);

      final blocoDados = Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Encerramento do turno',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Horímetro inicial: $_horimetroInicialVisivel',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TemaApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !controller.enviando,
                controller: _horimetroFinal,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_HorimetroFinalInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Horímetro final (obrigatório)',
                  suffixText: 'h',
                  errorText: _horimetroFinalMenorQueInicial
                      ? 'Não pode ser menor que o horímetro inicial.'
                      : null,
                ),
                onChanged: controller.definirHorimetroFinal,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: controller.enviando ? null : _selecionarHoraSaida,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Hora de saída: ${controller.horaSaida}'),
              ),
              const SizedBox(height: 14),
              TextField(
                enabled: !controller.enviando,
                controller: _observacao,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observação geral (opcional)',
                ),
                onChanged: controller.definirObservacaoGeral,
              ),
            ],
          ),
        ),
      );

      final blocoAssinatura = Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assinatura do operador',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: controller.enviando ? null : _assinatura.clear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Limpar'),
                  ),
                ],
              ),
              if (controller.modoEdicao &&
                  controller.assinaturaExistente != null &&
                  controller.assinaturaExistente!.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'A assinatura original já está registrada e será mantida. Assine abaixo apenas se desejar substituí-la.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TemaApp.sucesso,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                height: ehTablet ? 240 : 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: TemaApp.bordaForte, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: IgnorePointer(
                    ignoring: controller.enviando,
                    child: Signature(
                      controller: _assinatura,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      return Scaffold(
        backgroundColor: TemaApp.fundo,
        appBar: AppBar(
          title: const Text(
            'PASSO 3/3 · FINALIZAÇÃO',
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
            else if (controller.erro != null || _erroSincronizacao != null)
              BarraNotificacaoErro(
                mensagem: controller.erro ?? _erroSincronizacao!,
              ),
            if (controller.emCorrecaoSolicitada &&
                widget.motivoCorrecao != null &&
                widget.motivoCorrecao!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: TemaApp.ambarFundo,
                  border: Border(
                    bottom: BorderSide(color: TemaApp.ambarEscuro, width: 1.5),
                  ),
                ),
                child: Text(
                  'Correção solicitada: ${widget.motivoCorrecao}',
                  style: const TextStyle(
                    color: TemaApp.textoPrimario,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: Responsivo.paddingPagina(context),
          child: ContainerResponsivo(
            maxWidth: 1040,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _metricaResumo(
                        'Em lote',
                        '${controller.resumo.lote}',
                        TemaApp.ambarEscuro,
                        TemaApp.ambarFundo,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricaResumo(
                        'Manuais',
                        '${controller.resumo.manuais}',
                        TemaApp.sucesso,
                        TemaApp.sucessoFundo,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricaResumo(
                        'Problemas',
                        '${controller.resumo.problemas}',
                        controller.resumo.problemas > 0
                            ? TemaApp.perigo
                            : TemaApp.neutro,
                        controller.resumo.problemas > 0
                            ? TemaApp.perigoFundo
                            : TemaApp.neutroFundo,
                      ),
                    ),
                  ],
                ),
                if (controller.impedido) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: TemaApp.perigo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'EQUIPAMENTO IMPEDIDO DE OPERAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (ehTablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: blocoDados),
                      const SizedBox(width: 16),
                      Expanded(child: blocoAssinatura),
                    ],
                  )
                else ...[
                  blocoDados,
                  const SizedBox(height: 16),
                  blocoAssinatura,
                ],
                if (controller.errosValidacao.isNotEmpty ||
                    controller.erro != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: TemaApp.perigoFundo,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TemaApp.perigoBorda),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final erro in controller.errosValidacao)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $erro',
                              style: const TextStyle(
                                color: TemaApp.perigo,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (controller.erro != null)
                          Text(
                            controller.erro!,
                            style: const TextStyle(
                              color: TemaApp.perigo,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Salvo no aparelho primeiro; o envio ocorre automaticamente quando houver conexão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: TemaApp.textoSecundario,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: TemaApp.botaoAmbar,
                    onPressed: controller.enviando ? null : _finalizar,
                    child: Text(
                      controller.enviando
                          ? 'Salvando…'
                          : controller.emCorrecaoSolicitada
                          ? 'Confirmo as correções'
                          : controller.modoEdicao
                          ? 'Salvar alterações'
                          : 'Finalizar e Salvar',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _metricaResumo(String rotulo, String valor, Color cor, Color fundo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HorimetroFinalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return RegExp(r'^\d*(?:[.,]\d{0,1})?$').hasMatch(newValue.text)
        ? newValue
        : oldValue;
  }
}
