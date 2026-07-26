import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_colors.dart';

/// Banner offline que aparece no topo — Kinetic Dark.
class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: AppColors.errorContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Text(
            'Estás offline',
            style: GoogleFonts.inter(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
