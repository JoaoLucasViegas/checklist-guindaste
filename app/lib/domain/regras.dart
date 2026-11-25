import 'modelos.dart';

void responderManual(
  RespostaItem resposta,
  String valor, {
  String? observacao,
}) {
  resposta.resposta = valor;
  resposta.observacao = observacao;
  resposta.origem = 'MANUAL';
}

int marcarTudoOk(
  List<RespostaItem> respostas,
  List<ItemTemplate> itens, {
  bool incluirCriticos = true,
}) {
  int marcados = 0;

  for (final resposta in respostas) {
    if (resposta.resposta != null) continue;

    final item = itens.firstWhere((item) => item.numero == resposta.numero);

    if (!incluirCriticos && item.critico) continue;

    resposta.resposta = 'S';
    resposta.origem = 'LOTE';
    marcados++;
  }

  return marcados;
}

List<int> criticosComProblema(
  List<RespostaItem> respostas,
  List<ItemTemplate> itens,
) {
  return respostas
      .where((resposta) {
        final item = itens.firstWhere((item) => item.numero == resposta.numero);

        return item.critico && resposta.resposta == 'N';
      })
      .map((resposta) => resposta.numero)
      .toList();
}

ResumoChecklist resumir(List<RespostaItem> respostas) {
  return ResumoChecklist(
    lote: respostas.where((r) => r.origem == 'LOTE').length,
    manuais: respostas.where((r) => r.origem == 'MANUAL').length,
    problemas: respostas.where((r) => r.resposta == 'N').length,
  );
}

List<String> validarParaEnviar({
  required List<RespostaItem> respostas,
  required List<ItemTemplate> itens,
  required double horimetroInicial,
  required double horimetroFinal,
  required int combustivelPct,
  required String turno,
  required String horaEntrada,
  required String horaSaida,
  required String assinaturaBase64,
}) {
  final erros = <String>[];

  for (final resposta in respostas) {
    if (resposta.resposta == null) {
      erros.add('Item ${resposta.numero} sem resposta.');
    }

    if (resposta.resposta == 'N' &&
        (resposta.observacao == null || resposta.observacao!.trim().isEmpty)) {
      erros.add('Item ${resposta.numero} precisa de observação.');
    }
  }

  if (horimetroFinal < horimetroInicial) {
    erros.add('Horímetro final não pode ser menor que o inicial.');
  }

  if (combustivelPct < 0 || combustivelPct > 100) {
    erros.add('Combustível deve estar entre 0 e 100%.');
  }

  if (horaEntrada.isEmpty || horaSaida.isEmpty) {
    erros.add('Informe os horários de entrada e saída.');
  }

  if (assinaturaBase64.isEmpty) {
    erros.add('Assinatura obrigatória.');
  }

  return erros;
}
