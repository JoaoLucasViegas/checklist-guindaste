class ItemTemplate {
  final int numero;
  final String descricao;
  final bool critico;

  const ItemTemplate({
    required this.numero,
    required this.descricao,
    required this.critico,
  });
}

class RespostaItem {
  final int numero;
  String? resposta;
  String? observacao;
  String? origem;

  RespostaItem({
    required this.numero,
    this.resposta,
    this.observacao,
    this.origem,
  });
}

class ResumoChecklist {
  final int lote;
  final int manuais;
  final int problemas;

  const ResumoChecklist({
    required this.lote,
    required this.manuais,
    required this.problemas,
  });
}
