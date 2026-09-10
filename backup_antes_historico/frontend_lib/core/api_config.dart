class ApiConfig {
  /// Permite trocar a URL da API sem recompilar o app inteiro, ex:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
  ///
  /// 127.0.0.1 só funciona quando o app roda na mesma máquina do backend
  /// (desktop/web local). Em emulador Android use 10.0.2.2; em dispositivo
  /// físico, use o IP da máquina que roda a API na sua rede.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
}
