abstract class Api {
  Future<Map<String, dynamic>> login(String matricula, String pin);
  Future<Map<String, dynamic>> template();
  Future<Map<String, dynamic>> lookups();
  Future<double?> ultimoHorimetro(String equipamentoId);
  Future<Map<String, dynamic>> enviarChecklist(
    String id,
    Map<String, dynamic> payload,
  ); //PUT
  Future<Map<String, dynamic>> listarChecklists({String? status});
  Future<Map<String, dynamic>> detalhe(String id);
  Future<void> vistar(String id);
  Future<void> solicitarCorrecao(String id, String motivo);
}
