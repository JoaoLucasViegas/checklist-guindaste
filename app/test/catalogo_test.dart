import 'package:checklist_guindaste/data/mappers/catalogo_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CatalogoMapper converte template e lookups', () {
    final c = CatalogoMapper.fromJson(
      template: {
        'id': 't1',
        'codigo': 'FOR-OPP-0017',
        'versao': 5,
        'titulo': 'Check-List',
        'itens': [
          {
            'numero': 1,
            'descricao': 'Cinto',
            'critico': true,
            'permite_na': true,
          },
        ],
      },
      lookups: {
        'locais': [
          {'id': 'l1', 'nome': 'Cais 99'},
        ],
        'equipamentos': [
          {'id': 'e1', 'identificacao': 'GUINDASTE-280'},
        ],
        'turnos': ['T_20_02'],
      },
    );
    expect(c.itens.length, 1);
    expect(c.itens.first.critico, isTrue);
    expect(c.locais.first.nome, 'Cais 99');
    expect(c.turnos, ['T_20_02']);
  });
}
