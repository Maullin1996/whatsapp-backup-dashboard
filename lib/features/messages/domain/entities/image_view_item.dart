class ImageViewItem {
  final String storagePath;
  final String senderName;
  final int messageTimestamp;
  final String localTime;
  final String shift;
  final bool isEdited;
  final int? shiftImageIndex;

  ImageViewItem({
    required this.storagePath,
    required this.senderName,
    required this.messageTimestamp,
    required this.localTime,
    required this.shift,
    this.isEdited = false,
    this.shiftImageIndex,
  });
}
