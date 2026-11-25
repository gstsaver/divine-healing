import 'package:divine_healing/services/auth_return.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only in-app paths are safe to return to', () {
    expect(AuthReturn.sanitize('/content/12'), '/content/12');
    expect(AuthReturn.sanitize('/library/meditation'), '/library/meditation');
    expect(AuthReturn.sanitize('/shadow-work/4'), '/shadow-work/4');
    expect(AuthReturn.sanitize('/'), '/');
  });

  test('auth callbacks and off-app urls are refused', () {
    expect(AuthReturn.sanitize('/sign-in'), isNull);
    expect(AuthReturn.sanitize('/splash'), isNull);
    expect(AuthReturn.sanitize('/login-callback'), isNull);
    expect(AuthReturn.sanitize('https://example.com'), isNull);
    expect(AuthReturn.sanitize('//evil.example'), isNull);
    expect(AuthReturn.sanitize('/home?code=abc'), isNull);
    expect(AuthReturn.sanitize('/sign-in?error=access_denied'), isNull);
    expect(AuthReturn.sanitize(''), isNull);
    expect(AuthReturn.sanitize(null), isNull);
  });
}
