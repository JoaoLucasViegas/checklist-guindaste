import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../data/remote/api.dart';

class DetalheOperadorPage extends StatefulWidget {
  final String checklistId;
  final VoidCallback? onEditar;

  const DetalheOperadorPage({
    super.key,
    required this.checklistId,
    this.onEditar,
  });

  @override
  State<DetalheOperadorPage> createState() => _DetalheOperadorPageState();
}

class _DetalheOperadorPageState extends State<DetalheOperadorPage> {
  bool _carregando = true;
  String? _erro;
  Map<String, dynamic>? _dados;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resp = await context.read<Api>().detalhe(widget.checklistId);
      if (!mounted) return;
      setState(() {
        _dados = Map<String, dynamic>.from(resp);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_dados?['status'] ?? '').toString().toUpperCase();
    final podeEditar =
        _dados != null && status != 'VISTADO' && widget.onEditar != null;

    return Scaffold(
      backgroundColor: TemaApp.fundo,
      appBar: AppBar(
        title: const Text('Detalhe do Check-List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_erro != null)
            BarraNotificacaoErro(
              mensagem: 'Erro ao carregar detalhe: $_erro',
            ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _dados == null
                ? Center(
                    child: FilledButton.icon(
                      style: TemaApp.botaoAmbar,
                      onPressed: _carregar,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  )
                : _buildConteudo(_dados!),
          ),
        ],
      ),
      bottomNavigationBar: podeEditar
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: TemaApp.superficie,
                  border: Border(top: BorderSide(color: TemaApp.borda)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    style: TemaApp.botaoAmbar,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onEditar?.call();
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(
                      status == 'CORRECAO_SOLICITADA'
                          ? 'Corrigir e reenviar'
                          : 'Editar check-list',
                    ),
                  ),
                ),
              ),
            )
          : status == 'VISTADO'
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: TemaApp.sucessoFundo,
                  border: Border(top: BorderSide(color: TemaApp.sucessoBorda)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: TemaApp.sucesso),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Check-list vistado pela gestão — registro travado.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TemaApp.sucesso,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildConteudo(Map<String, dynamic> d) {
    final ehTablet = Responsivo.ehTablet(context);
    final status = (d['status'] ?? '').toString().toUpperCase();
    final motivo = (d['motivo_correcao'] ?? '').toString().trim();
    final editado = d['editado'] == true;
    final impedido = d['impedido'] == true;
    final eventos = ((d['eventos'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final cardResumo = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _seloStatus(status),
                if (impedido)
                  const SeloStatus(
                    texto: 'IMPEDIDO',
                    icone: Icons.warning_amber_rounded,
                    fundo: TemaApp.perigo,
                    corTexto: Colors.white,
                  ),
                if (editado)
                  const SeloStatus(
                    texto: 'Editado',
                    icone: Icons.edit_outlined,
                    fundo: TemaApp.azulFundo,
                    corTexto: TemaApp.azulAdmin,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${d['equipamento'] ?? '-'} · ${d['local'] ?? '-'}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: TemaApp.textoPrimario,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Turno: ${d['turno'] ?? '-'} · Data: ${d['data_turno'] ?? '-'}',
              style: const TextStyle(
                fontSize: 14,
                color: TemaApp.textoSecundario,
              ),
            ),
            if (d['revisao'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Revisão ${d['revisao']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TemaApp.textoTerciario,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final cardTimeline = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.timeline_rounded, size: 20, color: TemaApp.escuro),
            SizedBox(width: 8),
            Text(
              'Linha do tempo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TemaApp.textoPrimario,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (eventos.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum evento registrado.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (int i = 0; i < eventos.length; i++) ...[
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: TemaApp.azulAdmin,
                    ),
                    title: Text(
                      '${eventos[i]['tipo'] ?? 'Evento'} por ${eventos[i]['autor'] ?? eventos[i]['usuario'] ?? '-'}'
                      '${(eventos[i]['em'] ?? eventos[i]['criado_em']) != null ? ' — ${eventos[i]['em'] ?? eventos[i]['criado_em']}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: (eventos[i]['detalhes'] ?? eventos[i]['motivo']) != null
                        ? Text(
                            (eventos[i]['detalhes'] ?? eventos[i]['motivo'])
                                .toString(),
                          )
                        : null,
                  ),
                  if (i < eventos.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );

    return RefreshIndicator(
      onRefresh: _carregar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Responsivo.paddingPagina(context),
        child: ContainerResponsivo(
          maxWidth: 1040,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status == 'CORRECAO_SOLICITADA' && motivo.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TemaApp.ambarFundo,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TemaApp.ambarEscuro, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: TemaApp.ambarEscuro,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CORREÇÃO SOLICITADA',
                              style: TextStyle(
                                color: TemaApp.ambarEscuro,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              motivo,
                              style: const TextStyle(
                                color: TemaApp.textoPrimario,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (ehTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardResumo),
                    const SizedBox(width: 20),
                    Expanded(child: cardTimeline),
                  ],
                )
              else ...[
                cardResumo,
                const SizedBox(height: 18),
                cardTimeline,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _seloStatus(String status) {
    return switch (status) {
      'VISTADO' => const SeloStatus(
        texto: 'Vistado',
        icone: Icons.verified_outlined,
        fundo: TemaApp.sucessoFundo,
        corTexto: TemaApp.sucesso,
      ),
      'CORRECAO_SOLICITADA' => const SeloStatus(
        texto: 'Correção solicitada',
        icone: Icons.edit_note_rounded,
        fundo: TemaApp.ambarFundo,
        corTexto: TemaApp.ambarEscuro,
      ),
      _ => const SeloStatus(
        texto: 'Enviado',
        icone: Icons.cloud_done_outlined,
        fundo: TemaApp.sucessoFundo,
        corTexto: TemaApp.sucesso,
      ),
    };
  }
}
