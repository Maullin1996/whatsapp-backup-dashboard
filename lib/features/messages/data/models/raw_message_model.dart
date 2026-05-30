class RawMessageModel {
  final String id;
  final String chatJid;
  final String senderName;
  final String? caption;
  final String localTime;
  final bool hasMedia;
  final String? storagePath;
  final int messageTimestamp;
  final bool isEdited;
  final int? shiftImageIndex;

  RawMessageModel({
    required this.id,
    required this.senderName,
    this.caption,
    this.storagePath,
    required this.hasMedia,
    required this.messageTimestamp,
    required this.chatJid,
    required this.localTime,
    this.isEdited = false,
    this.shiftImageIndex,
  });

  factory RawMessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RawMessageModel(
      id: id,
      senderName: data['senderName'] as String,
      hasMedia: data['hasMedia'] as bool? ?? false,
      messageTimestamp: data['messageTimestamp'] as int,
      chatJid: data['chatJid'] as String,
      caption: data['caption'] as String?,
      storagePath: data['storagePath'] as String?,
      localTime: data['localTime'] as String,
      isEdited: false,
      shiftImageIndex: data['shiftImageIndex'] as int?,
    );
  }
}
