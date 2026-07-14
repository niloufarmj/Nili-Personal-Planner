/// Named route constants shared across the whole app.
/// Agents 2-5 add their own routes by registering in app_router.dart.
abstract final class Routes {
  // ── Shell tabs ──────────────────────────────────────────────────
  static const String today = '/';
  static const String calendar = '/calendar';
  static const String lists = '/lists';
  static const String track = '/track';
  static const String more = '/more';

  // ── Deep-link targets ───────────────────────────────────────────
  static const String dayDetail = '/day/:date'; // date = YYYY-MM-DD
  static const String collection = '/collection/:id';
  static const String trip = '/trip/:id';
  static const String fitnessLog = '/fitness/log';
  static const String period = '/period';
  static const String badges = '/badges';
  static const String next7Days = '/next-7-days';

  // ── Helpers to build parameterised paths ────────────────────────
  static String dayDetailPath(String date) => '/day/$date';
  static String collectionPath(int id) => '/collection/$id';
  static String tripPath(int id) => '/trip/$id';
}
