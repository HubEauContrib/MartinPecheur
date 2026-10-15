import 'package:flutter_test/flutter_test.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_map.dart';
import 'package:martinpecheur/domain/floods/flood_vigilance_source.dart';

class _Failing implements FloodVigilanceSource {
  @override
  Future<FloodVigilanceMap> current() async =>
      throw const VigilanceInjoignable('réseau');
}

String _label(FloodVigilanceFailure f) => switch (f) {
  VigilanceInjoignable() => 'injoignable',
  VigilanceRefusee(:final statusCode) => 'refusee $statusCode',
  VigilanceIllisible() => 'illisible',
};

void main() {
  test('égalité structurelle par branche', () {
    expect(const VigilanceInjoignable('a'), const VigilanceInjoignable('a'));
    expect(
      const VigilanceInjoignable('a'),
      isNot(const VigilanceInjoignable('b')),
    );
    expect(
      const VigilanceRefusee(statusCode: 404, diagnostic: 'x'),
      const VigilanceRefusee(statusCode: 404, diagnostic: 'x'),
    );
    expect(
      const VigilanceRefusee(statusCode: 404, diagnostic: 'x'),
      isNot(const VigilanceRefusee(statusCode: 500, diagnostic: 'x')),
    );
    expect(const VigilanceIllisible('a'), const VigilanceIllisible('a'));
    expect(
      const VigilanceIllisible('a'),
      isNot(const VigilanceInjoignable('a')),
    );
    expect(
      const VigilanceIllisible('a').hashCode,
      const VigilanceIllisible('a').hashCode,
    );
  });

  test('switch exhaustif sans default', () {
    expect(_label(const VigilanceInjoignable('a')), 'injoignable');
    expect(
      _label(const VigilanceRefusee(statusCode: 409, diagnostic: 'd')),
      'refusee 409',
    );
    expect(_label(const VigilanceIllisible('a')), 'illisible');
  });

  test('le port lève son échec', () {
    expect(_Failing().current(), throwsA(const VigilanceInjoignable('réseau')));
  });
}
