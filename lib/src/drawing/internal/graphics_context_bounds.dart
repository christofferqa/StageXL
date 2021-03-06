part of stagexl.drawing.internal;

class GraphicsContextBounds extends GraphicsContext {

  double _minX = 0.0 + double.MAX_FINITE;
  double _minY = 0.0 + double.MAX_FINITE;
  double _maxX = 0.0 - double.MAX_FINITE;
  double _maxY = 0.0 - double.MAX_FINITE;

  //---------------------------------------------------------------------------

  double get minX => _minX;
  double get minY => _minY;
  double get maxX => _maxX;
  double get maxY => _maxY;

  Rectangle<num> get bounds {
    if (minX < maxX && minY < maxY) {
      return new Rectangle<double>(minX, minY, maxX - minX, maxY - minY);
    } else {
      return new Rectangle<double>(0.0, 0.0, 0.0, 0.0);
    }
  }

  //---------------------------------------------------------------------------

  @override
  void fillColor(int color) {
    _updateBoundsForFill();
  }

  @override
  void fillGradient(GraphicsGradient gradient) {
    _updateBoundsForFill();
  }

  @override
  void fillPattern(GraphicsPattern pattern) {
    _updateBoundsForFill();
  }

  @override
  void strokeColor(int color, double lineWidth, String lineJoin, String lineCap) {
    _updateBoundsForStroke(lineWidth, lineJoin, lineCap);
  }

  @override
  void strokeGradient(GraphicsGradient gradient, double lineWidth, String lineJoin, String lineCap) {
    _updateBoundsForStroke(lineWidth, lineJoin, lineCap);
  }

  @override
  void strokePattern(GraphicsPattern pattern, double lineWidth, String lineJoin, String lineCap) {
    _updateBoundsForStroke(lineWidth, lineJoin, lineCap);
  }

  //---------------------------------------------------------------------------

  void _updateBoundsForFill() {
    for(var segment in _path.segments) {
      _minX = _minX > segment.minX ? segment.minX : _minX;
      _minY = _minY > segment.minY ? segment.minY : _minY;
      _maxX = _maxX < segment.maxX ? segment.maxX : _maxX;
      _maxY = _maxY < segment.maxY ? segment.maxY : _maxY;
    }
  }

  void _updateBoundsForStroke(double lineWidth, String lineJoin, String lineCap) {
    // TODO: revisit this code once we have stroke paths.
    double w = lineWidth / 2.0;
    for(var segment in _path.segments) {
      _minX = _minX > segment.minX - w ? segment.minX - w : _minX;
      _minY = _minY > segment.minY - w ? segment.minY - w : _minY;
      _maxX = _maxX < segment.maxX + w ? segment.maxX + w : _maxX;
      _maxY = _maxY < segment.maxY + w ? segment.maxY + w : _maxY;
    }
  }

}
