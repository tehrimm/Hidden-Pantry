
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hidden_pantry_app/features/nutritionist/services/nutritionist_service.dart';

Future<File> createDummyImage() async {
  final directory = Directory.systemTemp;
  final file = File('${directory.path}/dummy.png');
  await file.writeAsBytes(_transparentImage);
  return file;
}

/// A utility to mock all network image requests during tests.
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  HttpHeaders get headers => _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpHeaders extends Mock implements HttpHeaders {}

class _MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final Uint8List _transparentImage = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x44, 0x4E, 0xAE, 0x42,
  0x60, 0x82,
]);

void setUpNetworkImageMock() {
  HttpOverrides.global = MockHttpOverrides();
}

/// A fake user for authentication tests that avoids Mockito null safety issues.
class FakeUser extends Mock implements User {
  @override
  String get uid => 'test-uid';

  @override
  String? get email => 'test@gmail.com';

  @override
  String? get displayName => 'Test User';

  @override
  List<UserInfo> get providerData => [];
}

/// A fake user credential for authentication tests.
class FakeUserCredential extends Mock implements UserCredential {
  @override
  User? get user => FakeUser();
}

// --- Manual Mocks with safe overrides for null safety ---

class MockAuthService extends Mock implements AuthService {
  @override
  Future<UserCredential> registerWithEmail(String email, String password) =>
      super.noSuchMethod(
        Invocation.method(#registerWithEmail, [email, password]),
        returnValue: Future.value(FakeUserCredential()),
      );

  @override
  Future<void> signOut() => super.noSuchMethod(
        Invocation.method(#signOut, []),
        returnValue: Future.value(),
      );
}

class MockUserService extends Mock implements UserService {
  @override
  Future<void> upsertCurrentUserProfile({
    required String fullName,
    required String phoneNumber,
    List<String> allergies = const [],
    String? bio,
    String? photoUrl,
    bool notificationsEnabled = true,
  }) =>
      super.noSuchMethod(
        Invocation.method(#upsertCurrentUserProfile, [], {
          #fullName: fullName,
          #phoneNumber: phoneNumber,
          #allergies: allergies,
          #bio: bio,
          #photoUrl: photoUrl,
          #notificationsEnabled: notificationsEnabled,
        }),
        returnValue: Future.value(),
      );

  @override
  Future<void> updateAllergies(List<String> allergies) => super.noSuchMethod(
        Invocation.method(#updateAllergies, [allergies]),
        returnValue: Future.value(),
      );
}

class MockRecipeApiService implements RecipeApiService {
  @override
  String get baseUrl => "mock_url";

  @override
  Future<List<String>> fetchTags({int limit = 15}) async => ["All", "Sushi", "Seafood", "Dessert"];

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 10,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
    List<String>? allergies,
  }) async => [];

  @override
  Future<Recipe> getRecipeById(String id) async => Recipe(
          id: id,
          name: 'Mock Recipe',
          description: 'Description',
          imageUrl: '',
          minutes: 30,
          ingredients: [],
          directions: [],
          tags: [],
          avgRating: 4.5,
          authorId: 'a1',
          authorName: 'Author',
        );

  @override
  Future<int> countRecipesByAuthor(String authorId) async => 0;

  @override
  Future<List<Recipe>> fetchRecipesByAuthor(String authorId, {int limit = 10}) async => [];

  @override
  Future<List<Recipe>> recommend({
    String? query,
    List<String> ingredients = const [],
    String? tag,
    List<String> allergies = const [],
    List<String> likedRecipeIds = const [],
    int? maxMinutes,
    double? minRating,
    int topK = 10,
  }) async => [];

  @override
  Future<List<Recipe>> fetchFollowingFeed(List<String> authorIds, {int limit = 20}) async => [];

  @override
  Future<Map<String, dynamic>> getAuthorStats(String authorId) async => {};
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRecipeService extends Mock implements RecipeService {
  @override
  Stream<QuerySnapshot> getReviews(String recipeId) => Stream.value(_MockQuerySnapshot([]));
  
  @override
  Future<List<Recipe>> getRecipesByIds(List<String> ids) async => [];

  @override
  Future<bool> hasUserReviewed(String recipeId, String userId) async => false;
}

class MockNutritionistService extends Mock implements NutritionistService {
  @override
  Stream<List<Map<String, dynamic>>> getPendingNutritionists() => Stream.value([
    {
      'uid': 'n1',
      'fullName': 'Expert Jiro',
      'email': 'jiro@example.com',
      'licenseNumber': 'L12345',
      'certificateUrl': 'https://example.com/cert.pdf',
    }
  ]);

  @override
  Future<void> approveNutritionist(String uid) async {}
  @override
  Future<void> rejectNutritionist(String uid, String reason) async {}
}

class _MockQuerySnapshot extends Mock implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;
  _MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;
}

class _MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;
  _MockQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic operator [](Object field) => _data[field];
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _MockCollectionReference(collectionPath);
  }
}

class _MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {
  final String path;
  _MockCollectionReference(this.path);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _MockDocumentReference(path ?? 'default');
  }
}

class _MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {
  final String id;
  _MockDocumentReference(this.id);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return _MockDocumentSnapshot(id, {
      'fullName': 'Test User',
      'email': 'test@gmail.com',
    });
  }
}

class _MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;
  _MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  bool get exists => _data != null;
  @override
  dynamic operator [](Object field) => _data?[field];
}
