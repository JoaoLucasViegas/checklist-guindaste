import 'package:material_ui/material_ui.dart';

/// Sistema de design fiel à identidade COPI Operações Integradas
/// (Azul Naval escuro #0F172A + Âmbar operacional #F59E0B + alto contraste WCAG AA/AAA),
/// otimizado para uso em cabine (luvas) e tablets.
class TemaApp {
  TemaApp._();

  // Base institucional escura (headers, textos fortes, chips ativos)
  static const Color escuro = Color(0xFF0F172A);
  static const Color escuroCard = Color(0xFF1E293B);
  static const Color escuroBorda = Color(0xFF334155);

  // Destaque Operador (Âmbar / Laranja industrial)
  static const Color ambar = Color(0xFFF59E0B);
  static const Color ambarEscuro = Color(0xFFD97706);
  static const Color ambarFundo = Color(0xFFFEF3C7);
  static const Color ambarBorda = Color(0xFFFCD34D);

  // Destaque Administrador (Azul operacional)
  static const Color azulAdmin = Color(0xFF0284C7);
  static const Color azulClaro = Color(0xFF38BDF8);
  static const Color azulFundo = Color(0xFFE0F2FE);
  static const Color azulBorda = Color(0xFF7DD3FC);

  // Superfícies e bordas
  static const Color fundo = Color(0xFFF1F5F9);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieAlt = Color(0xFFF8FAFC);
  static const Color borda = Color(0xFFE2E8F0);
  static const Color bordaForte = Color(0xFFCBD5E1);

  // Tipografia
  static const Color textoPrimario = Color(0xFF0F172A);
  static const Color textoSecundario = Color(0xFF334155);
  static const Color textoTerciario = Color(0xFF64748B);

  // Semântica
  static const Color sucesso = Color(0xFF15803D);
  static const Color sucessoFundo = Color(0xFFDCFCE7);
  static const Color sucessoBorda = Color(0xFF86EFAC);

  static const Color perigo = Color(0xFFBE123C);
  static const Color perigoEscuro = Color(0xFF881337);
  static const Color perigoFundo = Color(0xFFFFE4E6);
  static const Color perigoBorda = Color(0xFFFDA4AF);

  static const Color neutro = Color(0xFF475569);
  static const Color neutroFundo = Color(0xFFE2E8F0);

  static ThemeData get claro {
    final scheme = ColorScheme.fromSeed(
      seedColor: escuro,
      brightness: Brightness.light,
      primary: escuro,
      onPrimary: Colors.white,
      secondary: ambar,
      onSecondary: escuro,
      error: perigo,
      onError: Colors.white,
      errorContainer: perigoFundo,
      onErrorContainer: perigoEscuro,
      surface: superficie,
      onSurface: textoPrimario,
      surfaceContainerLow: superficieAlt,
      outline: bordaForte,
      outlineVariant: borda,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: fundo,
      appBarTheme: const AppBarTheme(
        backgroundColor: escuro,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 22),
      ),
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borda, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borda,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficieAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: const TextStyle(
          color: textoSecundario,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: textoTerciario),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bordaForte, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bordaForte, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ambarEscuro, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: perigo, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: perigo, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: bordaForte, width: 1.4),
          foregroundColor: textoPrimario,
          backgroundColor: superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: escuro,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textoPrimario,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: textoPrimario,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textoPrimario,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textoPrimario,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textoSecundario,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textoTerciario,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textoPrimario,
        ),
      ),
    );
  }

  /// Estilo do botão principal Âmbar com texto escuro (contraste > 8:1).
  static ButtonStyle get botaoAmbar => FilledButton.styleFrom(
    backgroundColor: ambar,
    foregroundColor: escuro,
    minimumSize: const Size(56, 56),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.1,
    ),
  );
}

/// Selo semântico de alto contraste com ícone opcional.
class SeloStatus extends StatelessWidget {
  final String texto;
  final Color fundo;
  final Color corTexto;
  final Color? borda;
  final IconData? icone;

  const SeloStatus({
    super.key,
    required this.texto,
    required this.fundo,
    required this.corTexto,
    this.borda,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: texto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(8),
          border: borda != null ? Border.all(color: borda!, width: 1.2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 14, color: corTexto),
              const SizedBox(width: 5),
            ],
            Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: corTexto,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de notificação de erro para exibição no TOPO das telas do operador,
/// garantindo visibilidade imediata sem ficar escondida no rodapé.
class BarraNotificacaoErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onFechar;

  const BarraNotificacaoErro({
    super.key,
    required this.mensagem,
    this.onFechar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: TemaApp.perigoFundo,
        border: Border(
          bottom: BorderSide(color: TemaApp.perigoBorda, width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: TemaApp.perigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(
                color: TemaApp.perigo,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
          if (onFechar != null)
            InkWell(
              onTap: onFechar,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: TemaApp.perigo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog-box de alto contraste para destacar erros de validação ao operador.
Future<void> mostrarDialogoErros(
  BuildContext context, {
  required String titulo,
  required List<String> erros,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.error_outline_rounded,
        color: TemaApp.perigo,
        size: 34,
      ),
      title: Text(titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final erro in erros)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $erro',
                  style: const TextStyle(
                    color: TemaApp.textoPrimario,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: TemaApp.botaoAmbar,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
