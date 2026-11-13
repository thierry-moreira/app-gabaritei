import 'package:gabaritei_app/core/data/global_write_gateway.dart';
import 'package:gabaritei_app/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException;
import 'package:test/test.dart';

void main() {
  group('globalWriteFailure', () {
    test('maps an expired JWT to an authentication error', () {
      final error = globalWriteFailure(FunctionException(status: 401));

      expect(error, isA<AuthException>());
      expect(error.isUnauthorized, isTrue);
    });

    test('includes the server retry delay for rate limits', () {
      final error = globalWriteFailure(
        FunctionException(
          status: 429,
          details: {'retry_after_seconds': 37},
        ),
      );

      expect(error.code, '429');
      expect(error.message, contains('37 segundos'));
    });

    test('does not expose internal server details to the UI', () {
      final error = globalWriteFailure(
        FunctionException(
          status: 500,
          details: {'message': 'private database detail'},
        ),
      );

      expect(error, isA<AppException>());
      expect(error.message, isNot(contains('private database detail')));
    });
  });
}
