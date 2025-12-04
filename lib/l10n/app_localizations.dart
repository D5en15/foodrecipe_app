import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Class สำหรับจัดการเปลี่ยนภาษา (State Management อย่างง่าย)
class AppLanguage extends ChangeNotifier {
  Locale _appLocale = const Locale('th'); // เริ่มต้นที่ไทย

  Locale get appLocale => _appLocale;

  void changeLanguage(Locale type) {
    if (_appLocale == type) return;
    _appLocale = type;
    notifyListeners();
  }
}

// Class สำหรับโหลดและแปลภาษาจาก JSON
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // ตัวช่วยสำหรับ Delegate
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  // ฟังก์ชันโหลดไฟล์ JSON จาก Assets
  Future<bool> load() async {
    // โหลดไฟล์ตาม languageCode (เช่น assets/lang/th.json)
    String jsonString = await rootBundle.loadString('assets/lang/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  // ฟังก์ชันเรียกใช้คำ (เหมือนเดิมเป๊ะ)
  String t(String key) {
    return _localizedStrings[key] ?? key; // ถ้าหาไม่เจอให้คืนค่า key กลับไป
  }
}

// Delegate เพื่อบอก Flutter ว่าจะโหลดภาษาอย่างไร
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // ระบุภาษาที่รองรับ
    return ['en', 'th'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load(); // รอโหลดไฟล์ JSON จนเสร็จ
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}