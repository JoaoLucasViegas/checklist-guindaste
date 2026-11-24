import 'modelos.dart';

class Local {
  final String id;
  final String nome;
  const Local({required this.id, required this.nome});
}

class Equipamento {
  final String id;
  final String identificacao;
  const Equipamento({required this.id, required this.identificacao});
}

class Catalogo {
  final String templateId;
  final String codigo;
  final int versao;
  final String titulo;
  final List<ItemTemplate> itens;
  final List<Local> locais;
  final List<Equipamento> equipamentos;
  final List<String> turnos;
  final DateTime? atualizadoEm;

  const Catalogo({
    required this.templateId,
    required this.codigo,
    required this.versao,
    required this.titulo,
    required this.itens,
    required this.locais,
    required this.equipamentos,
    required this.turnos,
    this.atualizadoEm,
  });
}
