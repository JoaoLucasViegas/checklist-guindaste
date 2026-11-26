import 'package:material_ui/material_ui.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../domain/modelos.dart';
import 'checklist_edicao_controller.dart';
import 'checklist_finalizacao_page.dart';

class ChecklistItensPage extends StatelessWidget {
  final ChecklistEdicaoController controller;
  final String? motivoCorrecao;
  const ChecklistItensPage({super.key, required this.controller, this.motivoCorrecao});

  Future<void> _confirmarMarcarTudoOk(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.done_all_rounded,
          color: TemaApp.ambarEscuro,
          size: 32,
        ),
        title: const Text('Marcar tudo OK?'),
        content: const Text(
          'Confirmo que inspecionei o equipamento e que todos os itens abaixo '
          'estão OK, exceto os que eu alterar.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: TemaApp.botaoAmbar,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar == true) controller.marcarTudoOk();
  }

  void _responder(BuildContext context, int numero, String valor) {
    controller.responder(numero, valor);
    if (!controller.registrarAlertaImpedimentoExibido()) return;

    final criticos = controller.itensCriticosComProblema;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: TemaApp.perigo,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone circular branco com sinal de PARE (igual à ref image_2634c1.png)
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.dangerous_rounded,
                          color: Color(0xFFEF4444),
                          size: 46,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'EQUIPAMENTO IMPEDIDO DE OPERAR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Foi detectada falha em ${criticos.length} item(ns) crítico(s) de segurança.\n'
                        'A operação está bloqueada até liberação.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFE4E6),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Card translúcido escuro com itens críticos reprovados
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ITENS CRÍTICOS REPROVADOS:',
                              style: TextStyle(
                                color: Color(0xFFFECDD3),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final numItem in criticos)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '#$numItem · ${controller.catalogo.itens.firstWhere((item) => item.numero == numItem).descricao}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: TemaApp.perigo,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Ciente · Continuar'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Voltar e revisar respostas',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final total = controller.respostas.length;
      final progresso = total == 0 ? 0.0 : controller.respondidos / total;
      final temSemResposta = controller.respondidos < total;

      return Scaffold(
        backgroundColor: TemaApp.fundo,
        appBar: AppBar(
          title: Text(
            'PASSO 2/3 · $total ITENS',
            style: const TextStyle(
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
            if (controller.erro != null || controller.erroPersistencia != null)
              BarraNotificacaoErro(
                mensagem: controller.erro ?? controller.erroPersistencia!,
              ),
            // Barra de progresso + Marcar tudo OK
            Container(
              color: TemaApp.superficie,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: ContainerResponsivo(
                maxWidth: 960,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${controller.respondidos}/$total respondidos',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (temSemResposta)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 44),
                              side: const BorderSide(
                                color: TemaApp.ambarEscuro,
                                width: 1.4,
                              ),
                              foregroundColor: TemaApp.ambarEscuro,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            onPressed:
                                controller.finalizado || controller.enviando
                                ? null
                                : () => _confirmarMarcarTudoOk(context),
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text('Marcar tudo OK'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progresso,
                        minHeight: 8,
                        backgroundColor: TemaApp.neutroFundo,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          controller.impedido
                              ? TemaApp.perigo
                              : progresso == 1.0
                              ? TemaApp.sucesso
                              : TemaApp.ambar,
                        ),
                      ),
                    ),
                    if (controller.impedido) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: TemaApp.perigo,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'EQUIPAMENTO IMPEDIDO DE OPERAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
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
            const Divider(height: 1),

            Expanded(
              child: ListView.builder(
                padding: Responsivo.paddingPagina(context),
                itemCount: controller.catalogo.itens.length,
                itemBuilder: (context, index) {
                  final item = controller.catalogo.itens[index];
                  final resposta = controller.respostas[index];
                  return ContainerResponsivo(
                    maxWidth: 960,
                    child: _ItemCard(
                      item: item,
                      resposta: resposta,
                      bloqueado: controller.enviando || controller.finalizado,
                      onResposta: (valor) =>
                          _responder(context, item.numero, valor),
                      onObservacao: (valor) =>
                          controller.definirObservacao(item.numero, valor),
                    ),
                  );
                },
              ),
            ),

            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: TemaApp.superficie,
                border: Border(top: BorderSide(color: TemaApp.borda)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: TemaApp.botaoAmbar,
                    onPressed: controller.enviando || controller.finalizado
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChecklistFinalizacaoPage(
                                controller: controller,
                                motivoCorrecao: motivoCorrecao,
                              ),
                            ),
                          ),
                    child: Text(
                      controller.enviando
                          ? 'Finalizando…'
                          : 'Avançar para Finalização →',
                    ),
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
    final semResposta = resposta.resposta == null;
    final ehProblema = resposta.resposta == 'N';
    final ehOk = resposta.resposta == 'S';

    final borderColor = semResposta
        ? TemaApp.bordaForte
        : ehProblema
        ? TemaApp.perigo
        : ehOk
        ? TemaApp.sucesso
        : TemaApp.neutro;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: ehProblema
            ? TemaApp.perigoFundo.withValues(alpha: 0.45)
            : TemaApp.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor,
            width: ehProblema ? 2 : 1.3,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${item.numero}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ehProblema
                          ? TemaApp.perigo
                          : TemaApp.textoTerciario,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.descricao,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (item.critico) ...[
                    const SizedBox(width: 8),
                    const SeloStatus(
                      texto: 'CRÍTICO',
                      fundo: TemaApp.ambarFundo,
                      corTexto: TemaApp.ambarEscuro,
                      borda: TemaApp.ambarBorda,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _botaoResposta(
                    label: 'S',
                    valor: 'S',
                    icone: Icons.check_rounded,
                    selecionado: resposta.resposta == 'S',
                    cor: TemaApp.sucesso,
                  ),
                  const SizedBox(width: 10),
                  _botaoResposta(
                    label: 'N',
                    valor: 'N',
                    icone: Icons.close_rounded,
                    selecionado: resposta.resposta == 'N',
                    cor: TemaApp.perigo,
                  ),
                  const SizedBox(width: 10),
                  _botaoResposta(
                    label: 'N/A',
                    valor: 'NA',
                    icone: Icons.remove_rounded,
                    selecionado: resposta.resposta == 'NA',
                    cor: TemaApp.neutro,
                  ),
                ],
              ),
              if (resposta.resposta == 'N') ...[
                const SizedBox(height: 14),
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
                    errorText:
                        resposta.observacao == null ||
                            resposta.observacao!.trim().isEmpty
                        ? 'Informe uma observação para esta resposta.'
                        : null,
                  ),
                ),
              ],
              if (resposta.origem == 'LOTE' ||
                  resposta.origem == 'MANUAL') ...[
                const SizedBox(height: 10),
                SeloStatus(
                  texto: resposta.origem == 'LOTE' ? 'lote' : 'manual',
                  fundo: resposta.origem == 'LOTE'
                      ? TemaApp.ambarFundo
                      : TemaApp.neutroFundo,
                  corTexto: resposta.origem == 'LOTE'
                      ? TemaApp.ambarEscuro
                      : TemaApp.textoSecundario,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoResposta({
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
              style: FilledButton.styleFrom(
                backgroundColor: cor,
                foregroundColor: Colors.white,
              ),
            )
          : OutlinedButton.icon(
              onPressed: bloqueado ? null : () => onResposta(valor),
              icon: Icon(icone, color: cor),
              label: Text(label, style: TextStyle(color: cor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cor, width: 1.5),
                minimumSize: const Size(56, 56),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
    ),
  );
}
