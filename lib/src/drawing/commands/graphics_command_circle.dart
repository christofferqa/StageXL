part of stagexl.drawing.commands;

class GraphicsCommandCircle extends GraphicsCommand {

  final double x;
  final double y;
  final double radius;
  final bool antiClockwise;

  GraphicsCommandCircle(
      num x, num y, num radius, bool antiClockwise) :

      this.x = x.toDouble(),
      this.y = y.toDouble(),
      this.radius = radius.toDouble(),
      this.antiClockwise = antiClockwise;

  //---------------------------------------------------------------------------

  @override
  void updateContext(GraphicsContext context) {
    context.moveTo(x + radius, y);
    context.arc(x, y, radius, 0.0, 2 * math.PI, antiClockwise);
  }
}
