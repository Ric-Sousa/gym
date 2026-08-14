import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme tokens that change with the student's gender preference.
///
/// Student screens should read these values from the current [BuildContext]
/// instead of using the static pink aliases in [AppColors].
class StudentThemeColors extends ThemeExtension<StudentThemeColors> {
  final Color primary;
  final Color primaryDim;
  final Color primaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;

  const StudentThemeColors({
    required this.primary,
    required this.primaryDim,
    required this.primaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
  });

  factory StudentThemeColors.forGenero(String? genero) {
    final isMale = genero == 'masculino';
    return StudentThemeColors(
      primary: isMale ? AppColors.malePrimary : AppColors.femalePrimary,
      primaryDim: isMale
          ? AppColors.malePrimaryDim
          : AppColors.femalePrimaryDim,
      primaryContainer: isMale
          ? AppColors.malePrimaryContainer
          : AppColors.femalePrimaryContainer,
      primaryFixed: isMale
          ? AppColors.malePrimaryFixed
          : AppColors.femalePrimaryFixed,
      primaryFixedDim: isMale
          ? AppColors.malePrimaryFixedDim
          : AppColors.femalePrimaryFixedDim,
    );
  }

  static StudentThemeColors of(BuildContext context) {
    return Theme.of(context).extension<StudentThemeColors>() ??
        StudentThemeColors.forGenero(null);
  }

  @override
  StudentThemeColors copyWith({
    Color? primary,
    Color? primaryDim,
    Color? primaryContainer,
    Color? primaryFixed,
    Color? primaryFixedDim,
  }) {
    return StudentThemeColors(
      primary: primary ?? this.primary,
      primaryDim: primaryDim ?? this.primaryDim,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      primaryFixed: primaryFixed ?? this.primaryFixed,
      primaryFixedDim: primaryFixedDim ?? this.primaryFixedDim,
    );
  }

  @override
  StudentThemeColors lerp(StudentThemeColors? other, double t) {
    if (other is! StudentThemeColors) return this;
    return StudentThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      primaryFixed: Color.lerp(primaryFixed, other.primaryFixed, t)!,
      primaryFixedDim: Color.lerp(primaryFixedDim, other.primaryFixedDim, t)!,
    );
  }
}
