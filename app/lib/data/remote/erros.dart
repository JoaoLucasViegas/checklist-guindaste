import 'package:dio/dio.dart';

class ErroApi implements Exception {
  final String mensagem;
  const ErroApi(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Converte qualquer erro em mensagem para o usuário.
String mensagemDeErro(Object e) {
  if (e is ErroApi) return e.mensagem;
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['erro'] is Map && d['erro']['mensagem'] != null) {
      return d['erro']['mensagem'].toString();
    }
    if (d is Map && d['detail'] != null) return d['detail'].toString();
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Sem conexão com o servidor';
      default:
        break;
    }
  }
  return 'Algo deu errado. Tente novamente.';
}
