import 'package:flutter/material.dart';
import '../theme/mizan_theme.dart';

class MizanKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const MizanKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MizanColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: MizanColors.muted,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MizanBadge extends StatelessWidget {
  final String text;
  final Color color;

  const MizanBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Deterministic visual QR matrix widget (zero native dependencies).
class MizanVisualQrBox extends StatelessWidget {
  final String data;
  final double size;

  const MizanVisualQrBox({super.key, required this.data, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MizanColors.borderLight),
      ),
      child: CustomPaint(painter: _QrMatrixPainter(data)),
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  final String data;
  _QrMatrixPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    const int n = 15;
    final cell = size.width / n;
    final paint = Paint()..color = const Color(0xFF0F172A);
    int hash = 2166136261;
    for (final c in data.codeUnits) {
      hash ^= c;
      hash = (hash * 16777619) & 0xffffffff;
    }

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final inTopLeft = r < 4 && c < 4;
        final inTopRight = r < 4 && c >= n - 4;
        final inBottomLeft = r >= n - 4 && c < 4;
        bool fill = false;
        if (inTopLeft || inTopRight || inBottomLeft) {
          final rr = r >= n - 4 ? r - (n - 4) : r;
          final cc = c >= n - 4 ? c - (n - 4) : c;
          fill = rr == 0 || rr == 3 || cc == 0 || cc == 3 || (rr == 1 && cc == 1) || (rr == 2 && cc == 2);
        } else {
          final bit = ((hash >> ((r * n + c) % 31)) ^ (r * 7 + c * 13)) & 1;
          fill = bit == 1;
        }
        if (fill) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) => oldDelegate.data != data;
}
