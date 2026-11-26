import 'package:material_ui/material_ui.dart';

import '../../core/tema_app.dart';
import 'sessao.dart';

Future<void> confirmarSaida(BuildContext context, Sessao sessao) async {
  final confirmou = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.logout_rounded,
        color: TemaApp.escuro,
        size: 32,
      ),
      title: const Text('Deseja sair?'),
      content: const Text(
        'Será necessário entrar novamente para continuar. '
        'Sem conexão, não será possível autenticar. '
        'Checklists salvos no aparelho não serão apagados.',
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Permanecer'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: TemaApp.perigo),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sair da conta'),
        ),
      ],
    ),
  );
  if (confirmou == true) await sessao.sair();
}
