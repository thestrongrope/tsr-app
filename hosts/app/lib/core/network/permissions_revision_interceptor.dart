import 'package:dio/dio.dart';

/// Reports the `X-Permissions-Revision` header that the server puts on every
/// authenticated response, so the app learns that what a member may do has
/// changed without waiting for a timer.
///
/// The permissions call itself is skipped: its own answer is what a refresh
/// stores, and reading it here would refresh from inside a refresh.
class PermissionsRevisionInterceptor extends Interceptor {
  PermissionsRevisionInterceptor(this._onRevision);

  final void Function(String revision) _onRevision;

  static const header = 'x-permissions-revision';
  static const _permissionsPath = '/me/permissions';

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _report(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _report(err.response);
    handler.next(err);
  }

  void _report(Response? response) {
    if (response == null) return;
    if (response.requestOptions.path.endsWith(_permissionsPath)) return;
    final revision = response.headers.value(header);
    if (revision == null || revision.isEmpty) return;
    _onRevision(revision);
  }
}
