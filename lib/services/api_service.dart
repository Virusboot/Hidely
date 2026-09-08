import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'image_compression_service.dart';
import 'package:hidely_new/services/auth_service.dart';

import '../config/config.dart';

class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final String? error;

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });
}

class ApiService {
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final http.Client _client = http.Client();
  http.Client get client => _client;

  static String get defaultBaseUrl => AppEnv.apiBaseUrl;

  static String _resolvedBaseUrl = AppEnv.apiBaseUrl;

  String get baseUrl => _resolvedBaseUrl;

  Future<void> init() async {
    await autoDiscoverBaseUrl();
  }

  Future<void> autoDiscoverBaseUrl() async {
    // 1. Try to connect to local server first (Emulator / Simulator)
    final localUrls = AppEnv.localDiscoveryUrls;

    for (final url in localUrls) {
      try {
        // Check a lightweight endpoint to see if local server is alive
        final response = await _client.get(Uri.parse('$url/api/users/leaderboard')).timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          _resolvedBaseUrl = url;
          debugPrint('[ApiService] Using local server: $_resolvedBaseUrl');
          return;
        }
      } catch (_) {
        // Ignore and try next
      }
    }

    // 2. Point directly to the online server if local is not available
    _resolvedBaseUrl = 'https://hidely-backend.onrender.com';
    debugPrint('[ApiService] Using online server: $_resolvedBaseUrl');

    // Wake up the online Render server in the background (fire and forget)
    try {
      final uri = Uri.parse(_resolvedBaseUrl);
      _client.get(uri).timeout(const Duration(seconds: 90)).catchError((e) {
        return http.Response('error', 500);
      });
    } catch (_) {
      // Ignore background errors
    }
  }


  /// Register user
  Future<ApiResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? gender,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'username': username,
          'email': email,
          'password': password,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
        }),
      ).timeout(const Duration(seconds: 90));

      final body = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Registration successful!',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Registration failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      debugPrint('ApiService register error: $e');
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Verify OTP code
  Future<ApiResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 90));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'OTP verified.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Verification failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      debugPrint('ApiService verifyOtp error: $e');
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Login user
  Future<ApiResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 90));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Logged in successfully.',
          data: body,
        );
      } else if (response.statusCode == 403 && body['requiresVerification'] == true) {
        // Special case: account exists but not verified
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Please verify your account.',
          data: body,
          error: 'UNVERIFIED',
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Login failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      debugPrint('ApiService login error: $e');
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Request Forgot Password OTP
  Future<ApiResult> forgotPassword({required String email}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 90));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'OTP generated.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Request failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      debugPrint('ApiService forgotPassword error: $e');
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Reset password using OTP
  Future<ApiResult> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 90));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Password reset success.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Reset failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Change password (authenticated session)
  Future<ApiResult> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Password changed successfully.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Password change failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Get user profile stats and info
  Future<ApiResult> getUserProfile({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'Profile loaded.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Profile fetch failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Update user profile details (multipart)
  Future<ApiResult> updateUserProfile({
    required String token,
    String? name,
    String? username,
    String? pronouns,
    String? gender,
    String? bio,
    Uint8List? avatarBytes,
    File? avatar,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/profile');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token';

      if (name != null) request.fields['name'] = name;
      if (username != null) request.fields['username'] = username;
      if (pronouns != null) request.fields['pronouns'] = pronouns;
      if (gender != null) request.fields['gender'] = gender;
      if (bio != null) request.fields['bio'] = bio;

      if (avatarBytes != null && avatarBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            avatarBytes,
            filename: 'avatar.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else if (avatar != null && !kIsWeb) {
        final compressedAvatar = await ImageCompressionService.compressImage(
          avatar,
          quality: 85,
          maxDimension: 800,
        );
        final ext = compressedAvatar.path.split('.').last.toLowerCase();
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            compressedAvatar.path,
            contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
          ),
        );
      }

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Profile updated.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Profile update failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      debugPrint("Update Profile Error: $e");
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Fetch global posts feed
  Future<ApiResult> getFeedPosts({String? token}) async {
    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/api/posts/feed'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'Feed loaded.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Feed fetch failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Toggle post like status
  Future<ApiResult> toggleLikePost({required String token, required int postId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/posts/$postId/like'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Like toggled.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Like action failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  Future<ApiResult> createPost({
    required String token,
    required String caption,
    required String location,
    required String category,
    File? image,
    List<File>? images,
    Uint8List? imageBytes,
    String? filename,
    double? latitude,
    double? longitude,
    double? locationAccuracyMeters,
    String? locationSource,
    String? locationCapturedAt,
    String? canonicalName,
    String? normalizedName,
    String? landmarkType,
    String? city,
    String? state,
    String? country,
    double? aiConfidence,
    String? duplicateClusterId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/posts');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['caption'] = caption
        ..fields['location'] = location
        ..fields['category'] = category;

      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      if (locationAccuracyMeters != null) request.fields['location_accuracy_meters'] = locationAccuracyMeters.toString();
      if (locationSource != null) request.fields['location_source'] = locationSource;
      if (locationCapturedAt != null) request.fields['location_captured_at'] = locationCapturedAt;
      if (canonicalName != null) request.fields['canonical_name'] = canonicalName;
      if (normalizedName != null) request.fields['normalized_name'] = normalizedName;
      if (landmarkType != null) request.fields['landmark_type'] = landmarkType;
      if (city != null) request.fields['city'] = city;
      if (state != null) request.fields['state'] = state;
      if (country != null) request.fields['country'] = country;
      if (aiConfidence != null) request.fields['ai_confidence'] = aiConfidence.toString();
      if (duplicateClusterId != null) request.fields['duplicate_cluster_id'] = duplicateClusterId;

      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final imgFile = images[i];
          final ext = imgFile.path.split('.').last.toLowerCase();
          final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'mpeg'].contains(ext);
          
          File finalFile = imgFile;
          if (!isVideo && !kIsWeb) {
            finalFile = await ImageCompressionService.compressImage(
              imgFile,
              quality: 80,
              maxDimension: 1920,
            );
          }
          
          final fileExt = finalFile.path.split('.').last.toLowerCase();
          final mediaType = isVideo ? 'video' : 'image';
          final subType = isVideo ? fileExt : (fileExt == 'jpg' ? 'jpeg' : fileExt);

          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              finalFile.path,
              contentType: MediaType(mediaType, subType),
            ),
          );

          if (i == 0) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'image',
                finalFile.path,
                contentType: MediaType(mediaType, subType),
              ),
            );
          }
        }
      } else if (kIsWeb || imageBytes != null) {
        final bytes = imageBytes ?? (image != null ? await image.readAsBytes() : Uint8List(0));
        final name = filename ?? (image != null && image.path.isNotEmpty ? image.path.split('/').last : 'upload.jpg');
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'mpeg'].contains(ext);
        final mediaType = isVideo ? 'video' : 'image';
        final subType = isVideo ? ext : (ext == 'jpg' ? 'jpeg' : ext);

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: name,
            contentType: MediaType(mediaType, subType),
          ),
        );
      } else if (image != null) {
        final ext = image.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'mpeg'].contains(ext);
        
        File finalFile = image;
        if (!isVideo) {
          finalFile = await ImageCompressionService.compressImage(
            image,
            quality: 80,
            maxDimension: 1920,
          );
        }
        
        final fileExt = finalFile.path.split('.').last.toLowerCase();
        final mediaType = isVideo ? 'video' : 'image';
        final subType = isVideo ? fileExt : (fileExt == 'jpg' ? 'jpeg' : fileExt);

        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            finalFile.path,
            contentType: MediaType(mediaType, subType),
          ),
        );
      }

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      final body = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Post created.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Post creation failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Get posts of a specific user
  Future<ApiResult> getUserPosts({required String userId, String? token}) async {
    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _client.get(
        Uri.parse('$baseUrl/api/posts/user/$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'User posts loaded.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'User posts fetch failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Toggle bookmark on a post
  Future<ApiResult> toggleBookmarkPost({required String token, required int postId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/posts/$postId/bookmark'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: body['message'] ?? 'Bookmark toggled.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Bookmark action failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Get bookmarked posts of logged-in user
  Future<ApiResult> getSavedPosts({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/posts/saved'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'Saved posts loaded.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Saved posts fetch failed.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Get comments for a post
  Future<ApiResult> getComments({required int postId}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/posts/$postId/comments'),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Comments loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load comments.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Add a comment to a post
  Future<ApiResult> addComment({required String token, required int postId, required String text}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/posts/$postId/comment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResult(success: true, message: 'Comment posted.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to post comment.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Toggle comment like status
  Future<ApiResult> toggleLikeComment({required String token, required int commentId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/posts/comment/$commentId/like'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Comment liked/unliked.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to toggle comment like.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Delete a comment
  Future<ApiResult> deleteComment({required String token, required int commentId}) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/posts/comment/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Comment deleted.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to delete comment.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get specific creator details by username
  Future<ApiResult> getCreatorProfile({required String username, String? token}) async {
    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/profile/$username'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Creator profile loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load creator profile.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Toggle follow creator status
  Future<ApiResult> toggleFollowCreator({required String token, required String creatorId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/users/follow/$creatorId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Follow state toggled.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to toggle follow.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get followed creators list
  Future<ApiResult> getFollowing({required String token, String? username}) async {
    try {
      final url = (username != null && username.isNotEmpty)
          ? '$baseUrl/api/users/following/$username'
          : '$baseUrl/api/users/following';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Following list loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load following list.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get followers list
  Future<ApiResult> getFollowers({required String token, String? username}) async {
    try {
      final url = (username != null && username.isNotEmpty)
          ? '$baseUrl/api/users/followers/$username'
          : '$baseUrl/api/users/followers';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Followers list loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load followers list.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Fetch notifications for current user (paginated)
  Future<ApiResult> getNotifications({required String token, int page = 1, int limit = 30}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/notifications?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Notifications loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load notifications.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Mark single notification as read
  Future<ApiResult> markSingleNotificationAsRead({required String token, required int notificationId}) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Notification marked as read.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to mark notification read.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Mark all notifications as read
  Future<ApiResult> markNotificationsAsRead({required String token}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/notifications/read'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Notifications marked as read.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to mark read.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get unread notification count
  Future<ApiResult> getUnreadNotificationCount({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/notifications/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Unread count loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load unread count.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get a single post by ID
  Future<ApiResult> getPostById({required int postId, String? token}) async {
    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _client.get(
        Uri.parse('$baseUrl/api/posts/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Post loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load post.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Delete a post by ID
  Future<ApiResult> deletePost({required int postId, required String token}) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/posts/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResult(success: true, message: body['message'] ?? 'Post deleted.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to delete post.', error: body['error']);
      }
    } catch (e) {
      // Network error / timeout — treat as silent (don't revert local UI)
      return ApiResult(success: false, message: 'network_error', error: e.toString());
    }
  }

  /// Get explore/categories posts with filters
  Future<ApiResult> getExplorePosts({
    String? category,
    String? city,
    String? search,
    String? sortBy,
    String? token,
  }) async {
    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (city != null) queryParams['city'] = city;
      if (search != null) queryParams['search'] = search;
      if (sortBy != null) queryParams['sortBy'] = sortBy;

      final uri = Uri.parse('$baseUrl/api/posts/explore').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Explore posts loaded.', data: body);
      } else {
        return ApiResult(success: false, message: body['error'] ?? 'Failed to load explore posts.', error: body['error']);
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get leaderboard rankings (period: weekly, monthly, all_time)
  Future<ApiResult> getLeaderboard({String period = 'all_time'}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/gamification/leaderboard?period=$period'),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'Leaderboard loaded successfully.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Failed to load leaderboard.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Get authenticated user's points, level, rank, badges, and progress
  Future<ApiResult> getUserGamificationProfile() async {
    try {
      final token = AuthService().token;
      if (token == null) return ApiResult(success: false, message: 'Not authenticated.');

      final response = await _client.get(
        Uri.parse('$baseUrl/api/gamification/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Gamification profile loaded.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Error loading profile.');
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get user points transaction history
  Future<ApiResult> getPointHistory({int page = 1, int limit = 30}) async {
    try {
      final token = AuthService().token;
      if (token == null) return ApiResult(success: false, message: 'Not authenticated.');

      final response = await _client.get(
        Uri.parse('$baseUrl/api/gamification/points/history?page=$page&limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Point history loaded.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Error loading point history.');
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Get all available badges with user earned status
  Future<ApiResult> getBadges() async {
    try {
      final token = AuthService().token;
      final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};

      final response = await _client.get(
        Uri.parse('$baseUrl/api/gamification/badges'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Badges loaded.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Error loading badges.');
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Set primary featured badge
  Future<ApiResult> setFeaturedBadge(int? badgeId) async {
    try {
      final token = AuthService().token;
      if (token == null) return ApiResult(success: false, message: 'Not authenticated.');

      final response = await _client.post(
        Uri.parse('$baseUrl/api/gamification/badges/featured'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'badgeId': badgeId}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(success: true, message: body['message'] ?? 'Featured badge updated.');
      }
      return ApiResult(success: false, message: body['error'] ?? 'Error updating featured badge.');
    } catch (e) {
      return ApiResult(success: false, message: 'Could not connect to server.', error: e.toString());
    }
  }

  /// Search users by username or name
  Future<ApiResult> searchUsers({required String query}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/search').replace(queryParameters: {'q': query});
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResult(
          success: true,
          message: 'Users fetched successfully.',
          data: body,
        );
      } else {
        return ApiResult(
          success: false,
          message: body['error'] ?? 'Failed to search users.',
          error: body['error'],
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Could not connect to server.',
        error: e.toString(),
      );
    }
  }

  /// Get Direct Messaging Inbox Conversations
  Future<ApiResult> getChatConversations({required String token, bool archived = false}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/conversations?archived=$archived');
      final response = await _client.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Conversations loaded.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Failed to load conversations.');
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error.', error: e.toString());
    }
  }

  /// Get or Create Direct Chat with target user
  Future<ApiResult> getOrCreateDirectChat({required String token, required int targetUserId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/direct');
      final response = await _client.post(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'targetUserId': targetUserId}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Direct conversation ready.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Failed to start direct conversation.');
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error.', error: e.toString());
    }
  }

  /// Get Conversation Messages
  Future<ApiResult> getChatMessages({required String token, required int conversationId, int limit = 50}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/conversations/$conversationId/messages?limit=$limit');
      final response = await _client.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, message: 'Messages loaded.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Failed to load messages.');
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error.', error: e.toString());
    }
  }

  /// Send Direct Message (Text, Media File, Shared Post/Place/Location)
  Future<ApiResult> sendChatMessage({
    required String token,
    required int conversationId,
    String type = 'text',
    String text = '',
    int? replyToMessageId,
    String? sharedEntityType,
    String? sharedEntityId,
    File? mediaFile,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/conversations/$conversationId/messages');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['type'] = type
        ..fields['text'] = text;

      if (replyToMessageId != null) request.fields['reply_to_message_id'] = replyToMessageId.toString();
      if (sharedEntityType != null) request.fields['shared_entity_type'] = sharedEntityType;
      if (sharedEntityId != null) request.fields['shared_entity_id'] = sharedEntityId;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();

      if (mediaFile != null && !kIsWeb) {
        request.files.add(await http.MultipartFile.fromPath('media', mediaFile.path));
      }

      final streamedRes = await _client.send(request).timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedRes);
      final body = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResult(success: true, message: 'Message sent.', data: body);
      }
      return ApiResult(success: false, message: body['error'] ?? 'Failed to send message.');
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error.', error: e.toString());
    }
  }

  /// Toggle Message Emoji Reaction
  Future<ApiResult> toggleChatMessageReaction({required String token, required int messageId, required String emoji}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/messages/$messageId/reactions');
      final response = await _client.post(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'emoji': emoji}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      return ApiResult(success: response.statusCode == 200, message: body['error'] ?? 'Reaction updated.');
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error.', error: e.toString());
    }
  }

  /// Mark Conversation as Read
  Future<ApiResult> markChatConversationAsRead({required String token, required int conversationId}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat/conversations/$conversationId/read');
      final response = await _client.patch(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      return ApiResult(success: response.statusCode == 200, message: 'Conversation read.', data: body);
    } catch (e) {
      return ApiResult(success: false, message: 'Connection error.', error: e.toString());
    }
  }
}
