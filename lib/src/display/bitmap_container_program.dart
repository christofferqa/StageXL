part of stagexl.display;

class _BitmapContainerProgram extends RenderProgram {

  final BitmapProperty bitmapBitmapData;
  final BitmapProperty bitmapPosition;
  final BitmapProperty bitmapPivot;
  final BitmapProperty bitmapScale;
  final BitmapProperty bitmapSkew;
  final BitmapProperty bitmapRotation;
  final BitmapProperty bitmapAlpha;
  final BitmapProperty bitmapVisible;

  RenderBufferIndex _renderBufferIndex = null;
  int _dynStride = 0;
  int _staStride = 0;
  int _quadsMax = 0;

  //---------------------------------------------------------------------------

  _BitmapContainerProgram(
      this.bitmapBitmapData, this.bitmapPosition,
      this.bitmapPivot, this.bitmapScale, this.bitmapSkew,
      this.bitmapRotation, this.bitmapAlpha, this.bitmapVisible) {

    _dynStride = _calculateStride(BitmapProperty.Dynamic);
    _staStride = _calculateStride(BitmapProperty.Static);
    _quadsMax = minInt(2048, 65536 ~/ maxInt(_staStride, _dynStride));
  }

  //---------------------------------------------------------------------------
  // aBitmapData : Float32(x), Float32(y), Float32(u), Float32(v),
  // aPosition   : Float32(x), Float32(y)
  // aPivot      : Float32(x), Float32(y)
  // aScale      : Float32(x), Float32(y)
  // aSkew       : Float32(x), Float32(y)
  // aRotation   : Float32(r)
  // aAlpha      : Float32(a)
  //---------------------------------------------------------------------------

  String get vertexShaderSource => _modifyVertexShader("""

    uniform mat4 uProjectionMatrix;
    uniform mat3 uGlobalMatrix;
    uniform float uGlobalAlpha;

    attribute vec4 aBitmapData;
    attribute vec2 aPosition;
    attribute vec2 aPivot;
    attribute vec2 aScale;
    attribute vec2 aSkew;
    attribute float aRotation;
    attribute float aAlpha;

    varying vec2 vCoord;
    varying float vAlpha;

    void main() {

      mat4 transform = mat4(uGlobalMatrix) * uProjectionMatrix;
      vec2 skew = aSkew + aRotation;
      vec2 offset = aBitmapData.xy - aPivot; 
      vec2 offsetScaled = offset * aScale;
      vec2 offsetSkewed = vec2(
           offsetScaled.x * cos(skew.y) - offsetScaled.y * sin(skew.x), 
           offsetScaled.x * sin(skew.y) + offsetScaled.y * cos(skew.x));

      gl_Position = vec4(aPosition + offsetSkewed, 0.0, 1.0) * transform;
      vCoord  = aBitmapData.pq;  
      vAlpha = aAlpha * uGlobalAlpha;
    }
    """);

  String get fragmentShaderSource => """

    precision mediump float;
    uniform sampler2D uSampler;
  
    varying vec2 vCoord;
    varying float vAlpha;
  
    void main() {
      gl_FragColor = texture2D(uSampler, vCoord) * vAlpha;
    }
    """;

  //---------------------------------------------------------------------------

  @override
  void activate(RenderContextWebGL renderContext) {

    super.activate(renderContext);
    super.renderingContext.uniform1i(uniforms["uSampler"], 0);

    _renderBufferIndex = renderContext.renderBufferIndexQuads;
    _renderBufferIndex.activate(renderContext);
  }

  @override
  void flush() {
    // This RenderProgram has a built in draw call batching,
    // therefore we don't need to flush anything to the GPU.
  }

  //---------------------------------------------------------------------------

  void renderBitmapContainer(RenderState renderState,
                             BitmapContainer container) {

    var renderContext = renderState.renderContext;
    var globalMatrix = renderState.globalMatrix;
    var globalAlpha = renderState.globalAlpha;

    var bitmaps = container._children;
    var dirtyMin = container._buffersDirtyMin;
    var dirtyMax = container._buffersDirtyMax;
    var dynBuffers = container._dynBuffers;
    var staBuffers = container._staBuffers;

    var uGlobalMatrix = new Float32List(9);
    var dynBitmapProperty = BitmapProperty.Dynamic;
    var staBitmapProperty = BitmapProperty.Static;

    uGlobalMatrix[0] = globalMatrix.a;
    uGlobalMatrix[1] = globalMatrix.c;
    uGlobalMatrix[2] = globalMatrix.tx;
    uGlobalMatrix[3] = globalMatrix.b;
    uGlobalMatrix[4] = globalMatrix.d;
    uGlobalMatrix[5] = globalMatrix.ty;

    renderingContext.uniformMatrix3fv(uniforms["uGlobalMatrix"], false, uGlobalMatrix);
    renderingContext.uniform1f(uniforms["uGlobalAlpha"], globalAlpha);

    // Prepare dynamic and static vertex buffers

    var dynStride = _dynStride;
    var staStride = _staStride;
    var quadsMax = _quadsMax;
    var bufferLength = (bitmaps.length + _quadsMax - 1) ~/ _quadsMax;

    while(dynBuffers.length < bufferLength) {
      dynBuffers.add(new RenderBufferVertex(quadsMax * dynStride * 4));
    }

    while(staBuffers.length < bufferLength) {
      staBuffers.add(new RenderBufferVertex(quadsMax * staStride * 4));
    }

    while(dynBuffers.length > bufferLength) {
      dynBuffers.removeLast().dispose();
    }

    while(staBuffers.length > bufferLength) {
      staBuffers.removeLast().dispose();
    }

    if (bufferLength == 0) {
      return;
    }

    // Update dynamic vertex buffers

    for(int i = 0; i < bitmaps.length; i++) {

      var bitmap = bitmaps[i];
      var index = i % quadsMax;
      var bufferIndex = i ~/ quadsMax;
      var dynBuffer = dynBuffers[bufferIndex];

      setQuadVertices(dynBitmapProperty, dynBuffer, dynStride, index, bitmap);

      if ((i + 1) % quadsMax == 0 || i == bitmaps.length - 1) {
        dynBuffer.activate(renderContext);
        renderingContext.bufferSubDataTyped(gl.ARRAY_BUFFER, 0, dynBuffer.data);
      }
    }

    // Update static vertex buffers

    for(int i = dirtyMin; i < dirtyMax; i++) {

      var bitmap = bitmaps[i];
      var index = i % quadsMax;
      var bufferIndex = i ~/ quadsMax;
      var staBuffer = staBuffers[bufferIndex];

      setQuadVertices(staBitmapProperty, staBuffer, staStride, index, bitmap);

      if ((i + 1) % quadsMax == 0 || i == dirtyMax - 1) {
        staBuffer.activate(renderContext);
        renderingContext.bufferSubDataTyped(gl.ARRAY_BUFFER, 0, staBuffer.data);
      }
    }

    container._buffersDirtyMin = 0xffffff;
    container._buffersDirtyMax = 0;

    // Render all Bitmaps

    var dynBuffer = dynBuffers.first;
    var staBuffer = dynBuffers.first;
    var activeRenderTexture = renderContext.activeRenderTexture;
    var context = renderingContext;

    int quadLimit = _quadsMax;
    int quadStart = 0;
    int quadIndex = 0;
    int bitmapIndex = 0;
    int triangles = gl.TRIANGLES;
    int uShort = gl.UNSIGNED_SHORT;

    while (bitmapIndex < bitmaps.length) {

      var bitmap = bitmaps[bitmapIndex];
      var bitmapData = bitmap.bitmapData;
      var renderTexture = bitmapData.renderTexture;
      var textureCheck = identical(activeRenderTexture, renderTexture);
      var textureFlush = false;

      if (textureCheck) {
        bitmapIndex += 1;
        quadIndex += 1;
        textureFlush = bitmapIndex == bitmaps.length || quadIndex == quadLimit;
      } else {
        textureFlush = quadIndex > quadStart;
      }

      if (textureFlush) {

        var offset = quadStart;
        var length = quadIndex - quadStart;
        var bufferIndex = (bitmapIndex - length) ~/ quadsMax;
        var dynBuffer = dynBuffers[bufferIndex];
        var staBuffer = staBuffers[bufferIndex];

        dynBuffer.activate(renderContext);
        bindAttributes(dynBitmapProperty, dynBuffer, dynStride);
        staBuffer.activate(renderContext);
        bindAttributes(staBitmapProperty, staBuffer, staStride);
        context.drawElements(triangles, length * 6, uShort, offset * 12);

        if (quadIndex == quadLimit && bitmapIndex < bitmaps.length) {
          quadStart = quadIndex = 0;
        } else {
          quadStart = quadIndex;
        }
      }

      if (textureCheck == false) {
        activeRenderTexture = renderTexture;
        renderContext.activateRenderTexture(renderTexture);
      }
    }
  }

  //---------------------------------------------------------------------------

  int _calculateStride(BitmapProperty bitmapProperty) {
    int stride = 0;
    if (bitmapBitmapData == bitmapProperty) stride += 4;
    if (bitmapPosition == bitmapProperty) stride += 2;
    if (bitmapPivot == bitmapProperty) stride += 2;
    if (bitmapScale == bitmapProperty) stride += 2;
    if (bitmapSkew == bitmapProperty) stride += 2;
    if (bitmapRotation == bitmapProperty) stride += 1;
    if (bitmapAlpha == bitmapProperty) stride += 1;
    return stride;
  }

  //---------------------------------------------------------------------------

  String _modifyVertexShader(String vertexShader) {

    var regex = new RegExp(r"attribute\s+([a-z0-9]+)\s+([a-zA-Z0-9]+)\s*;");
    var ignore = BitmapProperty.Ignore;

    return vertexShader.replaceAllMapped(regex, (match) {
      var name = match.group(2);
      if (name == "aPivot" && bitmapPivot == ignore) {
        return "const vec2 aPivot = vec2(0.0, 0.0);";
      } else if (name == "aScale" && bitmapScale == ignore) {
        return "const vec2 aScale = vec2(1.0, 1.0);";
      } else if (name == "aSkew" && bitmapScale == ignore) {
        return "const vec2 aSkew = vec2(0.0, 0.0);";
      } else if (name == "aRotation" && bitmapRotation == ignore) {
        return "const float aRotation = 0.0;";
      } if (name == "aAlpha" && bitmapAlpha == ignore) {
        return "const float aAlpha = 1.0;";
      } else {
        return match.group(0);
      }
    });
  }

  //---------------------------------------------------------------------------

  void setQuadVertices(BitmapProperty bitmapProperty,
                       RenderBufferVertex buffer, int stride,
                       int index, Bitmap bitmap) {

    var data = buffer.data;
    var quadOffset  = index * stride * 4;
    var vertex0 = stride * 0;
    var vertex1 = stride * 1;
    var vertex2 = stride * 2;
    var vertex3 = stride * 3;

    if (this.bitmapBitmapData == bitmapProperty) {
      var renderTextureQuad = bitmap.bitmapData.renderTextureQuad;
      var quadX = renderTextureQuad.offsetX.toDouble();
      var quadY = renderTextureQuad.offsetY.toDouble();
      var quadWidth = renderTextureQuad.textureWidth.toDouble();
      var quadHeight = renderTextureQuad.textureHeight.toDouble();
      var quadUVs = renderTextureQuad.uvList;
      data[quadOffset + vertex0 + 0] = quadX;
      data[quadOffset + vertex0 + 1] = quadY;
      data[quadOffset + vertex0 + 2] = quadUVs[0];
      data[quadOffset + vertex0 + 3] = quadUVs[1];
      data[quadOffset + vertex1 + 0] = quadX + quadWidth;
      data[quadOffset + vertex1 + 1] = quadY;
      data[quadOffset + vertex1 + 2] = quadUVs[2];
      data[quadOffset + vertex1 + 3] = quadUVs[3];
      data[quadOffset + vertex2 + 0] = quadX + quadWidth;
      data[quadOffset + vertex2 + 1] = quadY + quadHeight;
      data[quadOffset + vertex2 + 2] = quadUVs[4];
      data[quadOffset + vertex2 + 3] = quadUVs[5];
      data[quadOffset + vertex3 + 0] = quadX;
      data[quadOffset + vertex3 + 1] = quadY + quadHeight;
      data[quadOffset + vertex3 + 2] = quadUVs[6];
      data[quadOffset + vertex3 + 3] = quadUVs[7];
      quadOffset += 4;
    }

    if (this.bitmapPosition == bitmapProperty) {
      var x = bitmap.x.toDouble();
      var y = bitmap.y.toDouble();
      data[quadOffset + vertex0 + 0] = x;
      data[quadOffset + vertex0 + 1] = y;
      data[quadOffset + vertex1 + 0] = x;
      data[quadOffset + vertex1 + 1] = y;
      data[quadOffset + vertex2 + 0] = x;
      data[quadOffset + vertex2 + 1] = y;
      data[quadOffset + vertex3 + 0] = x;
      data[quadOffset + vertex3 + 1] = y;
      quadOffset += 2;
    }

    if (this.bitmapPivot == bitmapProperty) {
      var pivotX = bitmap.pivotX.toDouble();
      var pivotY = bitmap.pivotY.toDouble();
      data[quadOffset + vertex0 + 0] = pivotX;
      data[quadOffset + vertex0 + 1] = pivotY;
      data[quadOffset + vertex1 + 0] = pivotX;
      data[quadOffset + vertex1 + 1] = pivotY;
      data[quadOffset + vertex2 + 0] = pivotX;
      data[quadOffset + vertex2 + 1] = pivotY;
      data[quadOffset + vertex3 + 0] = pivotX;
      data[quadOffset + vertex3 + 1] = pivotY;
      quadOffset += 2;
    }

    if (this.bitmapScale == bitmapProperty) {
      var scaleX = bitmap.scaleX.toDouble();
      var scaleY = bitmap.scaleY.toDouble();
      data[quadOffset + vertex0 + 0] = scaleX;
      data[quadOffset + vertex0 + 1] = scaleY;
      data[quadOffset + vertex1 + 0] = scaleX;
      data[quadOffset + vertex1 + 1] = scaleY;
      data[quadOffset + vertex2 + 0] = scaleX;
      data[quadOffset + vertex2 + 1] = scaleY;
      data[quadOffset + vertex3 + 0] = scaleX;
      data[quadOffset + vertex3 + 1] = scaleY;
      quadOffset += 2;
    }

    if (this.bitmapSkew == bitmapProperty) {
      var skewX = bitmap.skewX.toDouble();
      var skewY = bitmap.skewY.toDouble();
      data[quadOffset + vertex0 + 0] = skewX;
      data[quadOffset + vertex0 + 1] = skewY;
      data[quadOffset + vertex1 + 0] = skewX;
      data[quadOffset + vertex1 + 1] = skewY;
      data[quadOffset + vertex2 + 0] = skewX;
      data[quadOffset + vertex2 + 1] = skewY;
      data[quadOffset + vertex3 + 0] = skewX;
      data[quadOffset + vertex3 + 1] = skewY;
      quadOffset += 2;
    }

    if (this.bitmapRotation == bitmapProperty) {
      var rotation = bitmap.rotation.toDouble();
      data[quadOffset + vertex0 + 0] = rotation;
      data[quadOffset + vertex1 + 0] = rotation;
      data[quadOffset + vertex2 + 0] = rotation;
      data[quadOffset + vertex3 + 0] = rotation;
      quadOffset += 1;
    }

    if (this.bitmapAlpha == bitmapProperty) {
      var alpha = bitmap.alpha.toDouble();
      data[quadOffset + vertex0 + 0] = alpha;
      data[quadOffset + vertex1 + 0] = alpha;
      data[quadOffset + vertex2 + 0] = alpha;
      data[quadOffset + vertex3 + 0] = alpha;
      quadOffset += 1;
    }
  }

  //---------------------------------------------------------------------------

  void bindAttributes(BitmapProperty bitmapProperty,
                      RenderBufferVertex buffer, int stride) {

    int offset = 0;

    if (this.bitmapBitmapData == bitmapProperty) {
      var aBitmapData = attributes["aBitmapData"];
      buffer.bindAttribute(aBitmapData, 4, 4 * stride, offset);
      offset += 16;
    }

    if (this.bitmapPosition == bitmapProperty) {
      var aPosition = attributes["aPosition"];
      buffer.bindAttribute(aPosition, 2, 4 * stride, offset);
      offset += 8;
    }

    if (this.bitmapPivot == bitmapProperty) {
      var aPivot = attributes["aPivot"];
      buffer.bindAttribute(aPivot, 2, 4 * stride, offset);
      offset += 8;
    }

    if (this.bitmapScale == bitmapProperty) {
      var aScale = attributes["aScale"];
      buffer.bindAttribute(aScale, 2, 4 * stride, offset);
      offset += 8;
    }

    if (this.bitmapSkew == bitmapProperty) {
      var aSkew = attributes["aSkew"];
      buffer.bindAttribute(aSkew, 2, 4 * stride, offset);
      offset += 8;
    }

    if (this.bitmapRotation == bitmapProperty) {
      var aRotation = attributes["aRotation"];
      buffer.bindAttribute(aRotation, 1, 4 * stride, offset);
      offset += 4;
    }

    if (this.bitmapAlpha == bitmapProperty) {
      var aAlpha = attributes["aAlpha"];
      buffer.bindAttribute(aAlpha, 1, 4 * stride, offset);
      offset += 4;
    }
  }


}
