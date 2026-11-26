import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

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
      appBar: AppBar(
        title: const Text('Detalhe do Checklist'),
        actions: [
          if (podeEditar)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEditar?.call();
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar'),
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(child: Text('Erro: $_erro'))
          : _buildConteudo(_dados!),
    );
  }

  Widget _buildConteudo(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString().toUpperCase();
    final motivo = (d['motivo_correcao'] ?? '').toString().trim();
    final editado = d['editado'] == true;
    final eventos = ((d['eventos'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (status == 'CORRECAO_SOLICITADA' && motivo.isNotEmpty)
          Card(
            color: Colors.amber.shade100,
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.amber.shade900),
              title: const Text(
                'Correção solicitada',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(motivo),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${d['equipamento'] ?? '-'} • ${d['local'] ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (editado)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Editado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Status: $status'),
                Text(
                  'Turno: ${d['turno'] ?? '-'} • Data: ${d['data_turno'] ?? '-'}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Linha do tempo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (eventos.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
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
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(
                      '${eventos[i]['tipo'] ?? 'Evento'} por ${eventos[i]['autor'] ?? '-'} — ${eventos[i]['em'] ?? ''}',
                    ),
                    subtitle: eventos[i]['detalhes'] != null
                        ? Text(eventos[i]['detalhes'].toString())
                        : null,
                  ),
                  if (i < eventos.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
