import 'dart:convert';
import 'dart:typed_data';

/// Pure Dart ESC/POS 80mm/58mm Thermal Printer & Cash Drawer Kick Command Generator.
/// Works over USB, Bluetooth, or LAN TCP/9100 without proprietary vendor lock-in.
class EscPosReceiptBuilder {
  final List<int> _bytes = [];

  EscPosReceiptBuilder initialize() {
    _bytes.addAll([0x1B, 0x40]); // ESC @ — Initialize printer
    return this;
  }

  EscPosReceiptBuilder line(String text) {
    _bytes.addAll(utf8.encode('$text\n'));
    return this;
  }

  EscPosReceiptBuilder separator({int width = 42}) {
    _bytes.addAll(utf8.encode('${'-' * width}\n'));
    return this;
  }

  EscPosReceiptBuilder kickCashDrawer() {
    // ESC p 0 25 250 — Standard RJ11 cash drawer pulse
    _bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    return this;
  }

  EscPosReceiptBuilder cutPaper() {
    _bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V B 0 — Partial cut
    return this;
  }

  Uint8List build() => Uint8List.fromList(_bytes);
}
