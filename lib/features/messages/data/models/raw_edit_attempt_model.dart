class RawEditAttemptModel {
  final String messageId;
  final String attemptType;

  RawEditAttemptModel({required this.messageId, required this.attemptType});

  factory RawEditAttemptModel.fromFirestore(Map<String, dynamic> data) {
    return RawEditAttemptModel(
      messageId: data['messageId'] as String,
      attemptType: data['attemptType'] as String? ?? 'EDIT',
    );
  }
}
