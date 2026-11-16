import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cálculo de lucro', () {
    const ganhos = 35000;
    const despesas = 10000;
    expect(ganhos - despesas, 25000);
  });
}
