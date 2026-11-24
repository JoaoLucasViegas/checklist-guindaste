// features/home/home_operador_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/sessao.dart';

class HomeOperadorPage extends StatelessWidget {
  const HomeOperadorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Sessao>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: s.sair,
          ),
        ],
      ),
      body: Center(
        child: Text('Olá, ${s.nome}', style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
