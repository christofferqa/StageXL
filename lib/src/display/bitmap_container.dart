part of stagexl.display;

/// This enum defines how the properties (position, rotation, ...) of
/// the Bitmaps in the [BitmapContainer] will affect the rendering.

enum BitmapProperty {
  /// The bitmap property is dynamic and therefore it is uploaded to the
  /// GPU on every frame. This is the standard behavior you get from
  /// standard DisplayObjects other than the BitmapContainer.
  Dynamic,
  /// The bitmap property is static and therefore it is only uploaded to
  /// the GPU once. Changes to the value of the property will not affect
  /// the rendering.
  Static,
  /// The bitmap property is ignored and does not affect the rendering
  /// at all. Setting a bitmap property to this state will save memory
  /// and time when uploading the other properties to the GPU.
  Ignore
}

/// The BitmapContainer class is an optimized container for Bitmaps.
///
/// You can only add Bitmaps and you have to decide which properties of the
/// Bitmap should be used for the rendering. If a property is not used you
/// should set it to [BitmapProperty.Ignore]. If a property isn't changed
/// after the Bitmap was added to the container you should set it to
/// [BitmapProperty.Static]. Only properties that change regularly
/// (like the position) should be set to [BitmapProperty.Dynamic].
///
/// You can define the behavior of properties shown below.
///
/// [BitmapContainer.bitmapBitmapData]: Default is Static
/// [BitmapContainer.bitmapPosition]: Default is Dynamic
/// [BitmapContainer.bitmapPivot]: Default is Ignore
/// [BitmapContainer.bitmapScale]: Default is Ignore
/// [BitmapContainer.bitmapSkew]: Default is Ignore
/// [BitmapContainer.bitmapRotation]: Default is Ignore
/// [BitmapContainer.bitmapAlpha]: Default is Ignore
/// [BitmapContainer.bitmapVisible]: Default is Ignore
///
/// For additional performance the [BitmapContainer] does not dispatch events
/// when Bitmaps are added or removed like the [DisplayObjectContainer] does.
/// Also the childrens [Bitmap.filters] property is ignored by default.
///
/// Please note that the performance of the [BitmapContainer] may be inferior
/// compared to a standard container like [Sprite]. You will only get better
/// performance if the [BitmapContainer] contains lots of children where
/// several properties are set to ignore or static. Please profile!

class BitmapContainer
    extends InteractiveObject with IterableMixin<Bitmap>
    implements DisplayObjectParent {

  final BitmapProperty bitmapBitmapData;
  final BitmapProperty bitmapPosition;
  final BitmapProperty bitmapPivot;
  final BitmapProperty bitmapScale;
  final BitmapProperty bitmapSkew;
  final BitmapProperty bitmapRotation;
  final BitmapProperty bitmapAlpha;
  final BitmapProperty bitmapVisible;

  final List<Bitmap> _children = new List<Bitmap>();
  final List<RenderBufferVertex> _dynBuffers = new List<RenderBufferVertex>();
  final List<RenderBufferVertex> _staBuffers = new List<RenderBufferVertex>();

  int _buffersDirtyMin = 0; // inclusive
  int _buffersDirtyMax = 0; // exclusive

  String _bitmapContainerProgramName = "";

  //---------------------------------------------------------------------------

  BitmapContainer({
    this.bitmapBitmapData: BitmapProperty.Static,
    this.bitmapPosition: BitmapProperty.Dynamic,
    this.bitmapPivot: BitmapProperty.Ignore,
    this.bitmapScale: BitmapProperty.Ignore,
    this.bitmapSkew: BitmapProperty.Ignore,
    this.bitmapRotation: BitmapProperty.Ignore,
    this.bitmapAlpha: BitmapProperty.Ignore,
    this.bitmapVisible: BitmapProperty.Ignore }) {

    if (this.bitmapBitmapData == BitmapProperty.Ignore) {
      throw new ArgumentError("The bitmapData property can't be ignored.");
    }

    if (this.bitmapPosition == BitmapProperty.Ignore) {
      throw new ArgumentError("The position properties can't be ignored.");
    }

    _bitmapContainerProgramName = r"$BitmapContainerProgram(" +
        this.bitmapBitmapData.toString() + "," +
        this.bitmapPosition.toString() + "," +
        this.bitmapPivot.toString() + "," +
        this.bitmapScale.toString() + "," +
        this.bitmapSkew.toString() + ")" +
        this.bitmapRotation.toString() + "," +
        this.bitmapAlpha.toString() + "," +
        this.bitmapVisible.toString() + ",";
  }

  //---------------------------------------------------------------------------

  void dispose() {
    while(_dynBuffers.length > 0) {
      _dynBuffers.removeLast().dispose();
    }
    while(_staBuffers.length > 0) {
      _staBuffers.removeLast().dispose();
    }
  }

  //---------------------------------------------------------------------------

  Iterator<Bitmap> get iterator => _children.iterator;

  int get numChildren => _children.length;

  void addChild(Bitmap child) {
    addChildAt(child, _children.length);
  }

  void addChildAt(Bitmap child, int index) {
    if (index < 0 || index > _children.length) {
      throw new RangeError.index(index, _children, "index");
    } else if (child.parent == this) {
      int oldIndex = _children.indexOf(child);
      int newIndex = minInt(index, _children.length - 1);
      int minIndex = minInt(oldIndex, newIndex);
      int maxIndex = maxInt(oldIndex, newIndex);
      _children.removeAt(oldIndex);
      _children.insert(newIndex, child);
      _buffersDirtyMin = minInt(_buffersDirtyMin, minIndex + 0);
      _buffersDirtyMax = maxInt(_buffersDirtyMax, maxIndex + 1);
    } else {
       child.removeFromParent();
       child._parent = this;
       _children.insert(index, child);
       _buffersDirtyMin = minInt(_buffersDirtyMin, index);
       _buffersDirtyMax = _children.length;
    }
  }

  void removeChild(Bitmap child) {
    int childIndex = _children.indexOf(child);
    if (childIndex == -1) {
      throw new ArgumentError("The Bitmap is not a child of this container.");
    } else {
      removeChildAt(childIndex);
    }
  }

  void removeChildAt(int index) {
    if (index < 0 || index >= _children.length) {
      throw new RangeError.index(index, _children, "index");
    } else {
      _children.removeAt(index)._parent = null;
      _buffersDirtyMin = minInt(_buffersDirtyMin, index);
      _buffersDirtyMax = _children.length;
    }
  }

  Bitmap getChildAt(int index) {
    if (index < 0 || index >= _children.length) {
      throw new RangeError.index(index, _children, "index");
    } else {
      return _children[index];
    }
  }

  Bitmap getChildByName(String name) {
    for(int i = 0; i < _children.length; i++) {
      var child = _children[i];
      if (child.name == name) return child;
    }
    return null;
  }

  int getChildIndex(Bitmap child) {
    return _children.indexOf(child);
  }

  //---------------------------------------------------------------------------

  /// A rectangle that defines the area of this display object in this display
  /// object's local coordinates.
  ///
  /// The [BitmapContainer] does not calculate the bounds based on its
  /// children, instead a setter is used to define the bounds manually.

  @override
  Rectangle<num> bounds = new Rectangle<num>(0.0, 0.0, 0.0, 0.0);

  /// The hitTestInput is calculated based on the [bounds] rectangle
  /// which is set manually and not calculated dynamically.

  @override
  DisplayObject hitTestInput(num localX, num localY) {
    return bounds.contains(localX, localY) ? this : null;
  }

  @override
  void render(RenderState renderState) {
    var renderContext = renderState.renderContext;
    if (renderContext is RenderContextWebGL) {
      _renderWebGL(renderState);
    } else if (renderContext is RenderContextCanvas) {
      _renderCanvas(renderState);
    } else {
      super.render(renderState);
    }
  }

  //---------------------------------------------------------------------------

  void _renderWebGL(RenderState renderState) {

    RenderContextWebGL renderContext = renderState.renderContext;

    _BitmapContainerProgram renderProgram = renderContext.getRenderProgram(
        _bitmapContainerProgramName, () => new _BitmapContainerProgram(
            this.bitmapBitmapData, this.bitmapPosition,
            this.bitmapPivot, this.bitmapScale, this.bitmapSkew,
            this.bitmapRotation, this.bitmapAlpha, this.bitmapVisible));

    renderContext.activateRenderProgram(renderProgram);
    renderContext.activateBlendMode(renderState.globalBlendMode);
    renderProgram.renderBitmapContainer(renderState, this);
  }

  //---------------------------------------------------------------------------

  void _renderCanvas(RenderState renderState) {

    var renderContext = renderState.renderContext;
    var renderContextCanvas = renderContext as RenderContextCanvas;

    renderContextCanvas.setTransform(renderState.globalMatrix);
    renderContextCanvas.setAlpha(renderState.globalAlpha);

    // TODO: implement optimized BitmapContainer code for canvas.

    for (int i = 0; i < numChildren; i++) {
      Bitmap bitmap = getChildAt(i);
      if (bitmap.visible && bitmap.off == false) {
        renderState.renderObject(bitmap);
      }
    }
  }


}
