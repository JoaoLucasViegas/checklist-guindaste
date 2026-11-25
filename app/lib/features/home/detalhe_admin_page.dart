import 'dart:convert';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/remote/api.dart';

class DetalheAdminPage extends StatefulWidget {
  final String checklistId;

  const DetalheAdminPage({super.key, required this.checklistId});

  @override
  State<DetalheAdminPage> createState() => _DetalheAdminPageState();
}

class _DetalheAdminPageState extends State<DetalheAdminPage> {
  bool _carregando = true;
  bool _processandoAcao = false;
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
      final api = context.read<Api>();
      final resp = await api.detalhe(widget.checklistId);
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

  Future<void> _vistar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar visto'),
        content: const Text(
          'Ao vistar, este checklist será travado e o operador não poderá mais editá-lo. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vistar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processandoAcao = true);
    try {
      await context.read<Api>().vistar(widget.checklistId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist vistado e travado.')),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao vistar: $e')),
      );
    } finally {
      if (mounted) setState(() => _processandoAcao = false);
    }
  }

  Future<void> _solicitarCorrecao() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar correção'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Motivo (obrigatório)',
              hintText: 'Descreva o que o operador precisa corrigir...',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Informe o motivo da correção.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (motivo == null || motivo.isEmpty || !mounted) return;

    setState(() => _processandoAcao = true);
    try {
      await context.read<Api>().solicitarCorrecao(widget.checklistId, motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correção solicitada ao operador.')),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao solicitar correção: $e')),
      );
    } finally {
      if (mounted) setState(() => _processandoAcao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Erro ao carregar detalhe:\n$_erro',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _carregar,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildConteudo(_dados!),
      bottomNavigationBar: (_dados == null || _carregando)
          ? null
          : _buildRodape(_dados!),
    );
  }

  Widget _buildConteudo(Map<String, dynamic> d) {
    final itensBrutos = ((d['itens'] ?? d['respostas']) as List?) ?? const [];
    final itens = itensBrutos
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final itensProblema = itens.where((i) {
      final resp = (i['resposta'] ?? i['status'] ?? '').toString().toUpperCase();
      return resp == 'N' || resp == 'NAO' || resp == 'PROBLEMA';
    }).toList();

    final itensOk = itens.where((i) {
      final resp = (i['resposta'] ?? i['status'] ?? '').toString().toUpperCase();
      return resp != 'N' && resp != 'NAO' && resp != 'PROBLEMA';
    }).toList();

    final qtdCriticos = itensProblema.where((i) => i['critico'] == true).length;
    final impedido = d['impedido'] == true || qtdCriticos > 0;

    final obsGeral = (d['observacao_geral'] ?? d['observacao'] ?? '').toString().trim();
    final assinaturaB64 = (d['assinatura_base64'] ?? d['assinatura'] ?? '').toString().trim();
    final eventosBrutos = (d['eventos'] as List?) ?? const [];
    final eventos = eventosBrutos
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 1. Faixa de resumo
          _buildFaixaResumo(
            qtdOk: itensOk.length,
            qtdProblema: itensProblema.length,
            qtdCriticos: qtdCriticos,
            impedido: impedido,
          ),
          const SizedBox(height: 12),

          // 2. Cabeçalho completo
          _buildCabecalho(d),
          const SizedBox(height: 12),

          // 3. Itens com problema no topo (em vermelho)
          if (itensProblema.isNotEmpty) ...[
            _tituloSecao(
              'Itens com problema (${itensProblema.length})',
              cor: Colors.red.shade800,
            ),
            const SizedBox(height: 6),
            ...itensProblema.map(_buildCardItemProblema),
            const SizedBox(height: 12),
          ],

          // 4. Todos os itens OK logo abaixo (já abertos)
          _tituloSecao('Itens OK (${itensOk.length})'),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < itensOk.length; i++) ...[
                  _buildLinhaItemOk(itensOk[i]),
                  if (i < itensOk.length - 1) const Divider(height: 1),
                ],
                if (itensOk.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum item OK.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Observação geral
          _tituloSecao('Observação geral'),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                obsGeral.isEmpty ? 'Sem observação geral.' : obsGeral,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 6. Assinatura do operador
          _tituloSecao('Assinatura do operador'),
          const SizedBox(height: 6),
          _buildAssinatura(assinaturaB64),
          const SizedBox(height: 12),

          // 7. Metadados
          _tituloSecao('Metadados do preenchimento'),
          const SizedBox(height: 6),
          _buildMetadados(d, itens),
          const SizedBox(height: 12),

          // 8. Linha do tempo (eventos)
          _tituloSecao('Linha do tempo'),
          const SizedBox(height: 6),
          _buildLinhaDoTempo(eventos),
        ],
      ),
    );
  }

  Widget _buildFaixaResumo({
    required int qtdOk,
    required int qtdProblema,
    required int qtdCriticos,
    required bool impedido,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: impedido ? Colors.red.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: impedido ? Colors.red.shade400 : Colors.indigo.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$qtdOk OK · $qtdProblema com problema · $qtdCriticos crítico${qtdCriticos == 1 ? '' : 's'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: impedido ? Colors.red.shade900 : Colors.indigo.shade900,
              ),
            ),
          ),
          if (impedido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'IMPEDIDO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCabecalho(Map<String, dynamic> d) {
    final operadorMap = d['operador'] as Map?;
    final operador = operadorMap?['nome'] ?? d['operador_nome'] ?? '-';
    final horimetroIni = d['horimetro_inicial'] ?? d['horimetro_motor_inicial'] ?? '-';
    final horimetroFim = d['horimetro_final'] ?? d['horimetro_motor_final'] ?? '-';
    final combustivel = d['combustivel'] ?? d['nivel_combustivel'] ?? '-';
    final entrada = d['hora_entrada'] ?? d['entrada'] ?? '-';
    final saida = d['hora_saida'] ?? d['saida'] ?? '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cabeçalho',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Divider(),
            _linhaInfo('Operador', '$operador'),
            _linhaInfo('Equipamento', '${d['equipamento'] ?? '-'}'),
            _linhaInfo('Local / Cais', '${d['local'] ?? '-'}'),
            _linhaInfo('Navio', '${d['navio'] ?? '-'}'),
            _linhaInfo('Turno / Data', '${d['turno'] ?? '-'} • ${d['data_turno'] ?? '-'}'),
            _linhaInfo('Horímetros', 'Inicial: $horimetroIni • Final: $horimetroFim'),
            _linhaInfo('Combustível', '$combustivel'),
            _linhaInfo('Entrada / Saída', '$entrada / $saida'),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItemProblema(Map<String, dynamic> item) {
    final ordem = item['ordem'] ?? item['numero'] ?? '';
    final titulo = item['titulo'] ?? item['descricao'] ?? 'Item';
    final critico = item['critico'] == true;
    final obs = (item['observacao'] ?? '').toString().trim();

    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.red.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ordem.toString().isNotEmpty ? '$ordem. ' : ''}$titulo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                if (critico)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CRÍTICO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (obs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Obs: $obs',
                style: TextStyle(color: Colors.red.shade900),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaItemOk(Map<String, dynamic> item) {
    final ordem = item['ordem'] ?? item['numero'] ?? '';
    final titulo = item['titulo'] ?? item['descricao'] ?? 'Item';
    final origem = (item['origem'] ??
            (item['marcado_em_lote'] == true || item['lote'] == true
                ? 'lote'
                : 'manual'))
        .toString()
        .toLowerCase();
    final ehLote = origem == 'lote';

    return ListTile(
      dense: true,
      leading: Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
      title: Text('${ordem.toString().isNotEmpty ? '$ordem. ' : ''}$titulo'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: ehLote ? Colors.indigo.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          ehLote ? 'lote' : 'manual',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ehLote ? Colors.indigo.shade900 : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildAssinatura(String assinaturaB64) {
    Uint8List? bytes;
    if (assinaturaB64.isNotEmpty) {
      try {
        final limpo = assinaturaB64.contains(',')
            ? assinaturaB64.split(',').last
            : assinaturaB64;
        bytes = base64Decode(limpo);
      } catch (_) {
        bytes = null;
      }
    }

    return Card(
      child: Container(
        height: 140,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.contain)
            : const Text('Sem assinatura registrada.'),
      ),
    );
  }

  Widget _buildMetadados(Map<String, dynamic> d, List itens) {
    final inicio = d['iniciado_em'] ?? d['inicio_preenchimento'] ?? '-';
    final fim = d['finalizado_em'] ?? d['fim_preenchimento'] ?? '-';

    int? segundos;
    final rawTempo = d['tempo_preenchimento_seg'] ?? d['duracao_segundos'];
    if (rawTempo is int) {
      segundos = rawTempo;
    } else if (rawTempo is num) {
      segundos = rawTempo.toInt();
    }

    final usouLote = d['usou_lote'] == true;
    final qtdLote = d['qtd_itens_lote'] ??
        itens
            .where((i) =>
                i['marcado_em_lote'] == true ||
                i['lote'] == true ||
                (i['origem']?.toString().toLowerCase() == 'lote'))
            .length;

    final tempoTexto = segundos == null
        ? '-'
        : segundos < 60
            ? '${segundos}s'
            : '${segundos ~/ 60}min ${segundos % 60}s';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linhaInfo('Início', '$inicio'),
            _linhaInfo('Fim', '$fim'),
            _linhaInfo('Tempo total', tempoTexto),
            if (segundos != null && segundos < 60)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  '⚠ preenchido em menos de 1 min',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            _linhaInfo(
              'Preenchimento em lote',
              usouLote ? 'Sim ($qtdLote itens)' : 'Não',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaDoTempo(List eventos) {
    if (eventos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Nenhum evento registrado.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < eventos.length; i++) ...[
            _buildItemEvento(eventos[i]),
            if (i < eventos.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildItemEvento(Map<String, dynamic> ev) {
    final tipo = (ev['tipo'] ?? ev['acao'] ?? 'Evento').toString();
    final autor = (ev['autor'] ?? ev['usuario'] ?? '').toString();
    final data = (ev['em'] ?? ev['data_hora'] ?? ev['criado_em'] ?? '').toString();
    final diff = ev['diff'] ?? ev['detalhes'] ?? ev['motivo'];

    IconData icone = Icons.history;
    final tipoLower = tipo.toLowerCase();
    if (tipoLower.contains('edit')) icone = Icons.edit;
    if (tipoLower.contains('vist')) icone = Icons.verified;
    if (tipoLower.contains('corre')) icone = Icons.report_problem;
    if (tipoLower.contains('envi')) icone = Icons.send;

    final titulo = autor.isNotEmpty
        ? '$tipo por $autor${data.isNotEmpty ? ' — $data' : ''}'
        : '$tipo${data.isNotEmpty ? ' — $data' : ''}';

    return ListTile(
      dense: true,
      leading: Icon(icone, size: 20),
      title: Text(titulo),
      subtitle: diff != null && diff.toString().trim().isNotEmpty
          ? Text(diff.toString())
          : null,
    );
  }

  Widget _buildRodape(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString().toUpperCase();
    final vistado = status == 'VISTADO' || d['vistado_em'] != null;

    if (vistado) {
      final quem = d['vistado_por_nome'] ?? d['vistado_por'] ?? 'Administrador';
      final quando = d['vistado_em'] ?? '-';
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(14),
          color: Colors.green.shade50,
          child: Row(
            children: [
              Icon(Icons.lock, color: Colors.green.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vistado por $quem em $quando — registro travado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processandoAcao ? null : _solicitarCorrecao,
                icon: const Icon(Icons.edit_note),
                label: const Text('SOLICITAR CORREÇÃO'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _processandoAcao ? null : _vistar,
                icon: const Icon(Icons.verified),
                label: const Text('VISTAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tituloSecao(String texto, {Color? cor}) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: cor,
      ),
    );
  }

  Widget _linhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$rotulo:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}