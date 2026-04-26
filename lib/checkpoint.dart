class Checkpoint {
  final int id;
  final String qrCode;
  final String title;
  final String description;
  final String category;
  final String categoryLabel;
  final String categoryColor;
  final String image;
  final String location;
  final String? locationId;

  const Checkpoint({
    required this.id,
    required this.qrCode,
    required this.title,
    required this.description,
    this.category = '',
    this.categoryLabel = 'Inne',
    this.categoryColor = '',
    this.image = '',
    this.location = '',
    this.locationId,
  });

  String get subtitle => '';
  String get time => '';
}
