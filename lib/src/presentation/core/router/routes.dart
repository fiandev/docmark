/// The app's named routes. [path] is the URL segment handed to
/// `GoRoute.path`; `name` (the enum member name) is what `GoRoute.name`
/// and named navigation (`context.pushNamed`) use. Keeping both on one
/// enum means path and name cannot drift, and switches over routes are
/// exhaustive.
///
/// Top-level routes carry absolute paths (leading `/`). Sub-routes carry
/// relative segments and nest under their parent in the route tree.
enum Routes {
  splash('/splash'),
  onboarding('/onboarding'),
  lock('/lock'),

  home('/home'),
  documentPicker('/document-picker'),
  editor('/editor/:documentId'),
  presets('/presets'),
  history('/history'),
  exportPreview('/export-preview'),
  settings('/settings');

  const Routes(this.path);

  final String path;
}
