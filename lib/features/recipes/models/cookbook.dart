class Cookbook {
  final String id;
  final String title;
  final String description;
  final List<String> recipeIds;
  final String? imageUrl;
  final DateTime createdAt;

  Cookbook({
    required this.id,
    required this.title,
    this.description = "",
    this.recipeIds = const [],
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Cookbook.fromJson(Map<String, dynamic> json, String docId) {
    return Cookbook(
      id: docId,
      title: json['title'] ?? 'My Cookbook',
      description: json['description'] ?? '',
      recipeIds: (json['recipeIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as dynamic).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'recipeIds': recipeIds,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }

  Cookbook copyWith({
    String? title,
    String? description,
    List<String>? recipeIds,
    String? imageUrl,
  }) {
    return Cookbook(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      recipeIds: recipeIds ?? this.recipeIds,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
    );
  }
}



