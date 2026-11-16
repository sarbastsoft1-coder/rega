import 'dart:async';
import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'rega_i18n_dict.dart';

/// Shared ku / ar / en translator for every REGA app.
///
/// UI text in the code base is written in Kurdish (some Arabic). [tx] turns any
/// on-screen string into the active language so English mode shows no
/// Kurdish/Arabic and Arabic mode shows no Kurdish:
///   1. exact dictionary match,
///   2. template match for keys with `{placeholders}`,
///   3. phrase-by-phrase replacement when every Kurdish/Arabic word is covered
///      (handles strings built with interpolation like `'$count بەرهەم'`).
/// Text that is not in the dictionary (user data such as names) is returned
/// unchanged.
class RegaI18n {
  RegaI18n._();

  static String _lang = 'ku';
  static String get lang => _lang;

  static String normalize(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'en' || v == 'english' || v.startsWith('en_') || v.startsWith('en-')) return 'en';
    if (v == 'ar' || v == 'العربية' || v == 'عربي' || v == 'عەرەبی' || v.startsWith('ar_')) return 'ar';
    return 'ku';
  }

  /// Set the active language. When it changes, the whole widget tree is
  /// rebuilt on the next frame so every [tx] call picks up the new language.
  static void setLang(String raw) {
    final code = normalize(raw);
    if (code == _lang) return;
    _lang = code;
    _cache.clear();
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      final root = binding.rootElement;
      if (root == null) return;
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      root.visitChildren(visit);
    });
    binding.scheduleFrame();
    _startAuditIfEnabled();
  }

  // ── Names learned from server data ───────────────────────────────────
  // API rows carry name_ku / name_ar / name_en (also title_*, address_*,
  // description_*). Remember each set so tx(nameKu) shows the right language.
  static final Map<String, List<String>> _learned = {};
  static const List<String> _fieldStems = ['name', 'title', 'address', 'description', 'subtitle', 'label'];

  static void learn(dynamic json) {
    var added = false;
    void walk(dynamic v, int depth) {
      if (depth > 12) return;
      if (v is Map) {
        for (final stem in _fieldStems) {
          final ku = v['${stem}_ku']?.toString().trim() ?? '';
          final ar = v['${stem}_ar']?.toString().trim() ?? '';
          final en = v['${stem}_en']?.toString().trim() ?? '';
          if (ku.isEmpty && ar.isEmpty) continue;
          if (en.isEmpty && ar.isEmpty) continue;
          final row = [ku.isNotEmpty ? ku : (en.isNotEmpty ? en : ar), ar.isNotEmpty ? ar : (ku.isNotEmpty ? ku : en), en];
          for (final key in [ku, ar]) {
            if (key.isEmpty) continue;
            final old = _learned[key];
            if (old == null || old.join() != row.join()) {
              _learned[key] = row;
              added = true;
            }
          }
        }
        for (final child in v.values) {
          if (child is Map || child is List) walk(child, depth + 1);
        }
      } else if (v is List) {
        for (final child in v) {
          if (child is Map || child is List) walk(child, depth + 1);
        }
      }
    }

    walk(json, 0);
    if (added) _cache.clear();
  }

  // ── Test-only audit ─────────────────────────────────────────────────────
  // Build with --dart-define=REGA_I18N_AUDIT=true to print every visible
  // string that is still in the wrong language (I18N-MISS lines in console).
  static const bool _auditEnabled = bool.fromEnvironment('REGA_I18N_AUDIT');
  static Timer? _auditTimer;
  static final Set<String> _reported = {};
  static final RegExp _kuOnly = RegExp(r'[ەێۆڕڵڤگچپژیک]');

  static void _startAuditIfEnabled() {
    if (!_auditEnabled || _auditTimer != null) return;
    _auditTimer = Timer.periodic(const Duration(seconds: 2), (_) => _auditOnce());
  }

  static void _auditOnce() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null || _lang == 'ku') return;
    void visit(Element e) {
      final ro = e.renderObject;
      if (e is RenderObjectElement && ro is RenderParagraph) {
        final text = ro.text.toPlainText();
        final bad = _lang == 'en' ? _letters.hasMatch(text) : _kuOnly.hasMatch(text);
        if (bad && _reported.add('$_lang|$text')) {
          // ignore: avoid_print
          print('I18N-MISS[$_lang]: ${text.replaceAll(String.fromCharCode(10), ' ')}');
        }
      }
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
  }

  static int _idx(String code) => code == 'en' ? 2 : (code == 'ar' ? 1 : 0);

  static final RegExp _script = RegExp(r'[؀-ۿ]');
  // Letters only (digits ٠-٩, ، ؛ ؟ ٪ and tatweel are not "words").
  static final RegExp _letters = RegExp(r'[ء-يٱ-ۓەۮ-ۿ]');
  static final RegExp _ph = RegExp(r'\{(\w+)\}');

  static final Map<String, String> _cache = {};
  static List<_Template>? _templates;
  static List<String>? _phrases;

  static String toWesternDigits(String s) {
    const east = '٠١٢٣٤٥٦٧٨٩';
    const pers = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      var i = east.indexOf(ch);
      if (i < 0) i = pers.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (ch == '،') {
        b.write(',');
      } else if (ch == '؛') {
        b.write(';');
      } else if (ch == '؟') {
        b.write('?');
      } else if (ch == '٪') {
        b.write('%');
      } else if (ch == 'ـ') {
        // tatweel: drop
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  /// Translate [input] into the active language.
  static String t(Object? input) {
    if (input == null) return '';
    final s = input.toString();
    if (s.isEmpty || !_script.hasMatch(s)) return s;
    final key = '$_lang\u0000$s';
    final hit = _cache[key];
    if (hit != null) return hit;
    var out = _translate(s, _idx(_lang));
    if (_lang == 'en') out = toWesternDigits(out);
    if (_cache.length > 4000) _cache.clear();
    _cache[key] = out;
    return out;
  }

  static String _translate(String s, int li) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return s;
    final lead = s.substring(0, s.indexOf(trimmed));
    final trail = s.substring(s.indexOf(trimmed) + trimmed.length);

    final learned = _learned[trimmed];
    if (learned != null && learned[li].isNotEmpty) return '$lead${learned[li]}$trail';
    final exact = kRegaI18n[trimmed];
    if (exact != null) return '$lead${exact[li]}$trail';

    for (final t in _templateList()) {
      final m = t.re.firstMatch(trimmed);
      if (m == null) continue;
      var target = t.values[li];
      for (var g = 0; g < t.names.length; g++) {
        target = target.replaceAll('{${t.names[g]}}', _translate(m.group(g + 1) ?? '', li));
      }
      return '$lead$target$trail';
    }

    final phrased = _byPhrases(s, li);
    return phrased ?? s;
  }

  static List<_Template> _templateList() {
    return _templates ??= () {
      final list = <_Template>[];
      kRegaI18n.forEach((k, v) {
        if (!_ph.hasMatch(k)) return;
        final names = <String>[];
        final pattern = StringBuffer('^');
        var last = 0;
        for (final m in _ph.allMatches(k)) {
          pattern.write(RegExp.escape(k.substring(last, m.start)));
          pattern.write('(.+?)');
          names.add(m.group(1)!);
          last = m.end;
        }
        pattern.write(RegExp.escape(k.substring(last)));
        pattern.write(r'$');
        list.add(_Template(RegExp(pattern.toString()), names, v));
      });
      list.sort((a, b) => b.re.pattern.length.compareTo(a.re.pattern.length));
      return list;
    }();
  }

  static List<String> _phraseList() {
    return _phrases ??= (kRegaI18n.keys.where((k) => !_ph.hasMatch(k) && _letters.hasMatch(k)).toList()
      ..sort((a, b) => b.length.compareTo(a.length)));
  }

  static bool _isLetter(String s, int i) => i >= 0 && i < s.length && _letters.hasMatch(s[i]);

  /// Replace whole-word dictionary phrases; succeed only if no Kurdish/Arabic
  /// letters remain afterwards (so names / free text stay untouched).
  static String? _byPhrases(String s, int li) {
    final slots = <String>[];
    var work = s;
    for (final p in _phraseList()) {
      if (!work.contains(p)) continue;
      var from = 0;
      while (true) {
        final i = work.indexOf(p, from);
        if (i < 0) break;
        final end = i + p.length;
        if (_isLetter(work, i - 1) || _isLetter(work, end)) {
          from = i + 1;
          continue;
        }
        final token = '\u0001${slots.length}\u0002';
        slots.add(kRegaI18n[p]![li]);
        work = work.replaceRange(i, end, token);
        from = i + token.length;
      }
      if (!_letters.hasMatch(work)) break;
    }
    if (slots.isEmpty || _letters.hasMatch(work)) return null;
    return work.replaceAllMapped(RegExp('\u0001(\\d+)\u0002'), (m) => slots[int.parse(m.group(1)!)]);
  }
}

class _Template {
  final RegExp re;
  final List<String> names;
  final List<String> values;
  _Template(this.re, this.names, this.values);
}

/// Translate any on-screen string into the active app language.
String tx(Object? text) => RegaI18n.t(text);

/// Nullable variant for optional String params (hintText, errorText, tooltip…).
String? txn(String? text) => text == null ? null : RegaI18n.t(text);

/// jsonDecode that also teaches [RegaI18n] the ku/ar/en names in the payload.
dynamic regaJsonDecode(String source) {
  final v = jsonDecode(source);
  RegaI18n.learn(v);
  return v;
}
