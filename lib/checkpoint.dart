/// Field-game checkpoint. Mirrors the Directus `checkpoints` collection.
///
/// Scanning/matching is keyed on [qrCode] (unique, encoded into the
/// printed QR poster). The numeric [id] is kept for Hero-tag stability
/// across the details screen.
class Checkpoint {
  final int id;
  final String qrCode;
  final String title;
  final String description;
  final String category;
  final String image;
  final String location;

  /// ID of the related `locations` row, if any. Used to look up coords
  /// for the per-checkpoint mini-map without having to duplicate lat/lng
  /// onto the Checkpoint itself.
  final String? locationId;

  const Checkpoint({
    required this.id,
    required this.qrCode,
    required this.title,
    required this.description,
    this.category = 'other',
    this.image = '',
    this.location = '',
    this.locationId,
  });

  /// Screens still reference `subtitle` and `time` during the Phase 2
  /// rework. The CMS has no equivalent fields yet — keep empty getters so
  /// the existing layouts skip the rows gracefully.
  String get subtitle => '';
  String get time => '';
}
