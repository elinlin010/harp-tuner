import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What prompted the user to send feedback. Lets us segment, in Firestore,
/// spontaneous feedback from feedback captured at a churn moment.
enum FeedbackTrigger {
  /// Tapped the "Send feedback" row in the settings sheet.
  settings,

  /// Tapped the always-visible feedback button in the main screen's nav bar.
  mainScreen,

  /// Sent via the nudge shown when a tuning session ended without ever
  /// locking onto a note — the exact moment users give up and uninstall.
  failedSession,
}

extension on FeedbackTrigger {
  String get wireName => switch (this) {
        FeedbackTrigger.settings => 'settings',
        FeedbackTrigger.mainScreen => 'main_screen',
        FeedbackTrigger.failedSession => 'failed_session',
      };
}

/// Optional 4-level satisfaction rating attached to a feedback submission.
/// [score] is stored in Firestore (1 = worst … 4 = best) so ratings aggregate
/// numerically; order the UI best-first to match the score.
enum FeedbackRating {
  loveIt(4),
  fine(3),
  needsWork(2),
  frustrating(1);

  const FeedbackRating(this.score);

  /// 1–4, higher is more satisfied.
  final int score;
}

/// Collects anonymous in-app feedback and writes it to Firestore.
///
/// Designed to degrade gracefully: if no Firebase project is wired up yet
/// (i.e. `flutterfire configure` has not been run, so there is no
/// GoogleService-Info.plist / google-services.json), [tryInitialize] swallows
/// the error and the service reports [isAvailable] == false. Callers should
/// hide the feedback UI when the service is unavailable.
///
/// Collected fields are deliberately non-PII: a free-text message the user
/// typed, plus app/device context (version, platform, device model, locale)
/// used to cluster churn signals by device. See PrivacyInfo.xcprivacy and the
/// Play Console data-safety form for disclosures.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const _collection = 'feedback';
  static const _maxMessageLength = 2000;

  bool _initialized = false;
  bool _available = false;

  /// Whether feedback can currently be submitted. False until a Firebase
  /// project is configured and [tryInitialize] succeeds.
  bool get isAvailable => _available;

  /// Attempts to initialize Firebase. Safe to call once at startup; never
  /// throws. On platforms/builds without Firebase config it leaves the
  /// service disabled.
  Future<void> tryInitialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Reads native config (GoogleService-Info.plist / google-services.json).
      // Throws if no project is configured — handled below.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _available = true;
    } catch (e) {
      _available = false;
      if (kDebugMode) {
        debugPrint('FeedbackService: Firebase unavailable, feedback '
            'disabled. Run `flutterfire configure`. ($e)');
      }
    }
  }

  /// Submits a feedback [message]. Throws [StateError] if the service is
  /// unavailable, or rethrows Firestore errors so the UI can surface a retry.
  Future<void> submit({
    required String message,
    required FeedbackTrigger trigger,
    required String locale,
    FeedbackRating? rating,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Feedback message must not be empty.');
    }
    if (!_available) {
      throw StateError('Feedback service is not available.');
    }

    final meta = await _deviceMeta();
    // Firestore's add() future only completes on server ACK. With offline
    // persistence the write is cached locally and the SDK retries an
    // unreachable backend forever, so the future can hang indefinitely (e.g.
    // no network, or the backend genuinely unreachable). Bound the wait so the
    // UI can surface a retry instead of spinning forever.
    await FirebaseFirestore.instance.collection(_collection).add({
      'message': trimmed.length > _maxMessageLength
          ? trimmed.substring(0, _maxMessageLength)
          : trimmed,
      'trigger': trigger.wireName,
      'locale': locale,
      if (rating != null) 'rating': rating.score,
      'appVersion': meta.appVersion,
      'platform': meta.platform,
      'osVersion': meta.osVersion,
      'deviceModel': meta.deviceModel,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }

  Future<_DeviceMeta> _deviceMeta() async {
    String appVersion = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {/* leave default */}

    final plugin = DeviceInfoPlugin();
    String platform = 'unknown';
    String osVersion = 'unknown';
    String deviceModel = 'unknown';
    try {
      if (Platform.isIOS) {
        final ios = await plugin.iosInfo;
        platform = 'ios';
        osVersion = ios.systemVersion;
        deviceModel = ios.utsname.machine; // e.g. iPhone14,2
      } else if (Platform.isAndroid) {
        final android = await plugin.androidInfo;
        platform = 'android';
        osVersion = 'SDK ${android.version.sdkInt}';
        deviceModel = '${android.manufacturer} ${android.model}';
      } else {
        platform = Platform.operatingSystem;
      }
    } catch (_) {/* leave defaults */}

    return _DeviceMeta(
      appVersion: appVersion,
      platform: platform,
      osVersion: osVersion,
      deviceModel: deviceModel,
    );
  }
}

class _DeviceMeta {
  const _DeviceMeta({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
  });

  final String appVersion;
  final String platform;
  final String osVersion;
  final String deviceModel;
}
