import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/remote/api.dart';
import '../auth/sessao.dart';
import 'detalhe_admin_page.dart';

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  static const int _intervaloSegundos = 15;

  final ValueNotifier<int> _segundosRestantes = ValueNotifier<int>(
    _intervaloSegundos,
  );
  Timer? _timer;

  bool _carregando = true;
  String? _erro;
  String?
  _filtroStatus; // null = Todos, 'ENVIADO', 'CORRECAO_SOLICITADA', 'VISTADO'

  Map<String, dynamic> _contadores = const {
    'pendentes': 0,
    'impedidos': 0,
    'correcao': 0,
    'vistados_hoje': 0,
  };

  List _itens = const [];

  @override
  void initState() {
    super.initState();
    _recarregar();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _segundosRestantes.value = _intervaloSegundos;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_segundosRestantes.value <= 1) {
        _segundosRestantes.value = _intervaloSegundos;
        _recarregar(silencioso: true);
      } else {
        _segundosRestantes.value--;
      }
    });
  }

  Future<void> _recarregar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final api = context.read<Api>();
      final resposta = await api.listarChecklists(status: _filtroStatus);

      if (!mounted) return;
      final contadores = Map<String, dynamic>.from(
        (resposta['contadores'] as Map?) ?? const {},
      );
      final itensBrutos = (resposta['itens'] as List?) ?? const [];

      setState(() {
        _contadores = contadores;
        _itens = itensBrutos
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _carregando = false;
        _erro = null;
      });
      _segundosRestantes.value = _intervaloSegundos;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = e.toString();
      });
    }
  }

  void _selecionarFiltro(String? novoStatus) {
    if (_filtroStatus == novoStatus) return;
    setState(() => _filtroStatus = novoStatus);
    _recarregar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _segundosRestantes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
        actions: [
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: _segundosRestantes,
              builder: (_, segundos, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  'Atualiza em ${segundos}s',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () => _recarregar(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              final sair = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sair da conta'),
                  content: const Text('Deseja sair da conta de Administrador?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
              if (sair == true) {
                sessao.sair();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _recarregar(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Cartões de contadores
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.3,
                  children: [
                    _CartaoContador(
                      titulo: 'Pendentes',
                      valor: _contadores['pendentes'] ?? 0,
                      cor: Colors.amber.shade800,
                    ),
                    _CartaoContador(
                      titulo: 'Impedidos',
                      valor: _contadores['impedidos'] ?? 0,
                      cor: Colors.red.shade700,
                    ),
                    _CartaoContador(
                      titulo: 'Correção solicitada',
                      valor: _contadores['correcao'] ?? 0,
                      cor: Colors.orange.shade800,
                    ),
                    _CartaoContador(
                      titulo: 'Vistados hoje',
                      valor: _contadores['vistados_hoje'] ?? 0,
                      cor: Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Filtro por status (chips)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _chipFiltro('Todos', null),
                    const SizedBox(width: 8),
                    _chipFiltro('Pendentes', 'ENVIADO'),
                    const SizedBox(width: 8),
                    _chipFiltro('Correção solicitada', 'CORRECAO_SOLICITADA'),
                    const SizedBox(width: 8),
                    _chipFiltro('Vistados', 'VISTADO'),
                  ],
                ),
              ),
            ),

            // 3. Lista de checklists
            if (_carregando)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_erro != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Erro ao carregar checklists:\n$_erro',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _recarregar(),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_itens.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Nenhum checklist encontrado.')),
              )
            else
              SliverList.builder(
                itemCount: _itens.length,
                itemBuilder: (context, index) {
                  final item = _itens[index];
                  return _ItemChecklistCard(
                    item: item,
                    onTap: () async {
                      final id = item['id'].toString();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetalheAdminPage(checklistId: id),
                        ),
                      );
                      _recarregar();
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro(String label, String? valor) {
    return ChoiceChip(
      label: Text(label),
      selected: _filtroStatus == valor,
      onSelected: (_) => _selecionarFiltro(valor),
    );
  }
}

class _CartaoContador extends StatelessWidget {
  final String titulo;
  final Object valor;
  final Color cor;

  const _CartaoContador({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemChecklistCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _ItemChecklistCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final impedido = item['impedido'] == true;
    final usouLote = item['usou_lote'] == true;
    final editado = item['editado'] == true;

    final operadorMap = item['operador'] as Map?;
    final operadorNome = operadorMap?['nome']?.toString() ?? 'Operador';
    final equipamento = item['equipamento']?.toString() ?? '-';
    final local = item['local']?.toString() ?? '-';
    final turno = item['turno']?.toString() ?? '-';
    final dataTurno = item['data_turno']?.toString() ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: impedido ? Colors.red.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: impedido ? Colors.red.shade400 : Colors.grey.shade300,
          width: impedido ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          '$equipamento • $local',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: impedido ? Colors.red.shade900 : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operador: $operadorNome'),
              Text('Turno: $turno • Data: $dataTurno'),
              if (impedido || usouLote || editado) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (impedido)
                      _selo('IMPEDIDO', Colors.red.shade700, Colors.white),
                    if (usouLote)
                      _selo(
                        'Lote',
                        Colors.indigo.shade100,
                        Colors.indigo.shade900,
                      ),
                    if (editado)
                      _selo(
                        'Editado',
                        Colors.amber.shade100,
                        Colors.amber.shade900,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _selo(String texto, Color fundo, Color corTexto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: corTexto,
        ),
      ),
    );
  }
}
