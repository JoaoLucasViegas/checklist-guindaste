import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../data/local/banco_local.dart';
import '../../sync/sincronizador.dart';
import 'checklist_edicao_controller.dart';

class ChecklistFinalizacaoPage extends StatefulWidget {
  final ChecklistEdicaoController controller;

  const ChecklistFinalizacaoPage({super.key, required this.controller});

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
      penStrokeWidth: 3,
      penColor: Colors.black,
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
    if (!mounted || !valido) return;

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
        title: Text(
          status == 'SINCRONIZADO'
              ? 'Enviado'
              : status == 'ERRO_VALIDACAO'
              ? 'Revisão necessária'
              : 'Salvo no aparelho',
        ),
        content: Text(mensagem),
        actions: [
          FilledButton(
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

  String get _ajudaHorimetroFinal {
    final inicial = ChecklistEdicaoController.parseHorimetro(
      controller.horimetroInicial,
    );
    final finalValue = ChecklistEdicaoController.parseHorimetro(
      _horimetroFinal.text,
    );
    if (inicial != null && finalValue != null && finalValue >= inicial) {
      return 'Aumento desde o início: '
          '${(finalValue - inicial).toStringAsFixed(1)} h.';
    }
    return 'Leitura atual. Deve ser igual ou maior que '
        '$_horimetroInicialVisivel.';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Finalização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Resumo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${controller.resumo.lote} em lote · '
            '${controller.resumo.manuais} manuais · '
            '${controller.resumo.problemas} com problema',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (controller.impedido) ...[
            const SizedBox(height: 8),
            const Card(
              color: Color(0xFFB71C1C),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.white),
                title: Text(
                  'EQUIPAMENTO IMPEDIDO DE OPERAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Horímetro inicial deste checklist'),
              subtitle: Text(_horimetroInicialVisivel),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: !controller.enviando,
            controller: _horimetroFinal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_HorimetroFinalInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Horímetro final (obrigatório)',
              suffixText: 'h',
              border: const OutlineInputBorder(),
              helperText: _horimetroFinalMenorQueInicial
                  ? null
                  : _ajudaHorimetroFinal,
              errorText: _horimetroFinalMenorQueInicial
                  ? 'Não pode ser menor que o horímetro inicial.'
                  : null,
            ),
            onChanged: controller.definirHorimetroFinal,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.enviando ? null : _selecionarHoraSaida,
            icon: const Icon(Icons.logout),
            label: Text('Hora de saída: ${controller.horaSaida}'),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: !controller.enviando,
            controller: _observacao,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observação geral (opcional)',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.definirObservacaoGeral,
          ),
          const SizedBox(height: 20),
          Text(
            'Assinatura do operador',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IgnorePointer(
              ignoring: controller.enviando,
              child: Signature(
                controller: _assinatura,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.enviando ? null : _assinatura.clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpar assinatura'),
            ),
          ),
          if (controller.errosValidacao.isNotEmpty ||
              controller.erro != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final erro in controller.errosValidacao)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $erro'),
                      ),
                    if (controller.erro != null)
                      Text(
                        controller.erro!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_erroSincronizacao != null) ...[
            const SizedBox(height: 8),
            Text(
              _erroSincronizacao!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Salvo no aparelho primeiro; o envio ocorre quando houver conexão.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: controller.enviando ? null : _finalizar,
                  icon: controller.enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    controller.enviando ? 'Salvando…' : 'Finalizar e salvar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
