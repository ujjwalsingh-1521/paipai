import 'package:flutter/material.dart';

/// PaiPai's brand blue (from the logo). Every other color comes from
/// Material 3 tonal palettes built on it, so light and dark stay in step.
const brandSeed = Color(0xFF2C4FBD);

/// The spacing scale: every gap and padding in the app is one of these.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Corner radii, smallest to largest.
abstract final class Corners {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const extraLarge = 28.0;
}

/// Colors Material's scheme has no role for: money coming in. Money going
/// out is plain text (spending is normal, so it isn't shown as an alarm).
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  final Color income;
  final Color incomeContainer;
  final Color onIncomeContainer;

  const MoneyColors({
    required this.income,
    required this.incomeContainer,
    required this.onIncomeContainer,
  });

  static const light = MoneyColors(
    income: Color(0xFF1B7A43),
    incomeContainer: Color(0xFFB9F0C8),
    onIncomeContainer: Color(0xFF00210D),
  );

  static const dark = MoneyColors(
    income: Color(0xFF7DD99A),
    incomeContainer: Color(0xFF00522A),
    onIncomeContainer: Color(0xFFB9F0C8),
  );

  @override
  MoneyColors copyWith({Color? income, Color? incomeContainer, Color? onIncomeContainer}) =>
      MoneyColors(
        income: income ?? this.income,
        incomeContainer: incomeContainer ?? this.incomeContainer,
        onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      onIncomeContainer: Color.lerp(onIncomeContainer, other.onIncomeContainer, t)!,
    );
  }
}

/// Shorthands used across the UI: `context.colors.primary`,
/// `context.text.titleMedium`, `context.money.income`.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  MoneyColors get money => Theme.of(this).extension<MoneyColors>()!;
}

/// A category's own color as a soft circle background and a readable icon
/// color on it, in either theme.
({Color background, Color foreground}) categoryTint(BuildContext context, Color color) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? (background: color.withAlpha(56), foreground: Color.lerp(color, Colors.white, 0.35)!)
      : (background: color.withAlpha(40), foreground: Color.lerp(color, Colors.black, 0.35)!);
}

class AppTheme {
  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: brandSeed, brightness: brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'RobotoFlex');
    final text = _textTheme(base.textTheme);
    final pill = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.large)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.medium)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.medium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.medium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          shape: pill,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          shape: pill,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(textStyle: WidgetStatePropertyAll(text.labelLarge)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(textStyle: WidgetStatePropertyAll(text.labelLarge)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.extraLarge)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.extraLarge)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corners.small)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Space.l),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      extensions: [brightness == Brightness.dark ? MoneyColors.dark : MoneyColors.light],
    );
  }

  /// Roboto Flex everywhere, the large-size cut for big numbers, and
  /// fixed-width digits so amounts line up in lists.
  static TextTheme _textTheme(TextTheme base) {
    const digits = [FontFeature.tabularFigures()];
    TextStyle? display(TextStyle? style, FontWeight weight) => style?.copyWith(
        fontFamily: 'RobotoFlexDisplay', fontWeight: weight, fontFeatures: digits, letterSpacing: -0.5);
    TextStyle? body(TextStyle? style, [FontWeight? weight]) =>
        style?.copyWith(fontWeight: weight, fontFeatures: digits);
    return base.copyWith(
      displayLarge: display(base.displayLarge, FontWeight.w700),
      displayMedium: display(base.displayMedium, FontWeight.w700),
      displaySmall: display(base.displaySmall, FontWeight.w700),
      headlineLarge: display(base.headlineLarge, FontWeight.w600),
      headlineMedium: display(base.headlineMedium, FontWeight.w600),
      headlineSmall: display(base.headlineSmall, FontWeight.w600),
      titleLarge: body(base.titleLarge, FontWeight.w600),
      titleMedium: body(base.titleMedium, FontWeight.w600),
      titleSmall: body(base.titleSmall, FontWeight.w600),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge, FontWeight.w600),
      labelMedium: body(base.labelMedium, FontWeight.w500),
      labelSmall: body(base.labelSmall, FontWeight.w500),
    );
  }
}

/// No Android "stretch" or glow when a list hits its end; lists simply stop.
class CalmScrollBehavior extends MaterialScrollBehavior {
  const CalmScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}
