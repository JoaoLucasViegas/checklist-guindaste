class Config {
  // 10.0.2.2 = o notebook visto de dentro do emulador Android. No celular real, use o IP do notebook.
  static const apiUrlPadrao =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000/api/v1');
  static const usarMock = bool.fromEnvironment('MOCK', defaultValue: false);
}