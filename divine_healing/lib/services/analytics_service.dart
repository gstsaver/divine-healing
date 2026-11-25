/// Firebase Analytics, wired for Google Ads conversion tracking.
///
/// The ad campaign runs on installs today, which brings cheap downloads that
/// never subscribe. The fix is to report the real conversion — a subscription
/// — back to Google Analytics, link that to Google Ads, and let the campaign
/// optimise for subscribers instead. [logSubscribed] is that conversion.
///
/// Everything here is a no-op until [init] runs, and [init] runs only after
/// Firebase.initializeApp() succeeds in main(). Before the Firebase project is
/// wired (no google-services.json / GoogleService-Info.plist), the app starts
/// and behaves exactly as before — analytics simply stays off. An analytics
/// call must never throw into the app, least of all the purchase flow, so each
/// is guarded.
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  /// True once Firebase is up and events will actually be sent.
  bool get enabled => _analytics != null;

  /// Call once, after Firebase.initializeApp() has succeeded. If Firebase is
  /// not configured this is never reached (main() catches the init failure),
  /// so the rest of the class stays dormant.
  Future<void> init() async {
    final a = FirebaseAnalytics.instance;
    await a.setAnalyticsCollectionEnabled(true);
    _analytics = a;
  }

  /// The person tapped Subscribe and a plan was resolved — intent to buy.
  /// Useful as a funnel step, but not the conversion itself.
  Future<void> logBeginCheckout({
    required bool annual,
    double? value,
    String? currency,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logBeginCheckout(
        value: value,
        currency: currency,
        items: [_item(annual: annual)],
      );
    } catch (_) {
      // Analytics must never interrupt a purchase.
    }
  }

  /// The conversion. Fires only when a subscription is genuinely purchased
  /// (not restored), and carries the value and currency the store charged, so
  /// Google Ads can optimise and bid on real subscribers.
  Future<void> logSubscribed({
    required bool annual,
    required double value,
    required String productId,
    String? currency,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      await a.logPurchase(
        value: value,
        // GA4 pairs value with a currency; default to USD if the store did
        // not supply one rather than drop the conversion value.
        currency: currency == null || currency.isEmpty ? 'USD' : currency,
        items: [_item(annual: annual, id: productId)],
      );
    } catch (_) {
      // Never break the post-purchase flow.
    }
  }

  AnalyticsEventItem _item({required bool annual, String? id}) =>
      AnalyticsEventItem(
        itemId: id,
        itemName: annual ? 'Annual subscription' : 'Monthly subscription',
        itemCategory: 'subscription',
      );

  /// Screen name from a GoRouter route. Same `screen_view` event the
  /// Firebase observer would send.
  Future<void> logScreen(String name) =>
      _event('screen_view', {'screen_name': name, 'screen_class': name},
          screen: name);

  /// The paywall was shown. [source] is the trigger: locked_content,
  /// first_free_session, later_launch, home, library, and so on.
  Future<void> logPaywallView({required String source}) =>
      _event('paywall_view', {'source': source});

  Future<void> logPaywallDismiss({required String source}) =>
      _event('paywall_dismiss', {'source': source});

  Future<void> logLockedContentTap({
    String? contentId,
    String? contentType,
  }) =>
      _event('locked_content_tap', {
        if (contentId != null) 'content_id': _clip(contentId),
        if (contentType != null) 'content_type': _clip(contentType),
      });

  Future<void> logAudioPlay({
    required String contentId,
    required String title,
    required bool isPreview,
  }) =>
      _event('audio_play', {
        'content_id': _clip(contentId),
        'title': _clip(title),
        'is_preview': isPreview ? 1 : 0,
      });

  Future<void> logSessionComplete({
    required String contentId,
    required String title,
    required bool isPreview,
  }) =>
      _event('session_complete', {
        'content_id': _clip(contentId),
        'title': _clip(title),
        'is_preview': isPreview ? 1 : 0,
      });

  /// [method] is google, apple, email, or password.
  Future<void> logSignInStart({required String method}) =>
      _event('sign_in_start', {'method': method});

  /// The store sheet is about to open. [logBeginCheckout] still fires as
  /// well; this is the explicit funnel step beside it.
  Future<void> logPurchaseStart({
    required bool annual,
    required String productId,
    required bool hasTrial,
  }) =>
      _event('purchase_start', {
        'plan': annual ? 'annual' : 'monthly',
        'product_id': _clip(productId),
        'has_trial': hasTrial ? 1 : 0,
      });

  /// The plan being purchased includes a free trial, so the sheet is a
  /// trial start rather than an immediate charge.
  Future<void> logTrialStart({
    required bool annual,
    required String productId,
  }) =>
      _event('trial_start', {
        'plan': annual ? 'annual' : 'monthly',
        'product_id': _clip(productId),
      });

  Future<void> logPurchaseCancelled({required String productId}) =>
      _event('purchase_cancelled', {'product_id': _clip(productId)});

  Future<void> logPurchaseFailed({
    required String errorCode,
    String? productId,
  }) =>
      _event('purchase_failed', {
        'error_code': _clip(errorCode),
        if (productId != null) 'product_id': _clip(productId),
      });

  Future<void> _event(
    String name,
    Map<String, Object> parameters, {
    String? screen,
  }) async {
    final a = _analytics;
    if (a == null) return;
    try {
      if (screen != null) {
        await a.logScreenView(screenName: screen, screenClass: screen);
        return;
      }
      await a.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  static String _clip(String value) =>
      value.length <= 100 ? value : value.substring(0, 100);
}
