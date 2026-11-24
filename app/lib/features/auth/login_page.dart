import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
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
      setState(() => _erro = 'Informe a matrícula e o PIN');
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
      await sessao.entrar(resp); // a tela troca sozinha (ver main.dart)
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
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.fact_check, size: 64, color: cores.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Checklist de Guindaste',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _matricula,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _entrar(),
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '', // esconde o contador "0/6"
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _carregando ? null : _entrar,
                      child: _carregando
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cores.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (Config.atalhosDemo) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: cores.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Atalho de demonstração',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => _preencher('1001', '1234'),
                              child: const Text('João Silva (Operador)'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => _preencher('9001', '0000'),
                              child: const Text('Administrador'),
                            ),
                          ),
                        ],
                      ),
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
}
