import 'package:flutter_test/flutter_test.dart';
import 'package:rega_admin/rega_i18n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => RegaI18n.setLang('ku'));

  test('exact Kurdish phrase -> English / Arabic', () {
    RegaI18n.setLang('en');
    expect(tx('ڕێکخستنەکان'), 'Settings');
    RegaI18n.setLang('ar');
    expect(tx('ڕێکخستنەکان'), 'الإعدادات');
    RegaI18n.setLang('ku');
    expect(tx('ڕێکخستنەکان'), 'ڕێکخستنەکان');
  });

  test('template with placeholders', () {
    RegaI18n.setLang('en');
    expect(tx('داواکاری #42'), 'Order #42');
  });

  test('interpolated phrase is covered word by word', () {
    RegaI18n.setLang('en');
    final out = tx('٥ خولەک');
    expect(RegExp(r'[؀-ۿ]').hasMatch(out), isFalse, reason: out);
  });

  test('unknown text (names) stays unchanged, digits become western', () {
    RegaI18n.setLang('en');
    expect(tx('ناوێکی نەناسراو زۆر تایبەت'), 'ناوێکی نەناسراو زۆر تایبەت');
    expect(tx('١٢٣'), '123');
  });

  test('names learned from API data', () {
    RegaI18n.learn({
      'data': [
        {'name_ku': 'چێشتخانەی تاقیکردنەوە', 'name_ar': 'مطعم تجريبي', 'name_en': 'Test Restaurant'},
      ],
    });
    RegaI18n.setLang('en');
    expect(tx('چێشتخانەی تاقیکردنەوە'), 'Test Restaurant');
    RegaI18n.setLang('ar');
    expect(tx('چێشتخانەی تاقیکردنەوە'), 'مطعم تجريبي');
  });

  test('txn keeps null', () {
    expect(txn(null), isNull);
  });
}
