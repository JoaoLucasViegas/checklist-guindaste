import 'package:material_ui/material_ui.dart';

/// Utilitários de responsividade para adaptação fluida entre smartphones e tablets.
class Responsivo {
  Responsivo._();

  static const double breakpointTablet = 680;
  static const double breakpointTabletGrande = 1000;

  static bool ehTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointTablet;

  static bool ehTabletGrande(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointTabletGrande;

  /// Padding padrão respeitando a barra de navegação do sistema (Android).
  static EdgeInsets paddingPagina(BuildContext context) {
    final tablet = ehTablet(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      tablet ? 24 : 16,
      tablet ? 20 : 16,
      tablet ? 24 : 16,
      (tablet ? 24 : 20) + bottomInset,
    );
  }
}

/// Centraliza horizontalmente o conteúdo em tablets sem expandir verticalmente
/// (seguro inclusive dentro de headers e rodapés).
class ContainerResponsivo extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContainerResponsivo({
    super.key,
    required this.child,
    this.maxWidth = 1040,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
