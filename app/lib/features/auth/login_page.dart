import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/responsivo.dart';
import '../../core/tema_app.dart';
import '../../data/remote/api.dart';
import '../../data/remote/erros.dart';
import 'sessao.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _matricula = TextEditingController();
  final _pin = TextEditingController();
  bool _carregando = false;
  bool _ocultarPin = true;
  String? _erro;

  @override
  void dispose() {
    _matricula.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final matricula = _matricula.text.trim();
    final pin = _pin.text.trim();
    if (matricula.isEmpty || pin.isEmpty) {
      setState(() => _erro = 'Informe a matrícula e o PIN para continuar.');
      return;
    }
    final api = context.read<Api>();
    final sessao = context.read<Sessao>();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resp = await api.login(matricula, pin);
      await sessao.entrar(resp);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _preencher(String matricula, String pin) {
    _matricula.text = matricula;
    _pin.text = pin;
    setState(() => _erro = null);
  }

  @override
  Widget build(BuildContext context) {
    final ehTablet = Responsivo.ehTablet(context);

    return Scaffold(
      backgroundColor: TemaApp.superficieAlt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(ehTablet ? 32 : 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ehTablet ? 520 : 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho da marca COPI (igual à referência)
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: TemaApp.ambar,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_rounded,
                          size: 30,
                          color: TemaApp.escuro,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COPI OPERAÇÕES INTEGRADAS',
                              style: TextStyle(
                                color: TemaApp.ambarEscuro,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Check-List de Guindaste',
                              style: TextStyle(
                                color: TemaApp.textoPrimario,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Cartão branco de credenciais
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(ehTablet ? 26 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Acesso único por matrícula e PIN. Seu perfil de operação ou gestão é carregado automaticamente.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: TemaApp.textoSecundario,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Matrícula',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: TemaApp.textoPrimario,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _matricula,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Ex.: 1001',
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'PIN (4 dígitos)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: TemaApp.textoPrimario,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _pin,
                            obscureText: _ocultarPin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              hintText: '••••',
                              counterText: '',
                              suffixIcon: IconButton(
                                tooltip: _ocultarPin
                                    ? 'Mostrar PIN'
                                    : 'Ocultar PIN',
                                icon: Icon(
                                  _ocultarPin
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _ocultarPin = !_ocultarPin),
                              ),
                            ),
                          ),
                          if (_erro != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TemaApp.perigoFundo,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: TemaApp.perigoBorda),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: TemaApp.perigo,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _erro!,
                                      style: const TextStyle(
                                        color: TemaApp.perigo,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            style: TemaApp.botaoAmbar,
                            onPressed: _carregando ? null : _entrar,
                            child: _carregando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: TemaApp.escuro,
                                    ),
                                  )
                                : const Text('Entrar'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (Config.atalhosDemo) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: TemaApp.ambarEscuro,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ATALHO DE DEMONSTRAÇÃO',
                          style: TextStyle(
                            color: TemaApp.ambarEscuro,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _cartaoAtalho(
                      titulo: 'João Silva (Operador)',
                      subtitulo: 'Matrícula 1001 · PIN 1234',
                      corDestaque: TemaApp.ambarEscuro,
                      fundo: const Color(0xFFFFFBEB),
                      borda: TemaApp.ambarBorda,
                      onTap: () => _preencher('1001', '1234'),
                    ),
                    const SizedBox(height: 10),
                    _cartaoAtalho(
                      titulo: 'Administrador',
                      subtitulo: 'Matrícula 9001 · PIN 0000',
                      corDestaque: TemaApp.azulAdmin,
                      fundo: const Color(0xFFF0F9FF),
                      borda: TemaApp.azulBorda,
                      onTap: () => _preencher('9001', '0000'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartaoAtalho({
    required String titulo,
    required String subtitulo,
    required Color corDestaque,
    required Color fundo,
    required Color borda,
    required VoidCallback onTap,
  }) {
    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borda, width: 1.3),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: TemaApp.textoPrimario,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TemaApp.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Preencher →',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: corDestaque,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
