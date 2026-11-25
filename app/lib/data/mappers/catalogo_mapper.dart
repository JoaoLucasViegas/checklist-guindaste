import '../../domain/catalogo.dart';
import '../../domain/modelos.dart';

class CatalogoMapper {
  static Catalogo fromJson({
    required Map<String, dynamic> template,
    required Map<String, dynamic> lookups,
    DateTime? atualizadoEm,
  }) {
    List<Map<String, dynamic>> lista(dynamic valor) => [
      for (final item in valor as List) Map<String, dynamic>.from(item as Map),
    ];

    return Catalogo(
      templateId: template['id'] as String,
      codigo: template['codigo'] as String,
      versao: template['versao'] as int,
      titulo: (template['titulo'] ?? '') as String,
      itens: [
        for (final item in lista(template['itens']))
          ItemTemplate(
            numero: item['numero'] as int,
            descricao: item['descricao'] as String,
            critico: item['critico'] as bool,
          ),
      ],
      locais: [
        for (final local in lista(lookups['locais']))
          Local(id: local['id'] as String, nome: local['nome'] as String),
      ],
      equipamentos: [
        for (final equipamento in lista(lookups['equipamentos']))
          Equipamento(
            id: equipamento['id'] as String,
            identificacao: equipamento['identificacao'] as String,
          ),
      ],
      turnos: [for (final turno in lookups['turnos'] as List) turno as String],
      atualizadoEm: atualizadoEm,
    );
  }
}
