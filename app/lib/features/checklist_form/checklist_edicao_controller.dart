import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/banco_local.dart';
import '../../data/remote/api.dart';
import '../../data/remote/erros.dart';
import '../../domain/catalogo.dart';
import '../../domain/modelos.dart';
import '../../domain/regras.dart' as regras;

class ChecklistEdicaoController extends ChangeNotifier {
  final Api _api;
  final Catalogo catalogo;
  final String usuarioId;
  late DateTime inicioPreenchimento;
  late DateTime criadoNoDispositivo;

  late final String id;
  late final List<RespostaItem> respostas;
  String? localId;
  String? equipamentoId;
  String turno;
  DateTime dataTurno;
  String navio = '';
  String horimetroInicial = '';
  String horimetroFinal = '';
  int combustivelPct = 95;
  String horaEntrada;
  String horaSaida = '';
  String observacaoGeral = '';
  double? sugestaoHorimetro;
  bool carregando = true;
  bool buscandoHorimetro = false;
  bool enviando = false;
  bool finalizado = false;
  bool usouLote = false;
  int itensMarcadosLote = 0;
  int itensAlteradosAposLote = 0;
  bool _alertaImpedimentoMostrado = false;
  Map<String, dynamic>? resultadoEnvio;
  String? erro;
  String? erroPersistencia;
  String? avisoHorimetro;
  List<String> errosValidacao = [];

  Future<void> _filaSalvamento = Future<void>.value();
  bool _disposed = false;

  ChecklistEdicaoController({
    required this._api,
    required this.catalogo,
    required this.usuarioId,
    String? rascunhoId,
  }) : turno = turnoSugerido(DateTime.now()),
       dataTurno = DateTime.now(),
       horaEntrada = horaAtual(DateTime.now()) {
    inicioPreenchimento = DateTime.now();
    criadoNoDispositivo = inicioPreenchimento;
    id = rascunhoId ?? const Uuid().v4();
    respostas = [
      for (final item in catalogo.itens) RespostaItem(numero: item.numero),
    ];
  }

  static String horaAtual(DateTime agora) =>
      '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';

  static String turnoSugerido(DateTime agora) {
    final minutoDoDia = agora.hour * 60 + agora.minute;
    if (minutoDoDia >= 8 * 60 && minutoDoDia < 14 * 60) return 'T_08_14';
    if (minutoDoDia >= 14 * 60 && minutoDoDia < 20 * 60) return 'T_14_20';
    if (minutoDoDia >= 20 * 60 || minutoDoDia < 2 * 60) return 'T_20_02';
    return 'T_02_08';
  }

  static double? parseHorimetro(String valor) {
    final normalizado = valor.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d)?$').hasMatch(normalizado)) return null;
    final numero = double.tryParse(normalizado);
    return numero != null && numero.isFinite ? numero : null;
  }

  Future<void> inicializar() async {
    try {
      final salvo = await BancoLocal.lerChecklist(id);
      if (salvo != null) {
        _restaurar(salvo['json'] as Map<String, dynamic>);
      } else {
        _agendarSalvamento();
      }
    } catch (e) {
      erro = 'Não foi possível abrir o rascunho: ${mensagemDeErro(e)}';
    } finally {
      carregando = false;
      _notificar();
    }
  }

  void _restaurar(Map<String, dynamic> json) {
    inicioPreenchimento =
        DateTime.tryParse(json['inicio_preenchimento_em'] as String? ?? '') ??
        inicioPreenchimento;
    criadoNoDispositivo =
        DateTime.tryParse(json['criado_no_dispositivo_em'] as String? ?? '') ??
        criadoNoDispositivo;
    localId = json['local_id'] as String?;
    equipamentoId = json['equipamento_id'] as String?;
    turno = json['turno'] as String? ?? turno;
    dataTurno =
        DateTime.tryParse(json['data_turno'] as String? ?? '') ?? dataTurno;
    navio = json['navio'] as String? ?? '';
    horimetroInicial = json['horimetro_inicial']?.toString() ?? '';
    horimetroFinal = json['horimetro_final']?.toString() ?? '';
    combustivelPct = json['combustivel_pct'] as int? ?? combustivelPct;
    horaEntrada = json['hora_entrada'] as String? ?? horaEntrada;
    horaSaida = json['hora_saida'] as String? ?? '';
    observacaoGeral = json['observacao_geral'] as String? ?? '';
    usouLote = json['usou_lote'] as bool? ?? false;
    itensMarcadosLote = json['itens_marcados_lote'] as int? ?? 0;
    itensAlteradosAposLote = json['itens_alterados_apos_lote'] as int? ?? 0;
    _alertaImpedimentoMostrado =
        json['alerta_impedimento_mostrado'] as bool? ?? false;

    final respostasSalvas = json['respostas'];
    if (respostasSalvas is List) {
      for (final item in respostasSalvas) {
        if (item is! Map) continue;
        final numero = item['item_numero'];
        final resposta = respostas.where((r) => r.numero == numero);
        if (resposta.isEmpty) continue;
        resposta.first
          ..resposta = item['resposta'] as String?
          ..origem = item['origem'] as String?
          ..observacao = item['observacao'] as String?;
      }
    }
  }

  Map<String, dynamic> _rascunhoJson() => {
    'template_id': catalogo.templateId,
    'local_id': localId,
    'equipamento_id': equipamentoId,
    'data_turno': _dataIso(dataTurno),
    'turno': turno,
    'navio': navio,
    'horimetro_inicial': horimetroInicial,
    'horimetro_final': horimetroFinal,
    'combustivel_pct': combustivelPct,
    'hora_entrada': horaEntrada,
    'hora_saida': horaSaida,
    'observacao_geral': observacaoGeral,
    'usou_lote': usouLote,
    'itens_marcados_lote': itensMarcadosLote,
    'itens_alterados_apos_lote': itensAlteradosAposLote,
    'alerta_impedimento_mostrado': _alertaImpedimentoMostrado,
    'inicio_preenchimento_em': inicioPreenchimento.toUtc().toIso8601String(),
    'criado_no_dispositivo_em': criadoNoDispositivo.toUtc().toIso8601String(),
    'respostas': [
      for (final resposta in respostas)
        {
          'item_numero': resposta.numero,
          'resposta': resposta.resposta,
          'origem': resposta.origem,
          'observacao': resposta.observacao,
        },
    ],
  };

  void _agendarSalvamento() {
    if (finalizado) return;
    final snapshot = _rascunhoJson();
    _filaSalvamento = _filaSalvamento.then((_) async {
      try {
        await BancoLocal.salvarChecklist(
          id: id,
          usuarioId: usuarioId,
          json: snapshot,
          status: 'RASCUNHO',
        );
        erroPersistencia = null;
      } catch (e) {
        erroPersistencia = 'Não foi possível salvar o rascunho: $e';
      }
      _notificar();
    });
  }

  Future<void> aguardarSalvamento() => _filaSalvamento;

  void _alterado() {
    errosValidacao = [];
    erro = null;
    _notificar();
    _agendarSalvamento();
  }

  void selecionarLocal(String? valor) {
    localId = valor;
    _alterado();
  }

  Future<void> selecionarEquipamento(String? valor) async {
    equipamentoId = valor;
    sugestaoHorimetro = null;
    avisoHorimetro = null;
    _alterado();
    if (valor == null) return;

    buscandoHorimetro = true;
    _notificar();
    try {
      final sugestao = await _api.ultimoHorimetro(valor);
      if (equipamentoId != valor) return;
      if (sugestao != null) {
        sugestaoHorimetro = sugestao;
        await BancoLocal.guardarCache('ultimo_horimetro_$valor', sugestao);
      } else {
        final cache = await BancoLocal.lerCache('ultimo_horimetro_$valor');
        if (cache is num) sugestaoHorimetro = cache.toDouble();
      }
      if (horimetroInicial.trim().isEmpty && sugestaoHorimetro != null) {
        horimetroInicial = sugestaoHorimetro!.toStringAsFixed(1);
        _agendarSalvamento();
      }
    } catch (e) {
      try {
        final cache = await BancoLocal.lerCache('ultimo_horimetro_$valor');
        if (cache is num) {
          sugestaoHorimetro = cache.toDouble();
          if (horimetroInicial.trim().isEmpty) {
            horimetroInicial = sugestaoHorimetro!.toStringAsFixed(1);
            _agendarSalvamento();
          }
        } else {
          avisoHorimetro = 'Sugestão indisponível: ${mensagemDeErro(e)}';
        }
      } catch (erroCache) {
        avisoHorimetro =
            'Sugestão indisponível: ${mensagemDeErro(e)}. '
            'Falha ao ler o cache: $erroCache';
      }
    } finally {
      if (equipamentoId == valor) {
        buscandoHorimetro = false;
        _notificar();
      }
    }
  }

  void aplicarSugestaoHorimetro() {
    if (sugestaoHorimetro == null) return;
    horimetroInicial = sugestaoHorimetro!.toStringAsFixed(1);
    _alterado();
  }

  void definirTurno(String valor) {
    turno = valor;
    _alterado();
  }

  void definirData(DateTime valor) {
    dataTurno = DateTime(valor.year, valor.month, valor.day);
    _alterado();
  }

  void definirNavio(String valor) {
    navio = valor;
    _alterado();
  }

  void definirHorimetroInicial(String valor) {
    horimetroInicial = valor;
    _alterado();
  }

  void definirHorimetroFinal(String valor) {
    horimetroFinal = valor;
    _alterado();
  }

  void definirCombustivel(int valor) {
    combustivelPct = valor;
    _alterado();
  }

  void definirHoraEntrada(String valor) {
    horaEntrada = valor;
    _alterado();
  }

  void definirHoraSaida(String valor) {
    horaSaida = valor;
    _alterado();
  }

  void definirObservacaoGeral(String valor) {
    observacaoGeral = valor;
    _alterado();
  }

  void responder(int numero, String valor) {
    final resposta = respostas.firstWhere((r) => r.numero == numero);
    final marcadaEmLote = resposta.origem == 'LOTE';
    regras.responderManual(
      resposta,
      valor,
      observacao: valor == 'N' ? resposta.observacao : null,
    );
    if (marcadaEmLote) itensAlteradosAposLote++;
    _alterado();
  }

  void definirObservacao(int numero, String valor) {
    final resposta = respostas.firstWhere((r) => r.numero == numero);
    regras.responderManual(resposta, 'N', observacao: valor);
    _alterado();
  }

  int get respondidos =>
      respostas.where((resposta) => resposta.resposta != null).length;

  ResumoChecklist get resumo => regras.resumir(respostas);

  List<int> get itensCriticosComProblema =>
      regras.criticosComProblema(respostas, catalogo.itens);

  bool get impedido => itensCriticosComProblema.isNotEmpty;

  int marcarTudoOk() {
    final quantidade = regras.marcarTudoOk(respostas, catalogo.itens);
    if (quantidade == 0) return 0;
    usouLote = true;
    itensMarcadosLote += quantidade;
    _alterado();
    return quantidade;
  }

  bool registrarAlertaImpedimentoExibido() {
    if (!impedido || _alertaImpedimentoMostrado) return false;
    _alertaImpedimentoMostrado = true;
    _agendarSalvamento();
    return true;
  }

  void prepararFinalizacao() {
    if (horaSaida.isEmpty) {
      horaSaida = horaAtual(DateTime.now());
      _alterado();
    }
  }

  List<String> _errosCabecalho() {
    final erros = <String>[];
    if (localId == null) erros.add('Selecione o local.');
    if (equipamentoId == null) erros.add('Selecione o equipamento.');
    final inicial = parseHorimetro(horimetroInicial);
    if (inicial == null) {
      erros.add(
        'Informe um horímetro inicial válido, com no máximo 1 casa decimal.',
      );
    }
    if (horimetroFinal.trim().isNotEmpty) {
      final finalValue = parseHorimetro(horimetroFinal);
      if (finalValue == null) {
        erros.add(
          'Informe um horímetro final válido, com no máximo 1 casa decimal.',
        );
      } else if (inicial != null && finalValue < inicial) {
        erros.add('Horímetro final não pode ser menor que o inicial.');
      }
    }
    if (combustivelPct < 0 || combustivelPct > 100) {
      erros.add('Combustível deve estar entre 0 e 100%.');
    }
    return erros;
  }

  bool get cabecalhoValido => _errosCabecalho().isEmpty;

  bool validarCabecalho() {
    final erros = _errosCabecalho();
    errosValidacao = erros;
    _notificar();
    return erros.isEmpty;
  }

  List<String> _validarEnvio(String assinaturaBase64) {
    final inicial = parseHorimetro(horimetroInicial);
    final finalValue = parseHorimetro(horimetroFinal);
    final erros = <String>[..._errosCabecalho()];

    if (horimetroFinal.trim().isEmpty || finalValue == null) {
      erros.add(
        'Informe um horímetro final válido, com no máximo 1 casa decimal.',
      );
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_dataIso(dataTurno))) {
      erros.add('Informe uma data válida.');
    }
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(horaEntrada)) {
      erros.add('Informe uma hora de entrada válida.');
    }
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(horaSaida)) {
      erros.add('Informe uma hora de saída válida.');
    }
    erros.addAll(
      regras.validarParaEnviar(
        respostas: respostas,
        itens: catalogo.itens,
        horimetroInicial: inicial ?? 0,
        horimetroFinal: finalValue ?? inicial ?? 0,
        combustivelPct: combustivelPct,
        turno: turno,
        horaEntrada: horaEntrada,
        horaSaida: horaSaida,
        assinaturaBase64: assinaturaBase64,
      ),
    );
    return erros.toSet().toList();
  }

  Map<String, dynamic> _payload(
    DateTime finalizadoEm,
    String assinaturaBase64,
  ) {
    final inicial = parseHorimetro(horimetroInicial)!;
    final finalValue = horimetroFinal.trim().isEmpty
        ? null
        : parseHorimetro(horimetroFinal);
    return {
      'template_id': catalogo.templateId,
      'equipamento_id': equipamentoId,
      'local_id': localId,
      'data_turno': _dataIso(dataTurno),
      'turno': turno,
      'navio': navio.trim().isEmpty ? null : navio.trim(),
      'horimetro_inicial': inicial,
      'horimetro_final': finalValue,
      'combustivel_pct': combustivelPct,
      'hora_entrada': horaEntrada,
      'hora_saida': horaSaida.trim().isEmpty ? null : horaSaida,
      'observacao_geral': observacaoGeral.trim().isEmpty
          ? null
          : observacaoGeral.trim(),
      'assinatura_operador': assinaturaBase64,
      'usou_lote': usouLote,
      'itens_marcados_lote': itensMarcadosLote,
      'itens_alterados_apos_lote': itensAlteradosAposLote,
      'inicio_preenchimento_em': inicioPreenchimento.toUtc().toIso8601String(),
      'finalizado_em': finalizadoEm.toUtc().toIso8601String(),
      'duracao_segundos': finalizadoEm
          .difference(inicioPreenchimento)
          .inSeconds,
      'confirmacao_correcao': false,
      'criado_no_dispositivo_em': criadoNoDispositivo.toUtc().toIso8601String(),
      'app_versao': '0.1.0',
      'respostas': [
        for (final resposta in respostas)
          {
            'item_numero': resposta.numero,
            'resposta': resposta.resposta,
            'origem': resposta.origem ?? 'MANUAL',
            'observacao': resposta.observacao,
          },
      ],
    };
  }

  Future<bool> finalizar(String assinaturaBase64) async {
    errosValidacao = _validarEnvio(assinaturaBase64);
    if (errosValidacao.isNotEmpty) {
      erro = errosValidacao.first;
      _notificar();
      return false;
    }

    enviando = true;
    erro = null;
    _notificar();
    try {
      await _filaSalvamento;
      final payload = _payload(DateTime.now(), assinaturaBase64);
      await BancoLocal.salvarChecklist(
        id: id,
        usuarioId: usuarioId,
        json: payload,
        status: 'PENDENTE_ENVIO',
      );
      finalizado = true;
      erroPersistencia = null;
      return true;
    } catch (e) {
      erro = mensagemDeErro(e);
      return false;
    } finally {
      enviando = false;
      _notificar();
    }
  }

  static String _dataIso(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
