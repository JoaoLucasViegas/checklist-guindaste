import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../data/remote/api.dart';
import '../auth/confirmar_saida.dart';
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
  String? _filtroStatus;

  Map<String, dynamic> _contadores = const {
    'pendentes': 0,
    'impedidos': 0,
    'correcao': 0,
    'vistados_hoje': 0,
  };

  List<Map<String, dynamic>> _itens = const [];

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
    final ehTablet = Responsivo.ehTablet(context);

    return Scaffold(
      backgroundColor: TemaApp.fundo,
      body: Column(
        children: [
          // Cabeçalho escuro com contadores integrados (fiel à ref image_2631dc.png)
          Container(
            color: TemaApp.escuro,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ehTablet ? 24 : 16,
                  14,
                  ehTablet ? 24 : 16,
                  16,
                ),
                child: ContainerResponsivo(
                  maxWidth: 1120,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PAINEL ADMINISTRADOR',
                                  style: TextStyle(
                                    color: TemaApp.azulClaro,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sessao.nome ?? 'Administrador',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _segundosRestantes,
                            builder: (_, segundos, _) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                '${segundos}s',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                            tooltip: 'Atualizar',
                            onPressed: () => _recarregar(),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: TemaApp.escuroCard,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => confirmarSaida(context, sessao),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: ehTablet ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: ehTablet ? 2.4 : 2.3,
                        children: [
                          _contadorEscuro(
                            titulo: 'Pendentes',
                            valor: _contadores['pendentes'] ?? 0,
                            corNumero: TemaApp.azulClaro,
                            fundo: TemaApp.escuroCard,
                            borda: TemaApp.escuroBorda,
                            onTap: () => _selecionarFiltro('ENVIADO'),
                          ),
                          _contadorEscuro(
                            titulo: 'Impedidos',
                            valor: _contadores['impedidos'] ?? 0,
                            corNumero: const Color(0xFFFCA5A5),
                            fundo: const Color(0xFF4C0519),
                            borda: const Color(0xFF9F1239),
                            onTap: () => _selecionarFiltro(null),
                          ),
                          _contadorEscuro(
                            titulo: 'Correção',
                            valor: _contadores['correcao'] ?? 0,
                            corNumero: TemaApp.ambar,
                            fundo: TemaApp.escuroCard,
                            borda: TemaApp.escuroBorda,
                            onTap: () =>
                                _selecionarFiltro('CORRECAO_SOLICITADA'),
                          ),
                          _contadorEscuro(
                            titulo: 'Vistados hoje',
                            valor: _contadores['vistados_hoje'] ?? 0,
                            corNumero: const Color(0xFF4ADE80),
                            fundo: TemaApp.escuroCard,
                            borda: TemaApp.escuroBorda,
                            onTap: () => _selecionarFiltro('VISTADO'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Barra branca de filtros (igual à ref)
          Container(
            width: double.infinity,
            color: TemaApp.superficie,
            padding: EdgeInsets.symmetric(
              horizontal: ehTablet ? 24 : 16,
              vertical: 10,
            ),
            child: ContainerResponsivo(
              maxWidth: 1120,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
          ),
          const Divider(height: 1),

          // Lista de checklists
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _recarregar(),
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _erro != null
                  ? Center(
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
                    )
                  : _itens.isEmpty
                  ? const Center(child: Text('Nenhum checklist encontrado.'))
                  : ListView.builder(
                      padding: Responsivo.paddingPagina(context),
                      itemCount: _itens.length,
                      itemBuilder: (context, index) {
                        final item = _itens[index];
                        return ContainerResponsivo(
                          maxWidth: 1120,
                          child: _ItemChecklistCard(
                            item: item,
                            onTap: () async {
                              final id = item['id'].toString();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetalheAdminPage(checklistId: id),
                                ),
                              );
                              _recarregar();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contadorEscuro({
    required String titulo,
    required Object valor,
    required Color corNumero,
    required Color fundo,
    required Color borda,
    required VoidCallback onTap,
  }) {
    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borda),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$valor',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: corNumero,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipFiltro(String label, String? valor) {
    final selecionado = _filtroStatus == valor;
    return ChoiceChip(
      label: Text(label),
      selected: selecionado,
      showCheckmark: false,
      selectedColor: TemaApp.escuro,
      backgroundColor: TemaApp.fundo,
      labelStyle: TextStyle(
        color: selecionado ? Colors.white : TemaApp.textoSecundario,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => _selecionarFiltro(valor),
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
    final status = (item['status'] ?? 'ENVIADO').toString().toUpperCase();
    final ehVistado = status == 'VISTADO';
    final ehCorrecao = status == 'CORRECAO_SOLICITADA';

    final operadorMap = item['operador'] as Map?;
    final operadorNome = operadorMap?['nome']?.toString() ?? 'Operador';
    final equipamento = item['equipamento']?.toString() ?? '-';
    final local = item['local']?.toString() ?? '-';
    final turno = item['turno']?.toString() ?? '-';
    final dataTurno = item['data_turno']?.toString() ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: impedido && !ehVistado
            ? TemaApp.perigoFundo
            : ehCorrecao
            ? const Color(0xFFFFFBEB)
            : TemaApp.superficie,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: impedido && !ehVistado
                    ? TemaApp.perigo
                    : ehCorrecao
                    ? TemaApp.ambarEscuro
                    : ehVistado
                    ? TemaApp.sucessoBorda
                    : TemaApp.borda,
                width: (impedido && !ehVistado) || ehCorrecao ? 1.8 : 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconeStatusChecklist(status, impedido: impedido),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (impedido)
                                      const SeloStatus(
                                        texto: 'IMPEDIDO',
                                        icone: Icons.warning_amber_rounded,
                                        fundo: TemaApp.perigo,
                                        corTexto: Colors.white,
                                      ),
                                    if (ehVistado)
                                      const SeloStatus(
                                        texto: 'VISTADO',
                                        icone: Icons.verified_outlined,
                                        fundo: TemaApp.sucessoFundo,
                                        corTexto: TemaApp.sucesso,
                                      )
                                    else if (ehCorrecao)
                                      const SeloStatus(
                                        texto: 'CORREÇÃO',
                                        icone: Icons.edit_note_rounded,
                                        fundo: TemaApp.ambarFundo,
                                        corTexto: TemaApp.ambarEscuro,
                                      )
                                    else
                                      const SeloStatus(
                                        texto: 'Pendente',
                                        icone: Icons.pending_actions_rounded,
                                        fundo: TemaApp.azulFundo,
                                        corTexto: TemaApp.azulAdmin,
                                      ),
                                    if (usouLote)
                                      const SeloStatus(
                                        texto: 'lote',
                                        icone: Icons.done_all_rounded,
                                        fundo: TemaApp.ambarFundo,
                                        corTexto: TemaApp.ambarEscuro,
                                        borda: TemaApp.ambarBorda,
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
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dataTurno,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: TemaApp.textoTerciario,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            equipamento,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: impedido && !ehVistado
                                  ? TemaApp.perigo
                                  : TemaApp.textoPrimario,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$operadorNome · $local · Turno $turno',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: TemaApp.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (ehVistado) ...[
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: TemaApp.sucesso,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Vistado · Ver registro →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: TemaApp.sucesso,
                        ),
                      ),
                    ] else
                      Text(
                        'Conferir itens →',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: impedido ? TemaApp.perigo : TemaApp.azulAdmin,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconeStatusChecklist(String status, {required bool impedido}) {
    final (IconData icone, Color cor, Color fundo, Color borda, String dica) =
        switch (status) {
          'VISTADO' => (
            Icons.verified_rounded,
            TemaApp.sucesso,
            TemaApp.sucessoFundo,
            TemaApp.sucessoBorda,
            'Vistado e travado',
          ),
          'CORRECAO_SOLICITADA' => (
            Icons.edit_note_rounded,
            TemaApp.ambarEscuro,
            TemaApp.ambarFundo,
            TemaApp.ambarBorda,
            'Correção solicitada',
          ),
          _ when impedido => (
            Icons.warning_amber_rounded,
            Colors.white,
            TemaApp.perigo,
            TemaApp.perigo,
            'Equipamento impedido',
          ),
          _ => (
            Icons.pending_actions_rounded,
            TemaApp.azulAdmin,
            TemaApp.azulFundo,
            TemaApp.azulBorda,
            'Pendente de visto',
          ),
        };

    return Tooltip(
      message: dica,
      child: Semantics(
        label: dica,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borda, width: 1.2),
          ),
          child: Icon(icone, color: cor, size: 24),
        ),
      ),
    );
  }
}
