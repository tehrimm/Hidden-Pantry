
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:hidden_pantry_app/core/services/auth_service.dart';
import 'package:hidden_pantry_app/features/user/services/user_service.dart';
import 'package:hidden_pantry_app/features/recipes/services/recipe_api_service.dart';
import 'package:hidden_pantry_app/features/recipes/models/recipe.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A utility to mock all network image requests during tests.
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }
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

class MockRecipeApiService extends Mock implements RecipeApiService {
  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    int limit = 10,
    List<String>? ingredients,
    int? maxMinutes,
    List<String>? tags,
  }) =>
      super.noSuchMethod(
        Invocation.method(#searchRecipes, [
          query
        ], {
          #limit: limit,
          #ingredients: ingredients,
          #maxMinutes: maxMinutes,
          #tags: tags,
        }),
        returnValue: Future.value(<Recipe>[]),
      );

  @override
  Future<Recipe> getRecipeById(String id) => super.noSuchMethod(
        Invocation.method(#getRecipeById, [id]),
        returnValue: Future.value(Recipe(
          id: id,
          name: '',
          description: '',
          imageUrl: '',
          minutes: 0,
          ingredients: [],
          directions: [],
          tags: [],
          avgRating: 0.0,
          authorId: '',
          authorName: '',
        )),
      );

  @override
  Future<int> countRecipesByAuthor(String authorId) => super.noSuchMethod(
        Invocation.method(#countRecipesByAuthor, [authorId]),
        returnValue: Future.value(0),
      );

  @override
  Future<List<Recipe>> fetchRecipesByAuthor(String authorId, {int limit = 10, DocumentSnapshot? startAfter}) =>
      super.noSuchMethod(
        Invocation.method(#fetchRecipesByAuthor, [authorId], {#limit: limit, #startAfter: startAfter}),
        returnValue: Future.value(<Recipe>[]),
      );
}
