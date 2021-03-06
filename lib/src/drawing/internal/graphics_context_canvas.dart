part of stagexl.drawing.internal;

class GraphicsContextCanvas extends GraphicsContext {

  final RenderState renderState;
  final RenderContextCanvas _renderContext;
  final CanvasRenderingContext2D _canvasContext;

  GraphicsContextCanvas(RenderState renderState) :
     renderState = renderState,
    _renderContext = renderState.renderContext,
    _canvasContext = (renderState.renderContext as RenderContextCanvas).rawContext {
    _renderContext.setTransform(renderState.globalMatrix);
    _renderContext.setAlpha(renderState.globalAlpha);
    _canvasContext.beginPath();
  }

  //---------------------------------------------------------------------------

  @override
  void beginPath() {
    _canvasContext.beginPath();
  }

  @override
  void closePath() {
    _canvasContext.closePath();
  }

  @override
  void setPath(GraphicsPath path) {
    throw new UnsupportedError("Setting the path is not supported.");
  }

  //---------------------------------------------------------------------------

  @override
  void moveTo(double x, double y) {
    _canvasContext.moveTo(x, y);
  }

  @override
  void lineTo(double x, double y) {
    _canvasContext.lineTo(x, y);
  }

  @override
  void arcTo(double controlX, double controlY, double endX, double endY, double radius) {
    _canvasContext.arcTo(controlX, controlY, endX, endY, radius);
  }

  @override
  void quadraticCurveTo(double controlX, double controlY, double endX, double endY) {
    _canvasContext.quadraticCurveTo(controlX, controlY, endX, endY);
  }

  @override
  void bezierCurveTo(double controlX1, double controlY1, double controlX2, double controlY2, double endX, double endY) {
    _canvasContext.bezierCurveTo(controlX1, controlY1, controlX2, controlY2, endX, endY);
  }

  @override
  void rect(double x, double y, double width, double height) {
    _canvasContext.rect(x, y, width, height);
  }

  @override
  void arc(double x, double y, double radius, double startAngle, double endAngle, bool antiClockwise) {
    _canvasContext.arc(x, y, radius, startAngle, endAngle, antiClockwise);
  }

  //---------------------------------------------------------------------------

  @override
  void fillColor(int color) {
    _canvasContext.fillStyle = color2rgba(color);
    _canvasContext.fill();
  }

  @override
  void fillGradient(GraphicsGradient gradient) {
    _canvasContext.fillStyle = gradient.getCanvasGradient(_canvasContext);
    _canvasContext.fill();
  }

  @override
  void fillPattern(GraphicsPattern pattern) {

    _canvasContext.fillStyle = pattern.getCanvasPattern(_canvasContext);

    var matrix = pattern.matrix;
    if (matrix != null) {
      _canvasContext.save();
      _canvasContext.transform(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty);
      _canvasContext.fill();
      _canvasContext.restore();
    } else {
      _canvasContext.fill();
    }
  }

  //---------------------------------------------------------------------------

  @override
  void strokeColor(int color, double lineWidth, String lineJoin, String lineCap) {
    _canvasContext.strokeStyle = color2rgba(color);
    _canvasContext.lineWidth = lineWidth;
    _canvasContext.lineJoin = lineJoin;
    _canvasContext.lineCap = lineCap;
    _canvasContext.stroke();
  }

  @override
  void strokeGradient(GraphicsGradient gradient, double lineWidth, String lineJoin, String lineCap) {
    _canvasContext.strokeStyle = gradient.getCanvasGradient(_canvasContext);
    _canvasContext.lineWidth = lineWidth;
    _canvasContext.lineJoin = lineJoin;
    _canvasContext.lineCap = lineCap;
    _canvasContext.stroke();
  }

  @override
  void strokePattern(GraphicsPattern pattern, double lineWidth, String lineJoin, String lineCap) {

    _canvasContext.strokeStyle = pattern.getCanvasPattern(_canvasContext);
    _canvasContext.lineWidth = lineWidth;
    _canvasContext.lineJoin = lineJoin;
    _canvasContext.lineCap = lineCap;

    var matrix = pattern.matrix;
    if (matrix != null) {
      _canvasContext.save();
      _canvasContext.transform(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty);
      _canvasContext.stroke();
      _canvasContext.restore();
    } else {
      _canvasContext.stroke();
    }
  }

}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

class GraphicsContextCanvasMask extends GraphicsContextCanvas {

  GraphicsContextCanvasMask(RenderState renderState) : super(renderState);

  @override
  void fillColor(int color) {
    // do nothing
  }

  @override
  void fillGradient(GraphicsGradient gradient) {
    // do nothing
  }

  @override
  void fillPattern(GraphicsPattern pattern) {
    // do nothing
  }

  @override
  void strokeColor(int color, double lineWidth, String lineJoin, String lineCap) {
    // do nothing
  }

  @override
  void strokeGradient(GraphicsGradient gradient, double lineWidth, String lineJoin, String lineCap) {
    // do nothing
  }

  @override
  void strokePattern(GraphicsPattern pattern, double lineWidth, String lineJoin, String lineCap) {
    // do nothing
  }
}
