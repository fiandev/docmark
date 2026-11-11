/// The vault has no blob for the requested reference.
final class MissingAssetFailure implements Exception {
  const MissingAssetFailure(this.assetId);

  final String assetId;

  @override
  String toString() => 'MissingAssetFailure: $assetId';
}
