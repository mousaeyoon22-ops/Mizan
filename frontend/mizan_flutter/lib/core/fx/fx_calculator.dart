/// Pure integer-math FX spread & gain/loss calculator (Zero IEEE-754 double drift).
/// Amounts scaled x10,000 (minor units); Rates scaled x1,000,000 (micro units).
class FxExchangePreview {
  final int sourceBaseMinor;
  final int targetBaseMinor;
  final int fxDiffBaseMinor; // > 0 Gain (ربح مصارفة), < 0 Loss (مصروف/فرق مصارفة)

  const FxExchangePreview({
    required this.sourceBaseMinor,
    required this.targetBaseMinor,
    required this.fxDiffBaseMinor,
  });

  bool get isGain => fxDiffBaseMinor > 0;
  bool get isLoss => fxDiffBaseMinor < 0;
}

class FxCalculator {
  static const int rateScale = 1000000;

  static int convertToBaseMinor(int amountMinor, int rateMicro) {
    final prod = BigInt.from(amountMinor) * BigInt.from(rateMicro);
    const half = 500000;
    final rounded = prod >= BigInt.zero
        ? (prod + BigInt.from(half)) ~/ BigInt.from(rateScale)
        : (prod - BigInt.from(half)) ~/ BigInt.from(rateScale);
    return rounded.toInt();
  }

  static FxExchangePreview computeDirectExchange({
    required int sourceAmountMinor,
    required int sourceBookRateMicro,
    required int targetAmountMinor,
    required int targetBookRateMicro,
  }) {
    final srcBase = convertToBaseMinor(sourceAmountMinor, sourceBookRateMicro);
    final tgtBase = convertToBaseMinor(targetAmountMinor, targetBookRateMicro);
    return FxExchangePreview(
      sourceBaseMinor: srcBase,
      targetBaseMinor: tgtBase,
      fxDiffBaseMinor: tgtBase - srcBase,
    );
  }
}
