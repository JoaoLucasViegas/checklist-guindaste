import 'package:material_ui/material_ui.dart';

import 'sessao.dart';

Future<void> confirmarSaida(BuildContext context, Sessao sessao) async {
  final confirmou = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Deseja sair?'),
      content: const Text(
        'Será necessário entrar novamente para continuar. '
        'Sem conexão, não será possível autenticar. '
        'Checklists salvos no aparelho não serão apagados.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Permanecer'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sair da conta'),
        ),
      ],
    ),
  );
  if (confirmou == true) await sessao.sair();
}
