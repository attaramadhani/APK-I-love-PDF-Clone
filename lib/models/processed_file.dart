class ProcessedFile {
  final String id;
  final String name;
  final String path;
  final int sizeInBytes;
  final DateTime createdAt;
  final String toolUsed;

  ProcessedFile({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeInBytes,
    required this.createdAt,
    required this.toolUsed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'sizeInBytes': sizeInBytes,
        'createdAt': createdAt.toIso8601String(),
        'toolUsed': toolUsed,
      };

  factory ProcessedFile.fromJson(Map<String, dynamic> json) => ProcessedFile(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        sizeInBytes: json['sizeInBytes'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        toolUsed: json['toolUsed'] as String,
      );
}
