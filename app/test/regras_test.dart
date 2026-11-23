// Depois do `flutter create`, mova para app/test/ e rode: flutter test
// O nome do pacote vem do `--project-name checklist_guindaste` (ver app/README.md).
import 'package:checklist_guindaste/domain/modelos.dart';
import 'package:checklist_guindaste/domain/regras.dart';
import 'package:flutter_test/flutter_test.dart';

List<ItemTemplate> itens() => [
      for (var n = 1; n <= 23; n++)
        ItemTemplate(numero: n, descricao: 'Item $n', critico: {1, 10, 22}.contains(n)),
    ];

List<RespostaItem> vazias() => [for (var n = 1; n <= 23; n++) RespostaItem(numero: n)];

void main() {
  test('lote marca só itens sem resposta, como S', () {
    final r = vazias();
    responderManual(r[0], 'N', observacao: 'Não tem'); // item 1
    final marcados = marcarTudoOk(r, itens());
    expect(marcados, 22);
    expect(r[0].resposta, 'N'); // não sobrescreveu
    expect(r[1].resposta, 'S');
    expect(r[1].origem, 'LOTE');
  });

  test('lote sem críticos deixa críticos sem resposta', () {
    final r = vazias();
    marcarTudoOk(r, itens(), incluirCriticos: false);
    expect(r[0].resposta, isNull); // item 1 é crítico
    expect(r[1].resposta, 'S');
  });

  test('caso da foto: N nos itens 1, 10 e 22 => impedido', () {
    final r = vazias();
    marcarTudoOk(r, itens());
    responderManual(r[0], 'N', observacao: 'Não tem');
    responderManual(r[9], 'N', observacao: 'Patola 1 e 3 com vazamento');
    responderManual(r[21], 'N', observacao: 'Calibrar pneus');
    expect(criticosComProblema(r, itens()), [1, 10, 22]);
    final s = resumir(r);
    expect([s.lote, s.manuais, s.problemas], [20, 3, 3]);
  });

  test('N sem observação bloqueia o envio', () {
    final r = vazias();
    marcarTudoOk(r, itens());
    r[0].resposta = 'N';
    final erros = validarParaEnviar(
      respostas: r, itens: itens(), horimetroInicial: 1, horimetroFinal: 2,
      combustivelPct: 95, turno: 'T_20_02', horaEntrada: '20:00', horaSaida: '02:00',
      assinaturaBase64: 'x',
    );
    expect(erros.any((e) => e.contains('Item 1')), isTrue);
  });

  test('turno 20x02 aceita saída menor que entrada', () {
    final r = vazias();
    marcarTudoOk(r, itens());
    final erros = validarParaEnviar(
      respostas: r, itens: itens(), horimetroInicial: 36466.1, horimetroFinal: 36470.8,
      combustivelPct: 95, turno: 'T_20_02', horaEntrada: '20:00', horaSaida: '02:00',
      assinaturaBase64: 'x',
    );
    expect(erros, isEmpty);
  });

  test('horímetro final menor que o inicial bloqueia', () {
    final r = vazias();
    marcarTudoOk(r, itens());
    final erros = validarParaEnviar(
      respostas: r, itens: itens(), horimetroInicial: 10, horimetroFinal: 5,
      combustivelPct: 50, turno: 'T_08_14', horaEntrada: '08:00', horaSaida: '14:00',
      assinaturaBase64: 'x',
    );
    expect(erros.any((e) => e.contains('Horímetro final')), isTrue);
  });
}
