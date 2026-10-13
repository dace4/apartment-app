/// US-11: normalized coordinates keep signatures independent of screen size.
class SignaturePoint {
  const SignaturePoint(this.x, this.y);
  final double x;
  final double y;
  bool get isValid =>
      x.isFinite && y.isFinite && x >= 0 && x <= 1 && y >= 0 && y <= 1;
  List<double> toList() => [x, y];
}
