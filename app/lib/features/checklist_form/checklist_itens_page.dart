import 'package:material_ui/material_ui.dart';

import '../../domain/modelos.dart';
import 'checklist_edicao_controller.dart';

class ChecklistItensPage extends StatelessWidget {
  final ChecklistEdicaoController controller;
  const ChecklistItensPage({super.key, required this.controller});

  Future<void> _enviar(BuildContext context) async {
    final enviado = await controller.enviar();
    if (!context.mounted) return;
    if (enviado) {
      final impedido = controller.resultadoEnvio?['impedido'] == true;
      final mensagem = impedido
          ? 'Checklist enviado. Equipamento impedido de operar.'
          : 'Checklist enviado com sucesso.';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(mensagem)));
      return;
    }

    if (controller.errosValidacao.isNotEmpty) {
      messengerError(context, controller.errosValidacao);
    }
  }

  void messengerError(BuildContext context, List<String> erros) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(erros.take(3).join('\n'))));
    if (erros.length > 3) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Revise o checklist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [for (final erro in erros) Text('• $erro')],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final respondidos = controller.respostas
          .where((resposta) => resposta.resposta != null)
          .length;
      return Scaffold(
        appBar: AppBar(title: const Text('Itens do checklist')),
        body: Column(
          children: [
            Material(
              elevation: 2,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$respondidos/${controller.respostas.length} respondidos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: controller.respostas.isEmpty
                          ? 0
                          : respondidos / controller.respostas.length,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: controller.catalogo.itens.length,
                itemBuilder: (context, index) {
                  final item = controller.catalogo.itens[index];
                  final resposta = controller.respostas[index];
                  return _ItemCard(
                    item: item,
                    resposta: resposta,
                    bloqueado: controller.enviando || controller.sincronizado,
                    onResposta: (valor) =>
                        controller.responder(item.numero, valor),
                    onObservacao: (valor) =>
                        controller.definirObservacao(item.numero, valor),
                  );
                },
              ),
            ),
            if (controller.erro != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  controller.erro!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (controller.erroPersistencia != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  controller.erroPersistencia!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: controller.enviando || controller.sincronizado
                      ? null
                      : () => _enviar(context),
                  icon: controller.enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    controller.enviando ? 'Enviando…' : 'Enviar checklist',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ItemCard extends StatelessWidget {
  final ItemTemplate item;
  final RespostaItem resposta;
  final bool bloqueado;
  final ValueChanged<String> onResposta;
  final ValueChanged<String> onObservacao;

  const _ItemCard({
    required this.item,
    required this.resposta,
    required this.bloqueado,
    required this.onResposta,
    required this.onObservacao,
  });

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final semResposta = resposta.resposta == null;
    final borderColor = semResposta
        ? cores.outline
        : resposta.resposta == 'N'
        ? cores.error
        : resposta.resposta == 'S'
        ? Colors.green.shade700
        : Colors.blueGrey;

    return CustomPaint(
      foregroundPainter: semResposta ? _BordaTracejada(cores.outline) : null,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: semResposta ? cores.surfaceContainerLow : cores.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: semResposta ? Colors.transparent : borderColor,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 16, child: Text('${item.numero}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        item.descricao,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (item.critico)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(
                        label: Text('CRÍTICO'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Color(0xFFFFE0B2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _botaoResposta(
                    context,
                    label: 'S',
                    valor: 'S',
                    icone: Icons.check,
                    selecionado: resposta.resposta == 'S',
                    cor: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  _botaoResposta(
                    context,
                    label: 'N',
                    valor: 'N',
                    icone: Icons.close,
                    selecionado: resposta.resposta == 'N',
                    cor: cores.error,
                  ),
                  const SizedBox(width: 8),
                  _botaoResposta(
                    context,
                    label: 'N/A',
                    valor: 'NA',
                    icone: Icons.remove,
                    selecionado: resposta.resposta == 'NA',
                    cor: Colors.blueGrey,
                  ),
                ],
              ),
              if (resposta.resposta == 'N') ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('observacao-${item.numero}'),
                  initialValue: resposta.observacao ?? '',
                  minLines: 1,
                  maxLines: 3,
                  enabled: !bloqueado,
                  onChanged: onObservacao,
                  decoration: InputDecoration(
                    labelText: 'Observação (obrigatória)',
                    hintText: 'Descreva o problema encontrado',
                    border: const OutlineInputBorder(),
                    errorText:
                        resposta.observacao == null ||
                            resposta.observacao!.trim().isEmpty
                        ? 'Informe uma observação para esta resposta.'
                        : null,
                  ),
                ),
              ],
              if (resposta.origem == 'LOTE') ...[
                const SizedBox(height: 8),
                const Chip(
                  avatar: Icon(Icons.done_all, size: 18),
                  label: Text('Lote'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoResposta(
    BuildContext context, {
    required String label,
    required String valor,
    required IconData icone,
    required bool selecionado,
    required Color cor,
  }) => Expanded(
    child: SizedBox(
      height: 56,
      child: selecionado
          ? FilledButton.icon(
              onPressed: bloqueado ? null : () => onResposta(valor),
              icon: Icon(icone),
              label: Text(label),
              style: FilledButton.styleFrom(backgroundColor: cor),
            )
          : OutlinedButton.icon(
              onPressed: bloqueado ? null : () => onResposta(valor),
              icon: Icon(icone, color: cor),
              label: Text(label, style: TextStyle(color: cor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cor),
                minimumSize: const Size(56, 56),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
    ),
  );
}

class _BordaTracejada extends CustomPainter {
  final Color color;
  const _BordaTracejada(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(12),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final trecho = metric.extractPath(distance, distance + 6);
        canvas.drawPath(trecho, paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_BordaTracejada oldDelegate) => oldDelegate.color != color;
}
