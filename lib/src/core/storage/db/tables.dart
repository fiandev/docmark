import 'package:drift/drift.dart';

/// Imported documents: metadata only. The source bytes live encrypted in
/// the vault and are addressed through [DocumentAssets].
@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// `image` or `pdf`, persisted by enum name.
  TextColumn get kind => text()();

  IntColumn get pageCount => integer()();

  /// Serialized `WatermarkConfig`; null until the user first edits.
  TextColumn get configJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One page per row. A PDF page carries its own MediaBox size, so the
/// dimensions are per page rather than per document.
@DataClassName('DocumentPageRow')
class DocumentPages extends Table {
  TextColumn get docId => text()();

  IntColumn get pageIndex => integer()();

  RealColumn get widthPt => real()();

  RealColumn get heightPt => real()();

  @override
  Set<Column<Object>> get primaryKey => {docId, pageIndex};
}

/// The encrypted source blob of a document.
///
/// One document owns one source file (a whole PDF or one image); a page
/// index later selects a page inside those bytes. Keeping the reference in
/// its own table leaves the `documents` row free of storage paths.
@DataClassName('DocumentAssetRow')
class DocumentAssets extends Table {
  TextColumn get docId => text()();

  TextColumn get assetId => text()();

  /// Vault-relative path; never absolute.
  TextColumn get blobPath => text()();

  TextColumn get mime => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {docId};
}

/// Encrypted watermark images and logos known to the vault.
///
/// `dek_wrapped` mirrors the wrapped data key from the blob header. It is
/// metadata for auditing and repair; decryption reads the blob, never this
/// column.
@DataClassName('WatermarkAssetRow')
class WatermarkAssets extends Table {
  TextColumn get id => text()();

  TextColumn get blobPath => text()();

  TextColumn get dekWrapped => text()();

  TextColumn get mime => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Saved watermark configurations.
@DataClassName('PresetRow')
class Presets extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// JSON array of serialized `WatermarkElement`s.
  TextColumn get elementsJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Which vault assets a preset references. A preset may share an asset
/// with another preset, which is why deletion is reference counted.
@DataClassName('PresetAssetRow')
class PresetAssets extends Table {
  TextColumn get presetId => text()();

  TextColumn get assetId => text()();

  @override
  Set<Column<Object>> get primaryKey => {presetId, assetId};
}

/// One processing run: what came in, what went out, and how far it got.
@DataClassName('HistoryEntryRow')
class HistoryEntries extends Table {
  TextColumn get id => text()();

  TextColumn get documentName => text()();

  TextColumn get documentId => text().nullable()();

  /// Serialized `AssetRef`.
  TextColumn get originalRef => text().nullable()();

  /// Serialized `AssetRef`.
  TextColumn get processedRef => text().nullable()();

  /// Serialized `WatermarkConfig` snapshot used for the run.
  TextColumn get configRef => text().nullable()();

  TextColumn get status => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Every vault asset an owner points at, independent of preset assets.
///
/// A document references its edited watermark images here, and a history
/// entry references its two previews. Before an asset is deleted, this
/// table is what proves no other owner still needs it.
@DataClassName('AssetLinkRow')
class AssetLinks extends Table {
  TextColumn get assetId => text()();

  /// `document` or `history`.
  TextColumn get ownerType => text()();

  TextColumn get ownerId => text()();

  @override
  Set<Column<Object>> get primaryKey => {assetId, ownerType, ownerId};
}

/// Internal bookkeeping (schema markers, first-run flags).
@DataClassName('AppMetaRow')
class AppMeta extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
