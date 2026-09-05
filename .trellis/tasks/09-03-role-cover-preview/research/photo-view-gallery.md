# PhotoView gallery integration

Verified on 2026-09-05 against published `photo_view` 0.15.0 source installed by
`flutter pub add photo_view:0.15.0`. This added one dependency without updating
existing locked packages.

Sources:
- https://pub.dev/packages/photo_view
- https://pub.dev/documentation/photo_view/latest/photo_view/PhotoView-class.html
- Package files: `lib/photo_view_gallery.dart`,
  `lib/src/core/photo_view_gesture_detector.dart`,
  `lib/src/photo_view_wrappers.dart`.

Use `PhotoViewGallery.builder(itemCount, builder, pageController,
onPageChanged, backgroundDecoration)`. Each builder returns
`PhotoViewGalleryPageOptions(imageProvider: FileImage(file), initialScale,
minScale, maxScale, onTapUp, errorBuilder, semanticLabel)`.

- `PhotoViewComputedScale.contained` fits the original image without cropping.
  Use it for initial/minimum scale; cap maximum at contained times five.
- `PhotoViewGallery` supplies a horizontal gesture scope and a `PageView`.
  Its image gesture recognizer yields at image edges and accepts multi-pointer
  scaling. Do not implement a competing horizontal drag or scale recognizer.
- `PhotoView` uses tap, double-tap and scale recognizers in the gesture arena.
  Attach single-tap dismissal to `onTapUp`, not pointer-down callbacks.
- Gallery page options forward `errorBuilder`, but the image loading/failure
  widget does not have the loaded image's tap handler. Give failure/empty
  content its own tap callback and retain a separate close button.
- The route owns and disposes its `PageController`. Copy the input path list
  for the route session; safely clamp initial indices and handle empty lists.
- Keep `CoverPath.resolve` for sandbox-relative and legacy absolute paths.
  No role model, picker or database changes are needed for the gallery API.

Validation must load real images before gestures. Widget tests should precache
`FileImage` through `tester.runAsync` before opening the route, then assert actual
image transforms, page transitions and route dismissal. A widget-type assertion
alone cannot prove that images decoded or pinch gestures work.
