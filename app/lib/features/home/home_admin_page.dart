// features/home/home_admin_page.dart  (igual, trocando o nome da classe e o título)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/sessao.dart';

class HomeAdminPage extends StatelessWidget {
  const HomeAdminPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Sessao>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
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
