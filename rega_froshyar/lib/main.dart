import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import "package:flutter/foundation.dart";
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vendor_api_service.dart';
import 'blocked_account.dart';
import 'assigned_driver_map.dart';
import 'rega_mobile.dart';
import 'image_compress_service.dart';
import 'services/vendor_image_pick.dart';
import 'app/providers.dart';
import 'app/app_router.dart';
import 'state/vendor_nav_notifier.dart';
import 'state/vendor_session_notifier.dart';
import 'iraq_phone_formatter.dart';
import 'service_area.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;
import 'map/mapbox_tiles.dart';
import 'rega_i18n.dart';
import 'rega_colors.dart';

part 'products_menu_screen.dart';

// ==============================================================================
// 🔔 خزمەتگوزاری دەنگی موزیک و ئاگادارکردنەوە بۆ داواکارییە نوێیەکان (Order Sound Service)
// ئەم بەشە بەرپرسە لە لێدانی زەنگی گەورە و بەهێز بۆ داواکاری نوێ
// ==============================================================================
// 🔔 خزمەتگوزاری دەنگی موزیک و ئاگادارکردنەوە بۆ داواکارییە نوێیەکان (Order Sound Service)
// ئەم بەشە بەرپرسە لە لێدانی زەنگی گەورە و بەهێز بۆ داواکاری نوێ
// ==============================================================================
class OrderSoundService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// لێدانی زەنگی موزیک و ئاگادارکردنەوەی گەورە (طنین و موسیقای زەنگ)
  static const String _newOrderSoundAsset =
      'assets/sounds/mixkit-happy-bells-notification-937.wav';

  static Future<void> playNewOrderAlert({bool soundEnabled = true}) async {
    if (!soundEnabled) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource(_newOrderSoundAsset));
    } catch (e) {
      debugPrint('Error playing AudioPlayer sound: $e');
    }

    try {
      // Haptic pulse with the bells (no extra system beep — WAV is the alert).
      for (int i = 0; i < 2; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 280));
      }
    } catch (e) {
      debugPrint('Error playing haptic alert: $e');
    }
  }

  /// تاقیکردنەوەی زەنگ و موزیک
  static Future<void> playTestTone() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setSource(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error playing test tone: $e');
    }
  }
}

// ==============================================================================
// 📌 لۆگۆی ناڤ باڕی سەرەوە (Top Bar Logo Configuration)
// بە پێی فایلی پرۆژەکەت لێرە دانراوە: 'assets/logo.png'
// ئەپەکە بە شێوازی سەلامەت فایلی logo.png لە فۆڵدەری assets دەخوێنێتەوە
// ==============================================================================
const String kAppLogoFilePath = 'assets/logo.png';

// ==============================================================================
// 📌 فۆنتی سەرەکی ئەپ (Global Font Family)
// فۆنتی دیاریکراو بۆ هەموو تێکست و بەشەکانی ئەپەکە: Noto Kufi Arabic
// ==============================================================================
const String kAppFontFamily = 'NotoKufiArabic';


class Trans {
  static const String _prefKey = 'rega_vendor_lang';
  static final ValueNotifier<String> lang = ValueNotifier<String>('ku');
  static const String _darkKey = 'rega_vendor_dark_mode';
  static final ValueNotifier<bool> dark = ValueNotifier<bool>(false);

  static Future<void> setDark(bool value) async {
    dark.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkKey, value);
    } catch (e) {
      debugPrint('Error saving vendor theme: $e');
    }
  }

  static Future<void> loadSavedLang() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      dark.value = prefs.getBool(_darkKey) ?? false;
      if (saved != null && (saved == 'ku' || saved == 'ar' || saved == 'en')) {
        lang.value = saved;
      }
    } catch (e) {
      debugPrint('Error loading vendor language: $e');
    }
  }

  static Future<void> _persistLang(String l) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, l);
    } catch (e) {
      debugPrint('Error saving vendor language: $e');
    }
  }

  static void setLang(String l) {
    lang.value = l;
    _persistLang(l);
  }
  static TextDirection get direction => lang.value == 'en' ? TextDirection.ltr : TextDirection.rtl;

  static String get(String key) {
    if (lang.value == 'ku') return tx(key);
    return _dict[key]?[lang.value] ?? tx(key);
  }

  static final Map<String, Map<String, String>> _dict = {
     'ڕێکخستن': {'en': 'Settings', 'ar': 'الإعدادات'},
     'داهاتی فرۆشیار': {'en': 'Vendor Revenue', 'ar': 'إيرادات البائع'},
     'داهاتی فڕۆشیار': {'en': 'Vendor Revenue', 'ar': 'إيرادات البائع'},
     'فڕۆشی ئەمڕۆ': {'en': "Today's sales", 'ar': 'مبيعات اليوم'},
     'فڕۆشی ئەم هەفتەیە': {'en': 'This week sales', 'ar': 'مبيعات هذا الأسبوع'},
     'فڕۆشی مانگ': {'en': 'Month sales', 'ar': 'مبيعات الشهر'},
     'داهاتی سافی': {'en': 'Net income', 'ar': 'صافي الدخل'},
     'کۆمیسیۆن': {'en': 'Commission', 'ar': 'العمولة'},
     'بەرواری دیاریکراو': {'en': 'Custom date', 'ar': 'تاريخ محدد'},
     'هیچ فڕۆشێک تۆمار نەکراوە تا ئێستا': {'en': 'No sales recorded yet', 'ar': 'لم تُسجَّل أي مبيعات بعد'},
     'داواکاری': {'en': 'order', 'ar': 'طلب'},
     'مێنۆ و بەرهەم': {'en': 'Menu & Products', 'ar': 'القائمة والمنتجات'},
     'داواکارییەکان': {'en': 'Orders', 'ar': 'الطلبات'},
     'ڕێکخستنی دوکان': {'en': 'Store Settings', 'ar': 'إعدادات المتجر'},
     'زانیاری بنەڕەتی، زمان و کاتژمێری کارکردن': {'en': 'Basic Info, Language & Working Hours', 'ar': 'المعلومات الأساسية، اللغة وساعات العمل'},
     'زانیاری بنەڕەتی': {'en': 'Basic Info', 'ar': 'المعلومات الأساسية'},
     'ژمارەی مۆبایل *': {'en': 'Mobile Number *', 'ar': 'رقم الموبايل *'},
     'ناوی دوکان *': {'en': 'Store Name *', 'ar': 'اسم المتجر *'},
     'فرۆشگا': {'en': 'Store', 'ar': 'المتجر'},
     'کاتی کارکردن': {'en': 'Working Hours', 'ar': 'ساعات العمل'},
     'کاتی داخستن': {'en': 'Closing Time', 'ar': 'وقت الإغلاق'},
     'کاتی کردنەوە': {'en': 'Opening Time', 'ar': 'وقت الفتح'},
     'وێنەی دوکان (لۆگۆ و بەرگ)': {'en': 'Store Images (Logo & Cover)', 'ar': 'صور المتجر (الشعار والغلاف)'},
     'وێنەی بەرگ (Cover)': {'en': 'Cover Image', 'ar': 'صورة الغلاف'},
     'گۆڕینی بەرگ': {'en': 'Change Cover', 'ar': 'تغيير الغلاف'},
     'لۆگۆی دوکان (Logo)': {'en': 'Store Logo', 'ar': 'شعار المتجر'},
     'گۆڕینی لۆگۆ': {'en': 'Change Logo', 'ar': 'تغيير الشعار'},
     'زمانی بەرنامە': {'en': 'App Language', 'ar': 'لغة التطبيق'},
     'کوردی': {'en': 'Kurdish', 'ar': 'كردي'},
     'پاشەکەوتکردنی گۆڕانکارییەکان': {'en': 'Save Changes', 'ar': 'حفظ التغييرات'},
     'چوونە دەرەوە لە هەژمار': {'en': 'Log Out', 'ar': 'تسجيل الخروج'},
     'گۆڕانکارییەکان پاشەکەوت کران': {'en': 'Changes Saved', 'ar': 'تم حفظ التغييرات'},
     'هەڵبژاردنی وێنە لە': {'en': 'Choose Image From', 'ar': 'اختر صورة من'},
     'کامێرا': {'en': 'Camera', 'ar': 'الكاميرا'},
     'گەلەری': {'en': 'Gallery', 'ar': 'المعرض'},
     'REGA - LIVE': {'en': 'REGA - LIVE', 'ar': 'ريجا - مباشر'},
     'داواکارییە چالاکەکان': {'en': 'Active Orders', 'ar': 'الطلبات النشطة'},
     'چاوەڕوانکراو': {'en': 'Pending', 'ar': 'قيد الانتظار'},
     'داواکاری نوێ': {'en': 'New Order', 'ar': 'طلب جديد'},
     'قبوڵکراو': {'en': 'Accepted', 'ar': 'مقبول'},
     'لە ئامادەکردندایە': {'en': 'Preparing', 'ar': 'جاري التجهيز'},
     'ئامادەیە بۆ شۆفێر': {'en': 'Ready for Driver', 'ar': 'جاهز للسائق'},
     'تەواوبوو': {'en': 'Completed', 'ar': 'مكتمل'},
     'تەواو': {'en': 'Completed', 'ar': 'مكتمل'},
     'پاشگەزبوونەوە': {'en': 'Cancelled', 'ar': 'ملغى'},
     'ڕەتکردنەوە': {'en': 'Reject', 'ar': 'رفض'},
     'رەتکردنەوە': {'en': 'Reject', 'ar': 'رفض'},
     'قبولکردن': {'en': 'Accept', 'ar': 'قبول'},
     'قبوڵکردن': {'en': 'Accept', 'ar': 'قبول'},
     'تاقیکردنەوەی داواکاری نوێ': {'en': 'Test New Order', 'ar': 'تجربة طلب جديد'},
     'تاقیکردنەوەی داواکاری': {'en': 'Test Order', 'ar': 'تجربة طلب'},
     'سڕینەوەی تەواوبووەکان': {'en': 'Clear completed', 'ar': 'حذف المكتملة'},
     'فرۆشگا کراوەیە': {'en': 'Store is open', 'ar': 'المتجر مفتوح'},
     'فرۆشگا داخراوە': {'en': 'Store is closed', 'ar': 'المتجر مغلق'},
     'ناوی کڕیار': {'en': 'Customer Name', 'ar': 'اسم الزبون'},
     'ناونیشانی کڕیار': {'en': 'Customer Address', 'ar': 'عنوان الزبون'},
     'دەستپێکردنی ئامادەکردن': {'en': 'Start Preparing', 'ar': 'بدء التجهيز'},
     'کۆی گشتی :': {'en': 'Total :', 'ar': 'الإجمالي :'},
     'کاتی پێچوون :': {'en': 'Prep time :', 'ar': 'وقت التجهيز :'},
     'کاتی ماوە :': {'en': 'Time left :', 'ar': 'الوقت المتبقي :'},
     'مۆبایلی کڕیار': {'en': 'Customer Mobile', 'ar': 'موبايل الزبون'},
     'دۆخ': {'en': 'Status', 'ar': 'الحالة'},
     'شۆفێر': {'en': 'Driver', 'ar': 'السائق'},
     'دینار': {'en': 'IQD', 'ar': 'دينار'},
     'خولەک': {'en': 'min', 'ar': 'دقيقة'},
     'چرکە': {'en': 'sec', 'ar': 'ثانية'},
     'چاوەڕوانی شۆفێر': {'en': 'Waiting for driver', 'ar': 'بانتظار السائق'},
     'تێبینی : کڕیار لە': {'en': 'Note: Customer ordering from', 'ar': 'ملاحظة: الزبون يطلب من'},
     'داوای دەکات': {'en': 'is ordering', 'ar': 'يطلب'},
     'سرینەوەی داواکاری': {'en': 'Delete Order', 'ar': 'حذف الطلب'},
     'سڕینەوەی داواکاری': {'en': 'Delete Order', 'ar': 'حذف الطلب'},
     'سرینەوە': {'en': 'Delete', 'ar': 'حذف'},
     'ئایا دڵنیایت لە سرینەوەی ئەم داواکارییە؟': {'en': 'Are you sure you want to delete this order?', 'ar': 'هل أنت متأكد من حذف هذا الطلب؟'},
     'سرینەوەی تەواوبووەکان': {'en': 'Clear Completed', 'ar': 'حذف المكتملة'},
     'وردەکاری': {'en': 'Details', 'ar': 'التفاصيل'},
     'دڵنیایت لە سڕینەوەی ئەم داواکارییە؟': {'en': 'Delete this order?', 'ar': 'هل تريد حذف هذا الطلب؟'},
     'ئایا دڵنیایت لە سڕینەوەی ئەم داواکارییە؟': {'en': 'Are you sure you want to delete this order?', 'ar': 'هل أنت متأكد من حذف هذا الطلب؟'},
     'دڵنیایت لە سڕینەوەی هەموو داواکاری تەواوبووەکان؟': {'en': 'Clear all completed orders?', 'ar': 'هل تريد حذف كل الطلبات المكتملة؟'},
     'بەڵێ، بسڕەوە': {'en': 'Yes, delete', 'ar': 'نعم، احذف'},
     'سڕینەوە': {'en': 'Delete', 'ar': 'حذف'},
     'تێبینی': {'en': 'Note', 'ar': 'ملاحظة'},
     'تکایە هۆکاری ڕەتکردنەوە بنووسە': {'en': 'Please write a rejection reason', 'ar': 'يرجى كتابة سبب الرفض'},
     'قبوڵکردنی داواکاری سەرکەوتوو نەبوو': {'en': 'Failed to accept order', 'ar': 'فشل قبول الطلب'},
     'ڕەتکردنەوە سەرکەوتوو نەبوو': {'en': 'Failed to reject order', 'ar': 'فشل رفض الطلب'},
     'نوێکردنەوەی بەش سەرکەوتوو نەبوو': {'en': 'Failed to update category', 'ar': 'فشل تحديث القسم'},
     'بەش نوێکرایەوە': {'en': 'Category updated', 'ar': 'تم تحديث القسم'},
     'بەش نەدۆزرایەوە': {'en': 'Category not found', 'ar': 'القسم غير موجود'},
     'بەرهەم نوێکرایەوە': {'en': 'Product updated', 'ar': 'تم تحديث المنتج'},
     'نوێکردنەوەی بەرهەم سەرکەوتوو نەبوو': {'en': 'Failed to update product', 'ar': 'فشل تحديث المنتج'},
     'دۆخی بەرهەم نوێکرایەوە': {'en': 'Product status updated', 'ar': 'تم تحديث حالة المنتج'},
     'گۆڕینی دۆخی بەرهەم سەرکەوتوو نەبوو': {'en': 'Failed to update product status', 'ar': 'فشل تحديث حالة المنتج'},
     'بەرهەم سڕایەوە': {'en': 'Product deleted', 'ar': 'تم حذف المنتج'},
     'سڕینەوەی بەرهەم سەرکەوتوو نەبوو': {'en': 'Failed to delete product', 'ar': 'فشل حذف المنتج'},
     'ڕادەستکردنی داواکاری': {'en': 'Deliver Order', 'ar': 'تسليم الطلب'},
     'هیچ داواکارییەک نییە': {'en': 'No Orders', 'ar': 'لا توجد طلبات'},
     'لە کاتی هاتنی داواکاری لە ئەپی کڕیاران لێرە دەردەکەوێت': {'en': 'When orders arrive from the customer app, they will appear here.', 'ar': 'عند وصول الطلبات من تطبيق العملاء ستظهر هنا'},
     'ئەمڕۆ': {'en': 'Today', 'ar': 'اليوم'},
     'ئەم هەفتەیە': {'en': 'This Week', 'ar': 'هذا الأسبوع'},
     'ئەم مانگە': {'en': 'This Month', 'ar': 'هذا الشهر'},
     'کۆی داواکاری تەواوکراو': {'en': 'Total Completed Orders', 'ar': 'إجمالي الطلبات المكتملة'},
     'ع.د صافی قازانج': {'en': 'IQD Net Profit', 'ar': 'د.ع صافي الربح'},
     'کۆمیسیۆن (١٢٪)': {'en': 'Commission (12%)', 'ar': 'العمولة (١٢٪)'},
     'کۆی فرۆش': {'en': 'Total Sales', 'ar': 'إجمالي المبيعات'},
     'شیکاری داهاتی کاتژمێرەکانی ئەمڕۆ': {'en': 'Today\'s Hourly Revenue Analysis', 'ar': 'تحليل الإيرادات بالساعة لليوم'},
     'شیکاری داهاتی ٧ ڕۆژی ڕابردوو': {'en': 'Past 7 Days Revenue Analysis', 'ar': 'تحليل الإيرادات لآخر ٧ أيام'},
     'شیکاری داهاتی هەفتەکانی ئەم مانگە': {'en': 'This Month\'s Weekly Revenue Analysis', 'ar': 'تحليل الإيرادات الأسبوعية لهذا الشهر'},
     'بەپێی کۆی فرۆش': {'en': 'By Total Sales', 'ar': 'حسب إجمالي المبيعات'},
     'پڕداهاتترین بەرهەمەکان': {'en': 'Top Grossing Products', 'ar': 'المنتجات الأعلى إيراداً'},
     'هیچ فرۆشێک تۆمار نەکراوە تا ئێستا': {'en': 'No sales recorded yet', 'ar': 'لم يتم تسجيل أي مبيعات حتى الآن'},
     'ع.د': {'en': 'IQD', 'ar': 'د.ع'},
     'زیادکردنی بەرهەم': {'en': 'Add Product', 'ar': 'إضافة منتج'},
     'زیادکردنی بەشی نوێ': {'en': 'Add New Category', 'ar': 'إضافة قسم جديد'},
     'تکایە ناوی ئەو بەشە بنووسە کە دەتەوێت زیادی بکەیت': {'en': 'Please enter the name of the category you want to add', 'ar': 'الرجاء إدخال اسم القسم الذي تريد إضافته'},
     'ناوی بەش': {'en': 'Category Name', 'ar': 'اسم القسم'},
     'وێنەی بەش': {'en': 'Category Image', 'ar': 'صورة القسم'},
     'پاشگەزبونەوە': {'en': 'Cancel', 'ar': 'إلغاء'},
     'زیادکردن': {'en': 'Add', 'ar': 'إضافة'},
     'دەستکاریکردنی بەرهەم': {'en': 'Edit Product', 'ar': 'تعديل المنتج'},
     'ناوی بەرهەم *': {'en': 'Product Name *', 'ar': 'اسم المنتج *'},
     'بەش / پۆڵێن *': {'en': 'Category *', 'ar': 'القسم / التصنيف *'},
     'بەشێک هەڵبژێرە': {'en': 'Select Category', 'ar': 'اختر القسم'},
     'نرخی ئاسایی *': {'en': 'Regular Price *', 'ar': 'السعر العادي *'},
     'نرخی دوای داشکان': {'en': 'Price after Discount', 'ar': 'السعر بعد الخصم'},
     'داشکاندنی بەرهەم (٪)': {'en': 'Product Discount (%)', 'ar': 'خصم المنتج (%)'},
     'بێ داشکاندن': {'en': 'No Discount', 'ar': 'بدون خصم'},
     'نرخی دوای داشکاندن': {'en': 'Price after discount', 'ar': 'السعر بعد الخصم'},
     'داشکاندنی دوکان': {'en': 'Store Discount', 'ar': 'خصم المتجر'},
     'داشکاندن بۆ هەموو دوکانەکە': {'en': 'Discount for whole store', 'ar': 'خصم على كل المتجر'},
     'داشکاندن بۆ بەرهەمێک': {'en': 'Discount for one product', 'ar': 'خصم على منتج واحد'},
     'ڕێژەی داشکاندن هەڵبژێرە': {'en': 'Select discount percentage', 'ar': 'اختر نسبة الخصم'},
     'جێبەجێکردنی داشکاندن': {'en': 'Apply Discount', 'ar': 'تطبيق الخصم'},
     'لابردنی داشکاندنی دوکان': {'en': 'Remove store discount', 'ar': 'إزالة خصم المتجر'},
     'داشکاندن بۆ هەموو بەرهەمەکان جێبەجێ دەکرێت': {'en': 'Discount will apply to all products', 'ar': 'سيتم تطبيق الخصم على كل المنتجات'},
     'وەسفی بەرهەم - کوردی (ئارەزوومەندانە)': {'en': 'Product Description - Kurdish (Optional)', 'ar': 'وصف المنتج - كردي (اختياري)'},
     'وەسفی بەرهەم - عەرەبی': {'en': 'Product Description - Arabic', 'ar': 'وصف المنتج - عربي'},
     'وێنەی بەرهەم': {'en': 'Product Image', 'ar': 'صورة المنتج'},
     'هەڵبژاردنی فایل': {'en': 'Choose File', 'ar': 'اختر ملف'},
     'هەڵبژاردن و بارکردنی وێنە': {'en': 'Choose & upload image', 'ar': 'اختيار ورفع صورة'},
     'گۆڕینی وێنە': {'en': 'Change image', 'ar': 'تغيير الصورة'},
     'کرتە بکە بۆ هەڵبژاردنی وێنە': {'en': 'Tap to choose an image', 'ar': 'اضغط لاختيار صورة'},
     'بارکردنی وێنە...': {'en': 'Uploading image...', 'ar': 'جاري رفع الصورة...'},
     'بارکردنی وێنە سەرکەوتوو نەبوو': {'en': 'Image upload failed', 'ar': 'فشل رفع الصورة'},
     'هیچ فایلێک دیاری نەکراوە': {'en': 'No file selected', 'ar': 'لم يتم تحديد ملف'},
     'بەردەست': {'en': 'Available', 'ar': 'متاح'},
     'بەردەستە': {'en': 'Available', 'ar': 'متاح'},
     'نابەردەست': {'en': 'Unavailable', 'ar': 'غير متاح'},
     'نەماوە': {'en': 'Out of stock', 'ar': 'غير متوفر'},
     'داشکاندن': {'en': 'Discounted', 'ar': 'مخفض'},
     'بەرهەمی نوێ': {'en': 'New Product', 'ar': 'منتج جديد'},
     'مێنۆ و بەرهەمەکان': {'en': 'Menu & Products', 'ar': 'القائمة والمنتجات'},
     'بەشەکان': {'en': 'Categories', 'ar': 'الأقسام'},
     'بەڕێوەبردنی بەشەکان': {'en': 'Manage Categories', 'ar': 'إدارة الأقسام'},
     'بەشەکانی مێنۆ': {'en': 'Menu Categories', 'ar': 'أقسام القائمة'},
     'زیادکردنی بەش': {'en': 'Add section', 'ar': 'إضافة قسم'},
     'هیچ بەشێک زیاد نەکراوە': {'en': 'No sections have been added', 'ar': 'لم تتم إضافة أي أقسام'},
     '...ناوی بەش بنووسە': {'en': '...Write section name', 'ar': '...اكتب اسم القسم'},
     'هەڵبژاردنی وێنە': {'en': 'Select image', 'ar': 'اختيار صورة'},
     'هیچ بابەتێک لەم بەشەدا نییە': {'en': 'No items in this section', 'ar': 'لا توجد عناصر في هذا القسم'},
     'دەستکاری بابەت': {'en': 'Edit item', 'ar': 'تعديل العنصر'},
     'ناوی بابەت بە کوردی': {'en': 'Item name in Kurdish', 'ar': 'اسم العنصر بالكردية'},
     'ناوی بابەت بە عەرەبی': {'en': 'Item name in Arabic', 'ar': 'اسم العنصر بالعربية'},
     'وەسف': {'en': 'Description', 'ar': 'الوصف'},
     'داشکان': {'en': 'Discount', 'ar': 'الخصم'},
     'کاتی پێچوون (خولەک)': {'en': 'Prep time (min)', 'ar': 'وقت التحضير (دقيقة)'},
     'نرخی گەیاندن': {'en': 'Delivery price', 'ar': 'سعر التوصيل'},
     'زیادکردنی تایبەتمەندی +': {'en': 'Add feature +', 'ar': 'إضافة ميزة +'},
     '+ زیادکردنی تایبەتمەندی': {'en': '+ Add feature', 'ar': '+ إضافة ميزة'},
     'زیادکردنی تایبەتمەندی': {'en': 'Add feature', 'ar': 'إضافة ميزة'},
     'تایبەتمەندییەکان': {'en': 'Features', 'ar': 'الميزات'},
     'ناوی تایبەتمەندی': {'en': 'Feature name', 'ar': 'اسم الميزة'},
     'نرخی زیادە (ئارەزوومەندانە)': {'en': 'Extra price (optional)', 'ar': 'سعر إضافي (اختياري)'},
     'وێنە': {'en': 'Image', 'ar': 'صورة'},
     'سڕینەوەی بەش': {'en': 'Delete section', 'ar': 'حذف القسم'},
     'نرخ': {'en': 'Price', 'ar': 'السعر'},
     'تاقیکردنەوەی دەنگ': {'en': 'Sound test', 'ar': 'اختبار الصوت'},
     'test music': {'en': 'test music', 'ar': 'test music'},
     'گالەری': {'en': 'Gallery', 'ar': 'المعرض'},
     'گۆڕینی ناوی بەش': {'en': 'Rename Category', 'ar': 'تعديل اسم القسم'},
     'هیچ بەشێک نییە': {'en': 'No categories yet', 'ar': 'لا توجد أقسام بعد'},
     'پاشەکەوتکردن': {'en': 'Save', 'ar': 'حفظ'},
     '...گەڕان': {'en': '...Search', 'ar': '...بحث'},
     'دەستکاری': {'en': 'Edit', 'ar': 'تعديل'},
     'تۆمارکردنی بەرهەم': {'en': 'Save Product', 'ar': 'حفظ المنتج'},
     'هیچ بەرهەمێک نەدۆزرایەوە': {'en': 'No Products Found', 'ar': 'لم يتم العثور على منتجات'},
     'دەتوانیت بە کلیک لەسەر دوگمەی (بەرهەمی نوێ) یەکەمین کاڵا زیادبکەیت.': {'en': 'You can add your first item by clicking (Add Product).', 'ar': 'يمكنك إضافة العنصر الأول بالنقر على (إضافة منتج).'},
     'پانیڵى بەڕێوەبردنى فرۆشیاران (REGA Vendor)': {'en': 'Vendor Management Panel (REGA Vendor)', 'ar': 'لوحة إدارة البائعين (REGA Vendor)'},
     'بەخێر بێیت بۆ ئەپی ڕێگا': {'en': 'Welcome to REGA App', 'ar': 'أهلاً بك في تطبيق ريجا'},
     'بەخێر بێت بۆ ئەپی ڕێگا': {'en': 'Welcome to REGA App', 'ar': 'أهلاً بك في تطبيق ريجا'},
     'بەخێربێیت بۆ ئەپی ڕێگا': {'en': 'Welcome to REGA App', 'ar': 'أهلاً بك في تطبيق ريجا'},
     'مێنۆ': {'en': 'Menu', 'ar': 'القائمة'},
     'داهات': {'en': 'Revenue', 'ar': 'الإيرادات'},
     'ژمارەی مۆبایل': {'en': 'Mobile Number', 'ar': 'رقم الموبايل'},
     'وشەی تێپەڕ': {'en': 'Password', 'ar': 'كلمة المرور'},
     'چوونە ژوورەوە': {'en': 'Log In', 'ar': 'تسجيل الدخول'},
     'هێشتا نەبوویتە فرۆشیار لە ئەپی ڕێگا': {'en': 'Not a vendor in REGA App yet?', 'ar': 'لست بائعاً في تطبيق ريجا بعد؟'},
     'خۆت تۆمار بکە': {'en': 'Register', 'ar': 'سجل الآن'},
     'تۆمارکردنی فرۆشگای نوێ': {'en': 'New Shop Registration', 'ar': 'تسجيل متجر جديد'},
     'بۆ بەشداریکردن و کردنەوەی هەژماری فرۆشیار لە ڕێگا، تکایە پەیوەندی بە تیمی پشتگیرییەوە بکە لە ڕێگەی WhatsApp یان Telegram، یان سەردانی نووسینگەمان بکە.': {
       'en': 'To join and open a seller account on REGA, please contact support via WhatsApp or Telegram, or visit our office.',
       'ar': 'للمشاركة وفتح حساب بائع في ريجا، يرجى التواصل مع فريق الدعم عبر واتساب أو تيليجرام، أو زيارة مكتبنا.',
     },
     'باشە': {'en': 'OK', 'ar': 'حسناً'},
     'کراوەیە': {'en': 'Open', 'ar': 'مفتوح'},
     'داخراوە': {'en': 'Closed', 'ar': 'مغلق'},
     'داخستن': {'en': 'Close', 'ar': 'إغلاق'},
     'ڕادەستکردن بە شۆفێر': {
       'en': 'Hand over to driver',
       'ar': 'تسليم للسائق',
     },
  };
}

String t(String key) => Trans.get(key);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (MapboxTiles.accessToken.isNotEmpty) {
    try {
      MapboxOptions.setAccessToken(MapboxTiles.accessToken);
    } catch (_) {}
  }
  await Trans.loadSavedLang();
  runApp(buildVendorProviders(child: const RegaVendorApp()));
}

class RegaVendorApp extends StatefulWidget {
  const RegaVendorApp({super.key});

  @override
  State<RegaVendorApp> createState() => _RegaVendorAppState();
}

class _RegaVendorAppState extends State<RegaVendorApp> {
  GoRouter? _router;
  /// Keeps catalog/orders state alive across GoRouter shell rebuilds & tab changes.
  final GlobalKey<_MainNavigationScreenState> _shellKey =
      GlobalKey<_MainNavigationScreenState>();
  bool _isOutsideServiceArea = false;
  bool _checkingServiceArea = false;
  Timer? _serviceAreaTimer;

  @override
  void initState() {
    super.initState();
    _initServiceAreaGate();
  }

  Future<void> _initServiceAreaGate() async {
    await _refreshServiceAreaConfig();
    await _checkServiceArea(requestPermission: true);
    _serviceAreaTimer?.cancel();
    _serviceAreaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkServiceArea();
    });
  }

  Future<void> _refreshServiceAreaConfig() async {
    final data = await VendorApiService.instance.fetchSupportContacts();
    if (data.isNotEmpty) {
      ServiceAreaGate.applyFromMap(data);
    }
  }

  Future<void> _checkServiceArea({bool requestPermission = false}) async {
    if (_checkingServiceArea) return;
    _checkingServiceArea = true;
    try {
      final result =
          await ServiceAreaGate.check(requestPermission: requestPermission);
      if (!mounted) return;
      setState(() => _isOutsideServiceArea = result.blocksApp);
    } finally {
      _checkingServiceArea = false;
    }
  }

  @override
  void dispose() {
    _serviceAreaTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createVendorRouter(
      refreshListenable: context.read<VendorSessionNotifier>(),
      loginBuilder: (_) => const LoginScreen(),
      shellBuilder: (context, tabIndex) {
        final s = context.watch<VendorSessionNotifier>();
        return MainNavigationScreen(
          key: _shellKey,
          initialIndex: tabIndex,
          loginPhone: s.phone,
          loginPassword: s.password,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return const SizedBox.shrink();
    }
    if (_isOutsideServiceArea) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'NotoKufiArabic',
        ),
        home: ServiceAreaBlockedScreen(
          onRetry: () async {
            await _refreshServiceAreaConfig();
            await _checkServiceArea(requestPermission: true);
          },
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: Trans.dark,
      builder: (context, isDark, _) => ValueListenableBuilder<String>(
      valueListenable: Trans.lang,
      builder: (context, currentLang, child) {
        // Drives tx(): every on-screen string follows the selected language.
        RegaI18n.setLang(currentLang);
        RC.setDark(isDark);
        return MaterialApp.router(
          title: 'REGA Vendor',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'NotoKufiArabic',
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: 'NotoKufiArabic',
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: RC.darkPage,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF06400),
              brightness: Brightness.dark,
              primary: const Color(0xFFF06400),
              surface: RC.darkCard,
            ),
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return RegaResponsive.appBuilder(
              context,
              child,
              direction: Trans.direction,
            );
          },
        );
      },
    ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();

  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Trans.direction,
      child: Scaffold(
        backgroundColor: RC.bg(Color(0xFFF8FAFC)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: RegaResponsive.pagePadding(context),
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 430),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: RC.bg(Color(0x0C000000)),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: RC.bg(Color(0xFFF1F5F9))),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: RegaResponsive.scale(context, 26).clamp(16.0, 26.0),
                    vertical: 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Logo Badge — matches TB image 1
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: RC.bg(const Color(0xFFFF6418)),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: RC.bg(const Color(0xFFFF6418)).withOpacity(0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Center(
                          child: _TopBarLogoWidget(
                            primaryPath: kAppLogoFilePath,
                            height: 60,
                            fallbackColor: RC.bg(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Welcome Title (TB login)
                      Text(
                        t('بەخێربێیت بۆ ئەپی ڕێگا'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: RC.fg(const Color(0xFF0F172A)),
                          letterSpacing: -0.3,
                          fontFamily: kAppFontFamily,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // 3. Mobile Number Field
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_iphone_rounded, size: 17, color: RC.fg(const Color(0xFFFF6418))),
                            const SizedBox(width: 6),
                            Text(
                              t('ژمارەی مۆبایل'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: RC.fg(const Color(0xFF334155)),
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          inputFormatters: [IraqPhoneFormatter()],
                          decoration: InputDecoration(
                            hintText: txn(IraqPhoneFormatter.hint),
                            hintStyle: TextStyle(color: RC.fgn(Colors.grey[400]), fontSize: 14),
                            filled: true,
                            fillColor: RC.bg(const Color(0xFFF8FAFC)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: RC.bg(const Color(0xFFE2E8F0))),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: RC.bg(const Color(0xFFE2E8F0))),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: RC.bg(const Color(0xFFFF6418)), width: 1.6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 4. Password Field
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 17, color: RC.fg(const Color(0xFFFF6418))),
                            const SizedBox(width: 6),
                            Text(
                              t('وشەی تێپەڕ'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: RC.fg(const Color(0xFF334155)),
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: tx('••••••••'),
                          hintStyle: TextStyle(color: RC.fgn(Colors.grey[400]), fontSize: 14),
                          filled: true,
                          fillColor: RC.bg(const Color(0xFFF8FAFC)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 19,
                              color: RC.fg(const Color(0xFF94A3B8)),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFE2E8F0))),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFE2E8F0))),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFFF6418)), width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 5. Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final ok = await VendorApiService.instance.login(
                                _phoneController.text,
                                _passwordController.text,
                              );
                              if (!mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(tx('زانیاری چوونە ژوورەوە هەڵەیە'))),
                                );
                                return;
                              }
                              await context.read<VendorSessionNotifier>().login(
                                phone: _phoneController.text,
                                password: _passwordController.text,
                              );
                              if (!mounted) return;
                              context.go('/orders');
                            } on AccountBlockedException catch (e) {
                              if (!mounted) return;
                              await BlockedAccountContacts.show(context, e);
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tx('پەیوەندی سێرڤەر سەرکەوتوو نەبوو'))),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(const Color(0xFFFF6418)),
                            foregroundColor: RC.fg(Colors.white),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          child: Text(
                            t('چوونە ژوورەوە'),
                            style: TextStyle(
                              color: RC.fg(Colors.white),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              fontFamily: kAppFontFamily,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // 6. Register Section
                      Text(
                        t('هێشتا نەبوویتە فرۆشیار لە ئەپی ڕێگا'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF64748B)),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 7. Register Button — opens support WhatsApp / Telegram dialog
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () async {
                            Map<String, dynamic> contacts = const {};
                            try {
                              contacts = await VendorApiService.instance.fetchSupportContacts();
                            } catch (_) {}
                            if (!context.mounted) return;
                            await BlockedAccountContacts.showSellerRegistrationDialog(
                              context,
                              contactMap: contacts,
                              title: t('تۆمارکردنی فرۆشگای نوێ'),
                              body: t('بۆ بەشداریکردن و کردنەوەی هەژماری فرۆشیار لە ڕێگا، تکایە پەیوەندی بە تیمی پشتگیرییەوە بکە لە ڕێگەی WhatsApp یان Telegram، یان سەردانی نووسینگەمان بکە.'),
                              okLabel: t('باشە'),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: RC.bg(Color(0xFFCBD5E1)), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_outlined, color: RC.fg(Color(0xFFEA580C)), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                t('خۆت تۆمار بکە'),
                                style: TextStyle(
                                  color: RC.fg(Color(0xFFEA580C)),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Models ---
class Product {
  final String id;
  String name;
  String category;
  double price;
  double costPrice;
  double? discountPrice;
  bool isAvailable;
  String? description;
  String? imagePath;
  String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.costPrice = 0,
    this.discountPrice,
    this.isAvailable = true,
    this.description,
    this.imagePath,
    this.imageUrl,
  });
}

enum OrderStatus { pending, accepted, preparing, ready, completed, rejected }

class Order {
  final String id;
  final List<String> items;
  final double total;
  OrderStatus status;
  final DateTime timestamp;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String handoverPin;
  final String? customerNotes;
  final int? dbId;
  String? rejectReason;
  DateTime? acceptedAt;
  String? driverName;
  String? driverPhone;
  String? driverVehicle;
  double? driverLat;
  double? driverLng;
  double? storeLat;
  double? storeLng;
  double? customerLat;
  double? customerLng;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.timestamp,
    this.customerName = '',
    this.customerPhone = '',
    this.deliveryAddress = '',
    this.handoverPin = '',
    this.customerNotes,
    this.dbId,
    this.rejectReason,
    this.acceptedAt,
    this.driverName,
    this.driverPhone,
    this.driverVehicle,
    this.driverLat,
    this.driverLng,
    this.storeLat,
    this.storeLng,
    this.customerLat,
    this.customerLng,
  });
}

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final String? loginPhone;
  final String? loginPassword;
  const MainNavigationScreen({super.key, this.initialIndex = 3, this.loginPhone, this.loginPassword});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex; 
  bool _isOnline = false;
  bool _soundEnabled = true;
  String _language = 'ku';
  String _businessName = t('فرۆشگا');
  Timer? _backendPollTimer;
  final Set<int> _seenBackendOrderIds = {};
  /// Preserves UI stages (accepted vs preparing) when backend collapses both to `preparing`.
  final Map<int, OrderStatus> _localOrderStages = {};
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _language = Trans.lang.value;
    _initBackendVendorSync();
  }

  @override
  void didUpdateWidget(covariant MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex &&
        _selectedIndex != widget.initialIndex) {
      setState(() => _selectedIndex = widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _backendPollTimer?.cancel();
    super.dispose();
  }
  
  // Central Dynamic State (Synchronized 100% dynamically with PostgreSQL Backend)
  final List<String> _categories = [];
  final Map<String, String> _categoryImages = {};
  final List<Product> _products = [];
  final List<Order> _orders = [];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    context.read<VendorNavNotifier>().setTabIndex(index);
    context.go(VendorNavNotifier.pathForIndex(index));
  }

  OrderStatus _mapBackendVendorStatus(String raw) {
    switch (raw) {
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
      case 'picked_up':
      case 'on_the_way':
      case 'delivered':
        return OrderStatus.completed;
      case 'rejected':
      case 'cancelled':
        return OrderStatus.rejected;
      default:
        return OrderStatus.pending;
    }
  }

  OrderStatus _resolveSyncedStatus(int? dbId, String raw) {
    final backend = _mapBackendVendorStatus(raw);
    if (dbId == null) return backend;

    if (backend == OrderStatus.ready ||
        backend == OrderStatus.completed ||
        backend == OrderStatus.rejected ||
        backend == OrderStatus.pending) {
      _localOrderStages.remove(dbId);
      return backend;
    }

    final local = _localOrderStages[dbId];
    if (backend == OrderStatus.preparing) {
      if (local == OrderStatus.accepted || local == OrderStatus.preparing) {
        return local!;
      }
      // Fresh from server after accept elsewhere → treat as preparing.
      return OrderStatus.preparing;
    }
    return backend;
  }

  void _rememberLocalStage(int? dbId, OrderStatus status) {
    if (dbId == null) return;
    if (status == OrderStatus.accepted || status == OrderStatus.preparing) {
      _localOrderStages[dbId] = status;
    } else {
      _localOrderStages.remove(dbId);
    }
  }

  void _simulateNewOrder() {
    final demo = Order(
      id: 'T-${DateTime.now().millisecondsSinceEpoch % 100000}#',
      items: const ['2x پیتزا پێپەرۆنی'],
      total: 16800,
      status: OrderStatus.pending,
      timestamp: DateTime.now(),
      customerName: 'بەڵێن قادر',
      customerPhone: '07718829911',
      deliveryAddress: 'گەڕەکی کەلاری کۆن - شەقامی سەرەکی، کۆڵانی بەرامبەر',
      driverName: 'کاروان محەمەد',
    );
    setState(() {
      _orders.insert(0, demo);
      _selectedIndex = 3;
    });
    context.read<VendorNavNotifier>().setTabIndex(3);
    if (_soundEnabled) {
      OrderSoundService.playNewOrderAlert(soundEnabled: true);
    }
  }

  void _deleteOrderById(String id) {
    setState(() => _orders.removeWhere((o) => o.id == id));
  }

  void _clearCompletedOrders() {
    setState(() => _orders.removeWhere((o) => o.status == OrderStatus.completed));
  }

  Future<void> _initBackendVendorSync({bool forceRelogin = false}) async {
    try {
      final needsLogin = forceRelogin || !VendorApiService.instance.isAuthenticated;
      if (needsLogin &&
          widget.loginPhone != null &&
          widget.loginPhone!.trim().isNotEmpty &&
          widget.loginPassword != null &&
          widget.loginPassword!.trim().length >= 6) {
        try {
          await VendorApiService.instance.login(
            widget.loginPhone!,
            widget.loginPassword!,
          );
        } on AccountBlockedException catch (e) {
          if (!mounted) return;
          await BlockedAccountContacts.show(context, e);
          if (!mounted) return;
          await context.read<VendorSessionNotifier>().logout();
          if (!mounted) return;
          context.go('/login');
          return;
        }
      } else {
        await VendorApiService.instance.ensureAuthenticated();
      }

      if (!VendorApiService.instance.isAuthenticated) {
        debugPrint('Vendor backend sync skipped: not authenticated');
        return;
      }

      final store = await VendorApiService.instance.fetchStoreProfile();
      final cats = await VendorApiService.instance.fetchCategories();
      final prods = await VendorApiService.instance.fetchProducts();
      await _syncVendorOrdersOnly(initialLoad: true);

      if (!mounted) return;
      setState(() {
        if (store != null) {
          _businessName = store['name_ku']?.toString() ?? _businessName;
          _isOnline = store['is_online'] == true;
        }
        // Replace catalog only when the API succeeded (non-null). Empty list is valid.
        if (cats != null) {
          _categories.clear();
          _categoryImages.clear();
          for (final raw in cats) {
            final c = raw as Map<String, dynamic>;
            final name = c['name_ku']?.toString() ?? '';
            if (name.isEmpty) continue;
            _categories.add(name);
            final img = VendorApiService.instance.resolveMediaUrl(c['image_url']?.toString());
            if (img.isNotEmpty) _categoryImages[name] = img;
          }
        }
        if (prods != null) {
          _products
            ..clear()
            ..addAll(prods.map((raw) {
              final p = raw as Map<String, dynamic>;
              return Product(
                id: '${p['id']}',
                name: p['name_ku']?.toString() ?? '',
                category: p['store_category']?['name_ku']?.toString() ??
                    (_categories.isNotEmpty ? _categories.first : 'گشتی'),
                price: ((p['price'] as num?) ?? 0).toDouble(),
                costPrice: ((p['cost_price'] as num?) ?? 0).toDouble(),
                discountPrice: (p['discount_price'] as num?)?.toDouble(),
                isAvailable: p['is_available'] == true,
                description: p['description_ku']?.toString(),
                imageUrl: () {
                  final u = VendorApiService.instance.resolveMediaUrl(p['image_url']?.toString());
                  return u.isEmpty ? null : u;
                }(),
              );
            }));
        }
      });

      _backendPollTimer?.cancel();
      _backendPollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _syncVendorOrdersOnly(initialLoad: false),
      );
    } catch (e) {
      debugPrint('Vendor backend sync fallback: $e');
    }
  }

  Future<void> _syncVendorOrdersOnly({required bool initialLoad}) async {
    try {
      final list = await VendorApiService.instance.fetchOrders();
      if (!mounted) return;
      // Empty list is valid (no orders) — still clear backend-synced rows.
      if (list.isEmpty) {
        setState(() {
          final localOnly = _orders.where((o) => o.dbId == null).toList();
          _orders
            ..clear()
            ..addAll(localOnly);
        });
        return;
      }

      bool hasBrandNewPending = false;
      final parsed = <Order>[];

      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final dbId = (m['id'] as num?)?.toInt();
        final vStatus = m['vendor_status']?.toString() ?? m['status']?.toString() ?? 'pending';
        if (dbId != null && !_seenBackendOrderIds.contains(dbId)) {
          _seenBackendOrderIds.add(dbId);
          if (!initialLoad && vStatus == 'pending') {
            hasBrandNewPending = true;
          }
        }

        final itemsList = (m['items'] as List<dynamic>? ?? [])
            .map((it) {
              final im = it as Map<String, dynamic>;
              return '${im['quantity'] ?? 1}x ${im['product_name'] ?? ''}';
            })
            .toList();

        final resolved = _resolveSyncedStatus(dbId, vStatus);
        final acceptedAt = DateTime.tryParse(m['accepted_at']?.toString() ?? '')?.toLocal() ??
            (resolved == OrderStatus.accepted || resolved == OrderStatus.preparing
                ? DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal()
                : null);

        parsed.add(
          Order(
            id: '${m['order_number'] ?? 'RA-$dbId'}#',
            dbId: dbId,
            items: itemsList.isEmpty ? ['1x داواکاری'] : itemsList,
            total: ((m['subtotal'] ?? m['total_amount'] ?? 0) as num).toDouble(),
            status: resolved,
            timestamp: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
            acceptedAt: acceptedAt,
            customerName: m['customer_name']?.toString() ?? m['customer']?['name']?.toString() ?? 'کڕیار',
            customerPhone: m['customer_phone']?.toString() ?? m['customer']?['phone']?.toString() ?? '',
            deliveryAddress: m['delivery_address']?.toString() ?? '',
            handoverPin: m['handover_pin']?.toString() ?? '',
            customerNotes: m['customer_notes']?.toString(),
            driverName: m['driver']?['name']?.toString(),
            driverPhone: m['driver']?['phone']?.toString(),
            driverVehicle: m['driver']?['driver_profile']?['plate_number']?.toString() ??
                m['driver']?['driver_profile']?['motor_type']?.toString(),
            driverLat: (m['driver_lat'] as num?)?.toDouble() ??
                (m['driver']?['lat'] as num?)?.toDouble() ??
                (m['driver']?['current_lat'] as num?)?.toDouble(),
            driverLng: (m['driver_lng'] as num?)?.toDouble() ??
                (m['driver']?['lng'] as num?)?.toDouble() ??
                (m['driver']?['current_lng'] as num?)?.toDouble(),
            storeLat: (m['store_lat'] as num?)?.toDouble(),
            storeLng: (m['store_lng'] as num?)?.toDouble(),
            customerLat: (m['customer_lat'] as num?)?.toDouble() ?? (m['delivery_lat'] as num?)?.toDouble(),
            customerLng: (m['customer_lng'] as num?)?.toDouble() ?? (m['delivery_lng'] as num?)?.toDouble(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        final localOnly = _orders.where((o) => o.dbId == null).toList();
        _orders
          ..clear()
          ..addAll(parsed)
          ..addAll(localOnly);
      });

      if (hasBrandNewPending && _soundEnabled) {
        OrderSoundService.playNewOrderAlert(soundEnabled: _soundEnabled);
      }
    } catch (_) {}
  }

  void _legacyUnusedHook(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleProductAvailability(String id) {
    final product = _products.firstWhere((p) => p.id == id);
    final previous = product.isAvailable;
    setState(() => product.isAvailable = !previous);
    final pid = int.tryParse(id);
    if (pid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('دۆخی بەرهەم نوێکرایەوە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(const Color(0xFF00894C)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    VendorApiService.instance.toggleProductAvailability(pid).then((res) {
      if (!mounted) return;
      final (ok, msg) = res;
      if (!ok) {
        setState(() => product.isAvailable = previous);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(msg), textAlign: TextAlign.center),
          backgroundColor: ok ? RC.bg(const Color(0xFF00894C)) : RC.bg(const Color(0xFFE50010)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _deleteProduct(String id) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final removed = _products[index];
    setState(() => _products.removeAt(index));
    final pid = int.tryParse(id);
    if (pid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('بەرهەم سڕایەوە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(const Color(0xFF00894C)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    VendorApiService.instance.deleteProduct(pid).then((res) {
      if (!mounted) return;
      final (ok, msg) = res;
      if (!ok) {
        setState(() {
          if (index <= _products.length) {
            _products.insert(index, removed);
          } else {
            _products.add(removed);
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(msg), textAlign: TextAlign.center),
          backgroundColor: ok ? RC.bg(const Color(0xFF00894C)) : RC.bg(const Color(0xFFE50010)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _updateOrderStatus(String id, OrderStatus newStatus, {String? reason}) {
    final order = _orders.firstWhere((o) => o.id == id);
    final dbId = order.dbId;

    if (newStatus == OrderStatus.completed && dbId != null) {
      VendorApiService.instance.handoverToDriver(dbId).then((res) {
        if (!mounted) return;
        final (ok, msg) = res;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(msg)),
            backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFE50010)),
          ),
        );
        if (ok) {
          setState(() {
            order.status = OrderStatus.completed;
            _rememberLocalStage(dbId, OrderStatus.completed);
          });
          _syncVendorOrdersOnly(initialLoad: false);
        }
      });
      return;
    }

    // Local-only demo orders (no dbId) update immediately.
    if (dbId == null) {
      setState(() {
        order.status = newStatus;
        if (newStatus == OrderStatus.accepted) {
          order.acceptedAt ??= DateTime.now();
        }
        if (newStatus == OrderStatus.rejected && reason != null && reason.trim().isNotEmpty) {
          order.rejectReason = reason.trim();
        }
      });
      return;
    }

    if (newStatus == OrderStatus.accepted) {
      VendorApiService.instance.acceptOrder(dbId).then((ok) {
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tx('قبوڵکردنی داواکاری سەرکەوتوو نەبوو')),
              backgroundColor: RC.bg(Color(0xFFE50010)),
            ),
          );
          return;
        }
        setState(() {
          order.status = OrderStatus.accepted;
          order.acceptedAt ??= DateTime.now();
          _rememberLocalStage(dbId, OrderStatus.accepted);
        });
      });
      return;
    }

    if (newStatus == OrderStatus.preparing) {
      // Backend already set preparing on accept; advance local UI stage only.
      setState(() {
        order.status = OrderStatus.preparing;
        order.acceptedAt ??= DateTime.now();
        _rememberLocalStage(dbId, OrderStatus.preparing);
      });
      return;
    }

    if (newStatus == OrderStatus.ready) {
      VendorApiService.instance.markReady(dbId).then((res) {
        final (ok, msg, data) = res;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tx(msg)),
            backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFEA580C)),
            duration: const Duration(seconds: 4),
          ),
        );
        if (ok) {
          setState(() {
            order.status = OrderStatus.ready;
            _rememberLocalStage(dbId, OrderStatus.ready);
          });
          _syncVendorOrdersOnly(initialLoad: false);
        }
      });
      return;
    }

    if (newStatus == OrderStatus.rejected) {
      VendorApiService.instance.rejectOrder(dbId, reason: reason).then((ok) {
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tx('ڕەتکردنەوە سەرکەوتوو نەبوو')),
              backgroundColor: RC.bg(Color(0xFFE50010)),
            ),
          );
          return;
        }
        setState(() {
          order.status = OrderStatus.rejected;
          if (reason != null && reason.trim().isNotEmpty) {
            order.rejectReason = reason.trim();
          }
          _rememberLocalStage(dbId, OrderStatus.rejected);
        });
        _syncVendorOrdersOnly(initialLoad: false);
      });
      return;
    }

    setState(() {
      order.status = newStatus;
      _rememberLocalStage(dbId, newStatus);
    });
  }

  Future<void> _addProduct(Product product) async {
    setState(() => _products.add(product));
    final saved = await VendorApiService.instance.addProduct(
      nameKu: product.name,
      categoryName: product.category,
      price: product.price.round(),
      costPrice: product.costPrice.round(),
      discountPrice: product.discountPrice?.round(),
      descriptionKu: product.description,
      imageUrl: product.imageUrl,
      isAvailable: product.isAvailable,
    );
    if (!mounted) return;
    if (saved == null) {
      setState(() => _products.removeWhere((p) => p.id == product.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('پاشەکەوتکردنی بەرهەم سەرکەوتوو نەبوو — تکایە دووبارە هەوڵ بدە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(Color(0xFFE50010)),
        ),
      );
      return;
    }
    // Reload from server so local IDs/images match persisted rows after leave/logout.
    await _initBackendVendorSync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx('بەرهەم پاشەکەوت کرا'), textAlign: TextAlign.center),
        backgroundColor: RC.bg(Color(0xFF00894C)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addCategory(String category, {String? imageUrl}) async {
    if (_categories.contains(category)) return;
    final localImg = (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null;
    setState(() {
      _categories.add(category);
      if (localImg != null) {
        _categoryImages[category] = localImg;
      }
    });
    final id = await VendorApiService.instance.addCategory(category, imageUrl: localImg);
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _categories.remove(category);
        _categoryImages.remove(category);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('پاشەکەوتکردنی بەش سەرکەوتوو نەبوو — تکایە دووبارە هەوڵ بدە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(Color(0xFFE50010)),
        ),
      );
      return;
    }
    await _initBackendVendorSync();
    if (!mounted) return;
    // Keep the chosen image if sync returned the category without image_url yet.
    if (localImg != null) {
      final synced = _categoryImages[category];
      if (synced == null || synced.isEmpty) {
        setState(() => _categoryImages[category] = localImg);
      }
    }
  }

  Future<void> _updateCategory(String oldName, String newName, {String? imageUrl}) async {
    final (ok, msg) = await VendorApiService.instance.updateCategory(
      oldNameKu: oldName,
      newNameKu: newName,
      imageUrl: imageUrl,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(msg), textAlign: TextAlign.center),
          backgroundColor: RC.bg(const Color(0xFFE50010)),
        ),
      );
      return;
    }
    setState(() {
      final idx = _categories.indexOf(oldName);
      if (idx != -1) _categories[idx] = newName;
      final prevImg = _categoryImages.remove(oldName);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        _categoryImages[newName] = imageUrl;
      } else if (prevImg != null) {
        _categoryImages[newName] = prevImg;
      }
      for (final p in _products) {
        if (p.category.trim() == oldName.trim()) p.category = newName;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx('بەش نوێکرایەوە'), textAlign: TextAlign.center),
        backgroundColor: RC.bg(const Color(0xFF00894C)),
      ),
    );
  }

  void _deleteCategory(String category) {
    setState(() {
      _categories.remove(category);
      _categoryImages.remove(category);
      VendorApiService.instance.deleteCategoryByName(category);
    });
  }

  void _editProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) return;
    final previous = _products[index];
    setState(() => _products[index] = product);
    final pid = int.tryParse(product.id);
    if (pid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx('بەرهەم نوێکرایەوە'), textAlign: TextAlign.center),
          backgroundColor: RC.bg(const Color(0xFF00894C)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    VendorApiService.instance
        .updateProduct(
          productId: pid,
          nameKu: product.name,
          categoryName: product.category,
          price: product.price.round(),
          costPrice: product.costPrice.round(),
          discountPrice: product.discountPrice?.round(),
          descriptionKu: product.description,
          imageUrl: product.imageUrl,
          isAvailable: product.isAvailable,
        )
        .then((res) {
      if (!mounted) return;
      final (ok, msg) = res;
      if (!ok) {
        setState(() => _products[index] = previous);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(msg), textAlign: TextAlign.center),
          backgroundColor: ok ? RC.bg(const Color(0xFF00894C)) : RC.bg(const Color(0xFFE50010)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> _applyStoreWideDiscount(int percent) async {
    final (ok, msg) = await VendorApiService.instance.applyStoreDiscount(percent);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tx(msg), textAlign: TextAlign.center),
        backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFE50010)),
      ),
    );
    if (ok) {
      await _initBackendVendorSync();
    }
  }

  /// Semi-transparent rounded glass icon button used in the orange top bar.
  Widget _buildHeaderGlassIcon({
    required Widget child,
    required VoidCallback onTap,
    double size = 42,
    double radius = 14,
    double borderAlpha = 0.44,
    bool dimmed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dimmed ? 0.10 : 0.18),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: dimmed ? 0.22 : borderAlpha),
            width: 1.25,
          ),
        ),
        child: Opacity(opacity: dimmed ? 0.72 : 1, child: child),
      ),
    );
  }

  /// Recessed capsule toggle switch: emerald-teal ON / muted OFF with white thumb.
  Widget _buildOnlineOfflineSwitch() {
    const onEmerald = Color(0xFF0FB884);
    // Keep LTR so thumb position matches the header design regardless of app RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        button: true,
        toggled: _isOnline,
        label: _isOnline ? t('فرۆشگا کراوەیە') : t('فرۆشگا داخراوە'),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _isOnline = !_isOnline;
              VendorApiService.instance.updateOnlineStatus(_isOnline);
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 56,
            height: 34,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.1,
              ),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: _isOnline
                    ? onEmerald
                    : Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SettingsScreen(
        businessName: _businessName,
        onNameChange: (val) {
          setState(() => _businessName = val);
          VendorApiService.instance.updateStoreInfo(nameKu: val);
        },
        language: Trans.lang.value,
        onLangChange: (val) { Trans.setLang(val); setState(() => _language = val); },
      ),
      RevenueScreen(
        orders: _orders,
        onRefresh: () => _syncVendorOrdersOnly(initialLoad: false),
      ),
      ProductsMenuScreen(
        products: _products,
        categories: _categories,
        categoryImages: _categoryImages,
        onToggle: _toggleProductAvailability,
        onDelete: _deleteProduct,
        onAdd: _addProduct,
        onEdit: _editProduct,
        onAddCategory: _addCategory,
        onDeleteCategory: _deleteCategory,
        onUpdateCategory: _updateCategory,
      ),
      OrdersScreen(
        orders: _orders,
        onUpdateStatus: _updateOrderStatus,
        onOrdersChanged: () => _syncVendorOrdersOnly(initialLoad: false),
        onSimulateNewOrder: _simulateNewOrder,
        onDeleteOrder: _deleteOrderById,
        onClearCompletedOrders: _clearCompletedOrders,
      ),
    ];

    bool isRtl = _language != 'en';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: RC.bg(const Color(0xFFF6F7F9)),
        // Orange REGA top bar — matches vendor header reference design.
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.light,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: 80,
            titleSpacing: 14,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFEA580D),
                    Color(0xFFE46509),
                    Color(0xFFDE7507),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            title: SizedBox(
              width: double.infinity,
              height: 58,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  // Match reference: [switch] [sound]  ... [REGA logo centered] ...  [فرۆشگا] [store+dot]
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildOnlineOfflineSwitch(),
                              const SizedBox(width: 8),
                              _buildHeaderGlassIcon(
                                size: 42,
                                radius: 13.5,
                                borderAlpha: 0.42,
                                onTap: () {
                                  setState(() => _soundEnabled = !_soundEnabled);
                                  if (_soundEnabled) OrderSoundService.playTestTone();
                                },
                                child: CustomPaint(
                                  size: const Size(21, 21),
                                  painter: _HeaderVolumePainter(
                                    color: Colors.white,
                                    muted: !_soundEnabled,
                                  ),
                                ),
                                dimmed: !_soundEnabled,
                              ),
                            ],
                          ),
                        ),
                        Center(child: _buildTopLogo()),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 115),
                                child: Text(
                                  t('فرۆشگا'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: kAppFontFamily,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _buildHeaderGlassIcon(
                                    size: 46,
                                    radius: 14.5,
                                    borderAlpha: 0.48,
                                    onTap: () => _onItemTapped(0),
                                    child: CustomPaint(
                                      size: const Size(23, 23),
                                      painter: _HeaderStorePainter(color: Colors.white),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -1,
                                    right: -1,
                                    child: Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                        color: _isOnline
                                            ? const Color(0xFF0FB884)
                                            : const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFDE7507),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
        ),
        bottomNavigationBar: _buildResponsiveBottomNav(context),
      ),
    );
  }

  /// Fully responsive bottom navigation bar across compact phones, phones,
  /// landscape mode, tablets/iPads, and desktop browsers.
  Widget _buildResponsiveBottomNav(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final compactH = RegaResponsive.isCompactHeight(context);
    final isSmallPhone = screenW < 360;
    final isTablet = screenW >= RegaBreakpoints.phone && screenW < RegaBreakpoints.desktop;
    final isDesktop = screenW >= RegaBreakpoints.desktop;

    final double maxBarWidth = isDesktop
        ? 860
        : isTablet
            ? 740
            : double.infinity;
    final double hPad = isSmallPhone
        ? 4
        : isDesktop
            ? 24
            : isTablet
                ? 16
                : 8;
    final double bottomPad = compactH ? 4 : 8;

    return Container(
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        border: Border(
          top: BorderSide(
            color: RC.bg(const Color(0xFFF1F3F7)),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBarWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, bottomPad),
              // Match reference navbar (RTL): داواکارییەکان | مێنۆ | داهات | ڕێکخستن
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(
                    context,
                    3,
                    t('داواکارییەکان'),
                    kind: _NavIconKind.bag,
                    hasNotification: true,
                  ),
                  _buildNavItem(
                    context,
                    2,
                    t('مێنۆ'),
                    kind: _NavIconKind.utensils,
                  ),
                  _buildNavItem(
                    context,
                    1,
                    t('داهات'),
                    kind: _NavIconKind.chart,
                  ),
                  _buildNavItem(
                    context,
                    0,
                    t('ڕێکخستن'),
                    kind: _NavIconKind.sliders,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom nav item — matches reference (bag / crossed utensils / chart / sliders).
  Widget _buildNavItem(
    BuildContext context,
    int index,
    String label, {
    required _NavIconKind kind,
    bool hasNotification = false,
  }) {
    final screenW = MediaQuery.sizeOf(context).width;
    final compactH = RegaResponsive.isCompactHeight(context);
    final isSmallPhone = screenW < 360;
    final isWide = screenW >= RegaBreakpoints.phone;

    final bool isSelected = _selectedIndex == index;
    const primeOrange = Color(0xFFEB6316);
    const softPeach = Color(0xFFFFF1E9);
    const idleGray = Color(0xFF8A929E);
    final Color accent = RC.fg(isSelected ? primeOrange : idleGray);

    final double pillW = isSmallPhone ? 48 : (isWide ? 60 : 54);
    final double pillH = compactH ? 28 : (isSmallPhone ? 31 : (isWide ? 36 : 34));
    final double iconSize = compactH ? 20 : (isSmallPhone ? 21 : (isWide ? 24 : 23));
    final double fontSize = compactH ? 10.5 : (isSmallPhone ? 10.5 : (isWide ? 12.5 : 12.0));
    final double indicatorW = isSmallPhone ? 24 : (isWide ? 32 : 28);

    final pendingCount = _orders.where((o) => o.status == OrderStatus.pending).length;
    final bool showBadge = hasNotification && pendingCount > 0;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _onItemTapped(index);
          },
          splashColor: primeOrange.withValues(alpha: 0.08),
          hoverColor: primeOrange.withValues(alpha: 0.04),
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top active indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? indicatorW : 0,
                  height: 3.0,
                  margin: EdgeInsets.only(bottom: compactH ? 3 : 5),
                  decoration: BoxDecoration(
                    color: isSelected ? primeOrange : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Icon capsule + notification badge
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: pillW,
                      height: pillH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? RC.bg(softPeach) : Colors.transparent,
                        borderRadius: BorderRadius.circular(pillH / 2),
                      ),
                      child: CustomPaint(
                        size: Size(iconSize, iconSize),
                        painter: _VendorNavIconPainter(kind: kind, color: accent),
                      ),
                    ),
                    if (showBadge)
                      Positioned(
                        top: -6,
                        left: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                          decoration: BoxDecoration(
                            color: primeOrange,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: RC.bg(Colors.white), width: 1.8),
                          ),
                          constraints: BoxConstraints(
                            minWidth: isSmallPhone ? 18 : 20,
                            minHeight: isSmallPhone ? 18 : 20,
                          ),
                          child: Center(
                            child: Text(
                              tx(pendingCount > 99 ? '99+' : '$pendingCount'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallPhone ? 9.5 : 10.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compactH ? 2 : 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tx(label),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: fontSize,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.1,
                      height: 1.15,
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ============================================================================
  // 📌 ویجێتی لۆگۆی سەرەوە (بە شێوازی زیرەکانە و فرە-قۆناغ فایلی لۆکاڵ و ئاسێت دەدۆزێتەوە)
  // ============================================================================
  Widget _buildTopLogo() {
    return const IgnorePointer(
      child: _TopBarLogoWidget(
        primaryPath: kAppLogoFilePath,
        height: 48,
      ),
    );
  }
}

enum _TbInfoIcon { person, phone, pin, driver }

class _TbInfoIconPainter extends CustomPainter {
  final _TbInfoIcon kind;
  final Color color;
  _TbInfoIconPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case _TbInfoIcon.person:
        canvas.drawCircle(Offset(w * 0.5, h * 0.32), w * 0.18, paint);
        canvas.drawArc(
          Rect.fromLTRB(w * 0.18, h * 0.52, w * 0.82, h * 1.05),
          3.4,
          2.5,
          false,
          paint,
        );
      case _TbInfoIcon.phone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(w * 0.30, h * 0.10, w * 0.70, h * 0.90),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawLine(Offset(w * 0.40, h * 0.78), Offset(w * 0.60, h * 0.78), paint);
      case _TbInfoIcon.pin:
        canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.16, paint);
        final pin = Path()
          ..moveTo(w * 0.22, h * 0.40)
          ..quadraticBezierTo(w * 0.22, h * 0.18, w * 0.50, h * 0.12)
          ..quadraticBezierTo(w * 0.78, h * 0.18, w * 0.78, h * 0.40)
          ..quadraticBezierTo(w * 0.78, h * 0.62, w * 0.50, h * 0.92)
          ..quadraticBezierTo(w * 0.22, h * 0.62, w * 0.22, h * 0.40);
        canvas.drawPath(pin, paint);
      case _TbInfoIcon.driver:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.36, paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.14, paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.14), Offset(w * 0.5, h * 0.30), paint);
        canvas.drawLine(Offset(w * 0.20, h * 0.68), Offset(w * 0.34, h * 0.58), paint);
        canvas.drawLine(Offset(w * 0.80, h * 0.68), Offset(w * 0.66, h * 0.58), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TbInfoIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

class _ChatBubblePainter extends CustomPainter {
  final Color color;
  _ChatBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.08, h * 0.08, w * 0.92, h * 0.68),
      const Radius.circular(4),
    );
    canvas.drawRRect(bubble, paint);
    final tail = Path()
      ..moveTo(w * 0.28, h * 0.68)
      ..lineTo(w * 0.22, h * 0.92)
      ..lineTo(w * 0.48, h * 0.68);
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _ChatBubblePainter oldDelegate) => oldDelegate.color != color;
}

class _FlameIconPainter extends CustomPainter {
  final Color color;
  _FlameIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final flame = Path()
      ..moveTo(w * 0.50, h * 0.08)
      ..cubicTo(w * 0.78, h * 0.32, w * 0.88, h * 0.55, w * 0.70, h * 0.78)
      ..cubicTo(w * 0.62, h * 0.90, w * 0.38, h * 0.90, w * 0.30, h * 0.78)
      ..cubicTo(w * 0.12, h * 0.55, w * 0.22, h * 0.32, w * 0.50, h * 0.08);
    canvas.drawPath(flame, paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.68), width: w * 0.28, height: h * 0.28),
      3.5,
      2.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FlameIconPainter oldDelegate) => oldDelegate.color != color;
}

/// Bottom-nav icon kinds (drawn, not Material font — some glyphs blank on web).
enum _NavIconKind { bag, utensils, chart, sliders }

class _VendorNavIconPainter extends CustomPainter {
  final _NavIconKind kind;
  final Color color;

  _VendorNavIconPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case _NavIconKind.bag:
        _paintBag(canvas, paint);
      case _NavIconKind.utensils:
        _paintUtensils(canvas, paint);
      case _NavIconKind.chart:
        _paintChart(canvas, paint);
      case _NavIconKind.sliders:
        _paintSliders(canvas, paint);
    }

    canvas.restore();
  }

  void _paintBag(Canvas canvas, Paint paint) {
    // Retail/takeaway folded-top shopping bag with inner U-handle (Lucide shopping-bag)
    final bag = Path()
      ..moveTo(6.2, 3.2)
      ..lineTo(17.8, 3.2)
      ..lineTo(20.0, 7.0)
      ..lineTo(20.0, 18.4)
      ..quadraticBezierTo(20.0, 20.8, 17.6, 20.8)
      ..lineTo(6.4, 20.8)
      ..quadraticBezierTo(4.0, 20.8, 4.0, 18.4)
      ..lineTo(4.0, 7.0)
      ..close();
    canvas.drawPath(bag, paint);
    // Top fold crease
    canvas.drawLine(const Offset(4.2, 7.0), const Offset(19.8, 7.0), paint);
    // Inner hanging U-handle
    canvas.drawArc(
      const Rect.fromLTRB(8.6, 7.2, 15.4, 14.2),
      0,
      math.pi,
      false,
      paint,
    );
  }

  void _paintUtensils(Canvas canvas, Paint paint) {
    // Crossed fork (top-right -> bottom-left) & hollow knife blade (top-left -> bottom-right)
    // 1. Fork head at top-right (3 tines + curved cup)
    final forkCup = Path()
      ..moveTo(16.0, 2.6)
      ..lineTo(13.6, 5.0)
      ..cubicTo(12.3, 6.3, 12.3, 8.3, 13.6, 9.6)
      ..cubicTo(14.9, 10.9, 16.9, 10.9, 18.2, 9.6)
      ..lineTo(20.6, 7.2);
    canvas.drawPath(forkCup, paint);
    // Middle tine + upper fork neck
    canvas.drawLine(const Offset(18.3, 4.9), const Offset(12.2, 11.0), paint);
    // Lower fork handle (continues cleanly past knife to bottom-left)
    canvas.drawLine(const Offset(9.2, 14.0), const Offset(3.4, 19.8), paint);

    // 2. Knife: straight spine from top-left to bottom-right + curved blade belly
    canvas.drawLine(const Offset(4.0, 3.4), const Offset(20.4, 19.8), paint);
    final blade = Path()
      ..moveTo(4.0, 3.4)
      ..cubicTo(2.6, 6.2, 3.8, 9.8, 8.6, 13.8)
      ..lineTo(11.3, 10.7);
    canvas.drawPath(blade, paint);
  }

  void _paintChart(Canvas canvas, Paint paint) {
    // L-shaped chart axis + 3 vertical bars (short, tall, medium)
    final axis = Path()
      ..moveTo(3.5, 3.5)
      ..lineTo(3.5, 18.0)
      ..quadraticBezierTo(3.5, 20.5, 6.0, 20.5)
      ..lineTo(20.5, 20.5);
    canvas.drawPath(axis, paint);

    canvas.drawLine(const Offset(8.5, 13.5), const Offset(8.5, 16.8), paint);
    canvas.drawLine(const Offset(13.2, 7.0), const Offset(13.2, 16.8), paint);
    canvas.drawLine(const Offset(17.9, 10.2), const Offset(17.9, 16.8), paint);
  }

  void _paintSliders(Canvas canvas, Paint paint) {
    // Three split horizontal slider tracks with vertical tick knobs
    // Row 1 (tick at x = 13.5)
    canvas.drawLine(const Offset(3.5, 5.5), const Offset(10.2, 5.5), paint);
    canvas.drawLine(const Offset(13.5, 5.5), const Offset(20.5, 5.5), paint);
    canvas.drawLine(const Offset(13.5, 3.3), const Offset(13.5, 7.7), paint);

    // Row 2 (tick at x = 8.8)
    canvas.drawLine(const Offset(3.5, 12.0), const Offset(8.8, 12.0), paint);
    canvas.drawLine(const Offset(12.1, 12.0), const Offset(20.5, 12.0), paint);
    canvas.drawLine(const Offset(8.8, 9.8), const Offset(8.8, 14.2), paint);

    // Row 3 (tick at x = 15.2)
    canvas.drawLine(const Offset(3.5, 18.5), const Offset(11.9, 18.5), paint);
    canvas.drawLine(const Offset(15.2, 18.5), const Offset(20.5, 18.5), paint);
    canvas.drawLine(const Offset(15.2, 16.3), const Offset(15.2, 20.7), paint);
  }

  @override
  bool shouldRepaint(covariant _VendorNavIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

class _HeaderBellPainter extends CustomPainter {
  final Color color;
  _HeaderBellPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    canvas.save();
    canvas.scale(sx, sy);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top finial + solid bell dome + flared rim (Material notifications_active shape)
    final bell = Path()
      ..moveTo(12.0, 2.2)
      ..cubicTo(12.9, 2.2, 13.6, 2.9, 13.6, 3.8)
      ..lineTo(13.6, 4.3)
      ..cubicTo(16.4, 5.0, 18.0, 7.5, 18.0, 10.8)
      ..lineTo(18.0, 15.2)
      ..lineTo(20.0, 17.2)
      ..lineTo(20.0, 18.2)
      ..lineTo(4.0, 18.2)
      ..lineTo(4.0, 17.2)
      ..lineTo(6.0, 15.2)
      ..lineTo(6.0, 10.8)
      ..cubicTo(6.0, 7.5, 7.6, 5.0, 10.4, 4.3)
      ..lineTo(10.4, 3.8)
      ..cubicTo(10.4, 2.9, 11.1, 2.2, 12.0, 2.2)
      ..close();
    canvas.drawPath(bell, fillPaint);

    // Bottom clapper semicircle
    final clapper = Path()
      ..addArc(
        Rect.fromCenter(center: const Offset(12.0, 19.2), width: 4.0, height: 4.0),
        0,
        math.pi,
      )
      ..close();
    canvas.drawPath(clapper, fillPaint);

    // Curved ringing arcs on upper-left and upper-right shoulders
    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final waveRect = Rect.fromCenter(
      center: const Offset(12.0, 11.0),
      width: 18.4,
      height: 18.4,
    );
    canvas.drawArc(waveRect, -2.76, 0.72, false, wavePaint);
    canvas.drawArc(waveRect, -1.10, 0.72, false, wavePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeaderBellPainter oldDelegate) => oldDelegate.color != color;
}

class _HeaderVolumePainter extends CustomPainter {
  final Color color;
  final bool muted;
  _HeaderVolumePainter({required this.color, this.muted = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final body = Path()
      ..moveTo(w * 0.14, h * 0.38)
      ..lineTo(w * 0.30, h * 0.38)
      ..lineTo(w * 0.52, h * 0.20)
      ..lineTo(w * 0.52, h * 0.80)
      ..lineTo(w * 0.30, h * 0.62)
      ..lineTo(w * 0.14, h * 0.62)
      ..close();
    canvas.drawPath(body, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Soften speaker corners slightly
    canvas.drawPath(body, strokePaint..strokeWidth = 1.4);
    strokePaint.strokeWidth = 2.0;

    if (!muted) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.54, h * 0.50), width: w * 0.38, height: h * 0.38),
        -0.72,
        1.44,
        false,
        strokePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.54, h * 0.50), width: w * 0.68, height: h * 0.68),
        -0.78,
        1.56,
        false,
        strokePaint,
      );
    } else {
      canvas.drawLine(Offset(w * 0.62, h * 0.32), Offset(w * 0.88, h * 0.68), strokePaint);
      canvas.drawLine(Offset(w * 0.88, h * 0.32), Offset(w * 0.62, h * 0.68), strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderVolumePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.muted != muted;
}

class _HeaderStorePainter extends CustomPainter {
  final Color color;
  _HeaderStorePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;

    // Awning top & slanted outer sides
    final roofTop = Path()
      ..moveTo(w * 0.10, h * 0.43)
      ..lineTo(w * 0.17, h * 0.18)
      ..lineTo(w * 0.83, h * 0.18)
      ..lineTo(w * 0.90, h * 0.43);
    canvas.drawPath(roofTop, paint);

    // Three vertical awning stripes dividing into 4 panels
    canvas.drawLine(Offset(w * 0.335, h * 0.18), Offset(w * 0.30, h * 0.43), paint);
    canvas.drawLine(Offset(w * 0.50, h * 0.18), Offset(w * 0.50, h * 0.43), paint);
    canvas.drawLine(Offset(w * 0.665, h * 0.18), Offset(w * 0.70, h * 0.43), paint);

    // Four scalloped bottom arches along awning
    const xs = [0.10, 0.30, 0.50, 0.70, 0.90];
    for (int i = 0; i < 4; i++) {
      final x0 = w * xs[i];
      final x1 = w * xs[i + 1];
      final scallop = Path()
        ..moveTo(x0, h * 0.43)
        ..arcToPoint(
          Offset(x1, h * 0.43),
          radius: Radius.circular((x1 - x0) * 0.52),
          clockwise: false,
        );
      canvas.drawPath(scallop, paint);
    }

    // Clean open rounded-bottom shop body below awning
    final body = Path()
      ..moveTo(w * 0.18, h * 0.51)
      ..lineTo(w * 0.18, h * 0.78)
      ..quadraticBezierTo(w * 0.18, h * 0.85, w * 0.25, h * 0.85)
      ..lineTo(w * 0.75, h * 0.85)
      ..quadraticBezierTo(w * 0.82, h * 0.85, w * 0.82, h * 0.78)
      ..lineTo(w * 0.82, h * 0.51);
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant _HeaderStorePainter oldDelegate) => oldDelegate.color != color;
}

class _TopBarLogoWidget extends StatelessWidget {
  final String primaryPath;
  final double height;
  final Color? fallbackColor;

  const _TopBarLogoWidget({
    Key? key,
    required this.primaryPath,
    this.height = 48,
    this.fallbackColor,
  }) : super(key: key);

  List<String> _buildCandidateList() {
    final List<String> list = [];
    final cleanPrimary = primaryPath.trim();
    if (cleanPrimary.isNotEmpty && !list.contains(cleanPrimary)) {
      list.add(cleanPrimary);
    }
    const defaultCandidates = [
      'assets/logo REGA 1 ar.png',
      'assets/logo_rega.png',
      'assets/logo.png',
      'assets/logo.jpg',
      'assets/logo.jpeg',
      'assets/images/logo.png',
      'assets/images/logo.jpg',
    ];
    for (final candidate in defaultCandidates) {
      if (!list.contains(candidate)) {
        list.add(candidate);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final clean = primaryPath.trim();

    // ١. ئەگەر بەستەری ئۆنلاین بێت (Online URL)
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildChain(context, _buildCandidateList(), 0),
      );
    }

    // ٢. ئەگەر Base64 کۆد کرابێت (Base64 Image)
    if (clean.startsWith('data:image') || clean.length > 500) {
      try {
        final String base64Clean = clean.contains(',') ? clean.split(',').last : clean;
        final bytes = base64Decode(base64Clean);
        return Image.memory(
          bytes,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildChain(context, _buildCandidateList(), 0),
        );
      } catch (_) {}
    }

    // ٣. پشکنینی فایلی فیزیکی ڕەها (Absolute Local File Path)
    if (!kIsWeb && (clean.startsWith('/') || clean.contains(':\\') || clean.startsWith('file:'))) {
      try {
        final file = File(clean.replaceFirst('file://', ''));
        if (file.existsSync()) {
          return Image.file(
            file,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildChain(context, _buildCandidateList(), 0),
          );
        }
      } catch (_) {}
    }

    // ٤. بارکردنی ئاسێتی فەرمی Flutter بەبێ دروستبوونی هیچ ئیڕۆڕێکی سیستەم
    final candidates = _buildCandidateList();
    return _buildChain(context, candidates, 0);
  }

  Widget _buildChain(BuildContext context, List<String> candidates, int index) {
    if (index >= candidates.length) {
      // ئەگەر لە ناو هیچ کام لە فایلەکان نەدۆزرایەوە، لینکی فەرمی بەکار دەهێنێت
      return Image.network(
        'https://i.postimg.cc/CKsXsdD6/logo-REGA-png.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildLogoFallbackText(),
      );
    }

    final currentPath = candidates[index];

    return Image.asset(
      currentPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildChain(context, candidates, index + 1);
      },
    );
  }

  Widget _buildLogoFallbackText() {
    final effectiveColor = fallbackColor ?? RC.bg(Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          tx('REGA'),
          style: TextStyle(
            color: effectiveColor,
            fontSize: height > 55 ? 18 : 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          tx('ڕێگا'),
          style: TextStyle(
            color: effectiveColor,
            fontSize: height > 55 ? 12 : 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// --- Screens ---

String getOrderItemImageUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('پیتزا') || lower.contains('pizza') || lower.contains('پێپەرۆنی') || lower.contains('مارگاریتا')) {
    return 'https://images.unsplash.com/photo-1628840042765-356cda07504e?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('بەرگر') || lower.contains('burger') || lower.contains('برغر') || lower.contains('همبرغر')) {
    return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('کۆلا') || lower.contains('cola') || lower.contains('پپسی') || lower.contains('pepsi') || lower.contains('ئاوی') || lower.contains('شەربەت') || lower.contains('خواردنەوە')) {
    return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('مریشک') || lower.contains('کریسپی') || lower.contains('شاوەرمە') || lower.contains('chicken') || lower.contains('گۆشت')) {
    return 'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=240&auto=format&fit=crop';
  }
  if (lower.contains('پەتاتە') || lower.contains('fries') || lower.contains('فینگە')) {
    return 'https://images.unsplash.com/photo-1576107232684-1279f3908594?q=80&w=240&auto=format&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=240&auto=format&fit=crop';
}

String formatAmountOnly(int amount) {
  return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
}

String formatPrice(int amount) {
  return 'د.ع ${formatAmountOnly(amount)}';
}

int getEstimatedItemPrice(String name, int qty) {
  final lower = name.toLowerCase();
  int unitPrice = 5000;
  if (lower.contains('پێپەرۆنی') || lower.contains('pepperoni')) {
    unitPrice = 8500;
  } else if (lower.contains('مەرگەریتا') || lower.contains('مارگاریتا') || lower.contains('سەوزە')) {
    unitPrice = 7000;
  } else if (lower.contains('پیتزا') || lower.contains('pizza')) {
    unitPrice = 7500;
  } else if (lower.contains('بەرگر') || lower.contains('burger')) {
    unitPrice = 6000;
  } else if (lower.contains('کریسپی') || lower.contains('crispy') || lower.contains('مریشک')) {
    unitPrice = 7500;
  } else if (lower.contains('کۆلا') || lower.contains('cola') || lower.contains('pepsi') || lower.contains('پپسی')) {
    unitPrice = 1000;
  } else if (lower.contains('ئاو') || lower.contains('water')) {
    unitPrice = 500;
  } else if (lower.contains('پەتاتە') || lower.contains('fries')) {
    unitPrice = 2500;
  } else if (lower.contains('سۆس') || lower.contains('sauce')) {
    unitPrice = 500;
  }
  return unitPrice * (qty <= 0 ? 1 : qty);
}

String getProductImageUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('پیتزا') || lower.contains('pizza') || lower.contains('پێپەرۆنی') || lower.contains('پێپەڕۆنی') || lower.contains('مارگاریتا') || lower.contains('مەرگەریتا')) {
    return 'https://images.unsplash.com/photo-1628840042765-356cda07504e?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('بەرگر') || lower.contains('burger') || lower.contains('برغر') || lower.contains('همبرغر')) {
    return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('کۆلا') || lower.contains('cola') || lower.contains('پپسی') || lower.contains('pepsi') || lower.contains('سۆدا') || lower.contains('خواردنەوە')) {
    return 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('مریشک') || lower.contains('کریسپی') || lower.contains('شاوەرمە') || lower.contains('کەباب') || lower.contains('گۆشت')) {
    return 'https://images.unsplash.com/photo-1562967914-608f82629710?q=80&w=300&auto=format&fit=crop';
  }
  if (lower.contains('پەتاتە') || lower.contains('فینگە') || lower.contains('fries')) {
    return 'https://images.unsplash.com/photo-1576107232684-1279f3908594?q=80&w=300&auto=format&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=300&auto=format&fit=crop';
}

void showFullScreenImageDialog(BuildContext context, {String? imageUrl, ImageProvider? imageProvider, String? title}) {
  showDialog(
    context: context,
    barrierColor: RC.bg(Colors.black).withOpacity(0.85),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.75;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: RegaResponsive.dialogInset(ctx),
          child: SizedBox(
            height: maxH,
            width: RegaResponsive.dialogMaxWidth(ctx),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (title != null && title.isNotEmpty)
                      Expanded(
                        child: Text(
                          tx(title),
                          style: TextStyle(
                            color: RC.fg(Colors.white),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: RC.bg(Colors.white).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: RC.fg(Colors.white), size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      maxScale: 4.0,
                      minScale: 0.8,
                      child: imageProvider != null
                          ? Image(
                              image: imageProvider,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: RC.fg(Colors.white70), size: 64),
                            )
                          : Image.network(
                              imageUrl ?? '',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: RC.fg(Colors.white70), size: 64),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class OrdersScreen extends StatefulWidget {
  final List<Order> orders;
  final void Function(String id, OrderStatus status, {String? reason}) onUpdateStatus;
  final VoidCallback? onOrdersChanged;
  final VoidCallback? onSimulateNewOrder;
  final ValueChanged<String>? onDeleteOrder;
  final VoidCallback? onClearCompletedOrders;

  const OrdersScreen({
    super.key,
    required this.orders,
    required this.onUpdateStatus,
    this.onOrdersChanged,
    this.onSimulateNewOrder,
    this.onDeleteOrder,
    this.onClearCompletedOrders,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> get orders => widget.orders;
  void Function(String id, OrderStatus status, {String? reason}) get onUpdateStatus => widget.onUpdateStatus;

  List<Map<String, dynamic>> _drivers = [];
  String? _selectedOrderId;
  Timer? _driversTimer;
  int _statusTab = 0; // 0 new, 1 accepted, 2 preparing, 3 ready, 4 completed

  static const _statusTabs = <({OrderStatus status, String label})>[
    (status: OrderStatus.pending, label: 'داواکاری نوێ'),
    (status: OrderStatus.accepted, label: 'قبوڵکراو'),
    (status: OrderStatus.preparing, label: 'لە ئامادەکردندایە'),
    (status: OrderStatus.ready, label: 'ئامادەیە بۆ شۆفێر'),
    (status: OrderStatus.completed, label: 'تەواوبوو'),
  ];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _driversTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadDrivers());
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPending = oldWidget.orders.where((o) => o.status == OrderStatus.pending).length;
    final newPending = orders.where((o) => o.status == OrderStatus.pending).length;
    if (newPending > oldPending && _statusTab != 0) {
      _statusTab = 0;
    }
  }

  @override
  void dispose() {
    _driversTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    final data = await VendorApiService.instance.fetchNearbyDrivers();
    if (!mounted || data == null) return;
    final list = (data['drivers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    list.sort((a, b) {
      final ao = a['is_online'] == true ? 0 : 1;
      final bo = b['is_online'] == true ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      final ad = (a['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final bd = (b['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      if (ad != bd) return ad.compareTo(bd);
      final at = (a['today_orders'] as num?)?.toInt() ?? 0;
      final bt = (b['today_orders'] as num?)?.toInt() ?? 0;
      return at.compareTo(bt);
    });
    setState(() => _drivers = list);
  }

  Order? get _selectedOrder {
    if (_selectedOrderId == null) return null;
    for (final o in orders) {
      if (o.id == _selectedOrderId) return o;
    }
    return null;
  }

  Future<void> _assignDriverToOrder(Order order, Map<String, dynamic> driver) async {
    final dbId = order.dbId;
    final driverUserId = (driver['user_id'] as num?)?.toInt();
    if (dbId == null || driverUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('داواکاری یان ماتۆرسوار نادروستە')), backgroundColor: RC.bg(Color(0xFFE50010))),
      );
      return;
    }
    final (ok, msg, data) = await VendorApiService.instance.assignDriver(dbId, driverUserId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx(msg)), backgroundColor: ok ? RC.bg(Color(0xFF00894C)) : RC.bg(Color(0xFFE50010))),
    );
    if (ok) {
      final nested = data?['driver'] as Map<String, dynamic>?;
      setState(() {
        order.driverName = nested?['name']?.toString() ?? driver['name']?.toString() ?? order.driverName;
        order.driverPhone = nested?['phone']?.toString() ?? driver['phone']?.toString() ?? order.driverPhone;
      });
      widget.onOrdersChanged?.call();
    }
  }

  String _fmtDriverDistance(dynamic meters) {
    final m = (meters as num?)?.toDouble();
    if (m == null) return 'بێ GPS';
    if (m < 1000) return '${m.round()} م';
    return '${(m / 1000).toStringAsFixed(1)} کم';
  }

  Future<void> _showAssignDriverDialog(Order order) async {
    setState(() => _selectedOrderId = order.id);
    await _loadDrivers();
    final drivers = List<Map<String, dynamic>>.from(_drivers);
    drivers.sort((a, b) {
      final ao = a['is_online'] == true ? 0 : 1;
      final bo = b['is_online'] == true ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      final ad = (a['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final bd = (b['distance_meters'] as num?)?.toDouble() ?? double.infinity;
      return ad.compareTo(bd);
    });
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: RegaResponsive.dialogInset(ctx, cap: 440),
          title: Text(tx('دیاریکردنی ماتۆرسوار بۆ ${order.id}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: RegaResponsive.dialogMaxWidth(ctx, cap: 440),
            height: 420,
            child: drivers.isEmpty
                ? Center(child: Text(tx('هیچ ماتۆرسوارێک بەردەست نییە')))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tx('نزیکترین بۆ فرۆشگاکەت یەکەمە — ئەمڕۆ چەند داواکاری گەیاندوویەتی'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RC.fg(Colors.grey.shade700)),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: drivers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final d = drivers[idx];
                            final online = d['is_online'] == true;
                            final today = (d['today_deliveries'] as num?)?.toInt() ?? 0;
                            final todayAssigned = (d['today_orders'] as num?)?.toInt() ?? 0;
                            final near = idx == 0 && d['distance_meters'] != null ? ' · نزیکترین' : '';
                            final phone = RegaResponsive.isPhone(ctx);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: phone
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.two_wheeler_rounded, color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tx('${d['name'] ?? ''} (${d['driver_code'] ?? ''})$near'),
                                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • ${_fmtDriverDistance(d['distance_meters'])}\n'
                                                    'ئەمڕۆ: $today گەیاندن · $todayAssigned داواکاری • ${IraqPhoneFormatter.display((d['phone'] ?? '').toString())}'),
                                                    style: TextStyle(fontSize: 12, color: RC.fg(Colors.grey.shade700), height: 1.35),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: RC.bg(Color(0xFF16A34A)),
                                              foregroundColor: RC.fg(Colors.white),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await _assignDriverToOrder(order, d);
                                            },
                                            child: Text(tx(online ? 'پێدان' : 'دیاریکردن')),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.two_wheeler_rounded, color: online ? RC.fg(Color(0xFF16A34A)) : RC.bg(Colors.grey)),
                                      title: Text(tx('${d['name'] ?? ''} (${d['driver_code'] ?? ''})$near'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                      subtitle: Text(
                                        tx('${online ? '🟢 ئۆنلاین' : '⚫ ئۆفلاین'} • ${_fmtDriverDistance(d['distance_meters'])}\n'
                                        'ئەمڕۆ: $today گەیاندن · $todayAssigned داواکاری • ${IraqPhoneFormatter.display((d['phone'] ?? '').toString())}'),
                                      ),
                                      isThreeLine: true,
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: RC.bg(Color(0xFF16A34A)), foregroundColor: RC.fg(Colors.white)),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await _assignDriverToOrder(order, d);
                                        },
                                        child: Text(tx(online ? 'پێدان' : 'دیاریکردن')),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(const Color(0xFFDC2626)),
                  foregroundColor: RC.fg(Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  t('داخستن'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RC.fg(Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Order> get _filteredOrders {
    final status = _statusTabs[_statusTab].status;
    final list = orders.where((o) => o.status == status).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final padH = RegaResponsive.pagePadding(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, 12, padH, 8),
                  // One line like screenshot: داواکارییە چالاکەکان | تاقیکردنەوەی دەنگ
                  child: Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          t('داواکارییە چالاکەکان'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: RC.fg(const Color(0xFF0F172A)),
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1.1,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: RC.bg(const Color(0xFFFF6418)),
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: () => OrderSoundService.playTestTone(),
                          onLongPress: () => widget.onSimulateNewOrder?.call(),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: TextDirection.rtl,
                              children: [
                                CustomPaint(
                                  size: const Size(18, 18),
                                  painter: _HeaderBellPainter(color: Colors.white),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  t('تاقیکردنەوەی دەنگ'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_statusTab == 4 &&
                          orders.any((o) => o.status == OrderStatus.completed)) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: RC.bg(Colors.white),
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: AlertDialog(
                                    title: Text(t('سڕینەوەی تەواوبووەکان')),
                                    content: Text(t('دڵنیایت لە سڕینەوەی هەموو داواکاری تەواوبووەکان؟')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('پاشگەزبوونەوە'))),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text(t('سڕینەوە'), style: TextStyle(color: RC.fg(const Color(0xFFDC2626)))),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (ok == true) widget.onClearCompletedOrders?.call();
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(Icons.delete_outline_rounded, color: RC.fg(const Color(0xFFDC2626)), size: 20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (orders.isNotEmpty) _buildStatusTabs(),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = RegaResponsive.gridCountForWidth(
                            constraints.maxWidth,
                            phone: 1,
                            tablet: 2,
                            desktop: 3,
                          );
                          if (crossAxisCount == 1) {
                            return ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return _buildOrderCard(context, filtered[index]);
                              },
                            );
                          }
                          if (filtered.length == 1) {
                            return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 540),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
                                  child: _buildOrderCard(context, filtered.first),
                                ),
                              ),
                            );
                          }
                          return GridView.builder(
                            padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              mainAxisExtent: crossAxisCount >= 3 ? 420 : 440,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildOrderCard(context, filtered[index]);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    const teal = Color(0xFF0F8A5F);
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(
          textDirection: TextDirection.rtl,
          children: List.generate(_statusTabs.length, (i) {
            final tab = _statusTabs[i];
            final selected = _statusTab == i;
            final count = orders.where((o) => o.status == tab.status).length;
            return InkWell(
              onTap: () => setState(() => _statusTab = i),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? RC.bg(teal) : Colors.transparent,
                      width: 3.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      t(tab.label),
                      style: TextStyle(
                        color: selected
                            ? RC.fg(const Color(0xFF0F172A))
                            : RC.fg(const Color(0xFF94A3B8)),
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 13.5,
                        fontFamily: kAppFontFamily,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: selected ? RC.bg(teal) : RC.bg(const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: selected ? RC.fg(Colors.white) : RC.fg(const Color(0xFF64748B)),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _extractNeighborhood(String address) {
    final m = RegExp(r'گەڕەکی\s*[^\s\-–،,]+').firstMatch(address);
    if (m != null) return m.group(0)!.trim();
    final parts = address.split(RegExp(r'[\-–،,]'));
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) return parts.first.trim();
    return address.trim().isEmpty ? 'ناونیشان' : address.trim();
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    if (order.status == OrderStatus.pending) {
      return _buildNewOrderArrivalCard(order);
    }
    if (order.status == OrderStatus.completed) {
      return _buildCompletedOrderCard(order);
    }
    if (order.status == OrderStatus.accepted ||
        order.status == OrderStatus.preparing ||
        order.status == OrderStatus.ready) {
      return _buildActiveStageOrderCard(order);
    }

    final formattedPrice = '${order.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    String idDisplay = order.id;
    if (!idDisplay.endsWith('#') && !idDisplay.startsWith('#')) {
      idDisplay = '$idDisplay#';
    }
    final selected = _selectedOrderId == order.id;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedOrderId = order.id);
        _openOrderActionBox(order);
      },
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? RC.bg(Color(0xFF16A34A)) : RC.bg(Color(0xFFFFEDD5)),
          width: selected ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Order ID (Right) & Status Badge + Price Pill (Left) in RTL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              // Order ID badge on the right
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black).withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  tx(idDisplay),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: RC.fg(Color(0xFF0F172A)),
                    letterSpacing: 0,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Status Badge & Price Pill on the left (FittedBox prevents any RenderFlex overflow)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(order.status),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFF0F172A)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tx(formattedPrice),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: RC.fg(Colors.white),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Items
          ...order.items.map((item) => _buildOrderItem(item)),
          GestureDetector(
            onTap: () => _showAssignDriverDialog(order),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                    ? RC.bg(Color(0xFFF0FDF4))
                    : RC.bg(Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                      ? RC.bg(Color(0xFFBBF7D0))
                      : RC.bg(Color(0xFFFECACA)),
                ),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    Icons.two_wheeler_rounded,
                    size: 20,
                    color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                        ? RC.fg(Color(0xFF16A34A))
                        : RC.bg(Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx((order.driverName != null && order.driverName!.trim().isNotEmpty)
                          ? 'ماتۆرسوار: ${order.driverName} (${IraqPhoneFormatter.display(order.driverPhone ?? "")})'
                          : 'ماتۆرسوار: دیاری نەکراوە — کرتە بکە بۆ هەڵبژاردن'),
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                            ? RC.bg(Color(0xFF166534))
                            : RC.bg(Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: (order.driverName != null && order.driverName!.trim().isNotEmpty)
                        ? RC.fg(Color(0xFF16A34A))
                        : RC.bg(Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ),
          if (order.driverName != null && order.driverName!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AssignedDriverMap(
                orderNumber: order.id,
                storeLat: order.storeLat,
                storeLng: order.storeLng,
                customerLat: order.customerLat,
                customerLng: order.customerLng,
                initialDriverLat: order.driverLat,
                initialDriverLng: order.driverLng,
                driverName: order.driverName,
                height: 170,
              ),
            ),

          // Customer Notes Box (بۆکسی تێبینی - Cyber Cyan لە وێنەکەدا)
          if (order.customerNotes != null && order.customerNotes!.trim().isNotEmpty) ...[
            _buildCustomerNotesBox(order.customerNotes!),
            const SizedBox(height: 6),
          ],

          // Time badge & Details Button Row (ڕاست: وردەکاری داواکاری, چەپ: کاتژمێر)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              GestureDetector(
                onTap: () => _showOrderDetails(context, order),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx('وردەکاری داواکاری'),
                      style: TextStyle(
                        color: RC.fg(Color(0xFF475569)),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: RC.fg(Color(0xFF475569)),
                      size: 18,
                    ),
                  ],
                ),
              ),
              _buildTimeBadge(order.timestamp),
            ],
          ),

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              ..._buildActionButtons(context, order),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAssignDriverDialog(order),
              icon: const Icon(Icons.two_wheeler_rounded, size: 17),
              label: Text(
                tx((order.driverName != null && order.driverName!.trim().isNotEmpty)
                    ? 'گۆڕینی ماتۆرسوار'
                    : 'ناردنی ماتۆرسوار'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: RC.fg(Color(0xFF16A34A)),
                side: BorderSide(color: RC.bg(Color(0xFF16A34A))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildOrderItem(String itemText) {
    int qtyNumber = 1;
    String name = itemText.trim();

    final arabicToStandard = {
      '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5',
      '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };

    final regex = RegExp(r'^([0-9١-٩]+)\s*[xX*×]\s*(.*)$');
    final match = regex.firstMatch(itemText.trim());
    if (match != null) {
      String numPart = match.group(1)!;
      arabicToStandard.forEach((k, v) {
        numPart = numPart.replaceAll(k, v);
      });
      qtyNumber = int.tryParse(numPart) ?? 1;
      name = match.group(2)!.trim();
    }

    final rawItemPrice = getEstimatedItemPrice(name, 1);
    final itemPriceAmount = formatAmountOnly(rawItemPrice);
    final imgUrl = getProductImageUrl(name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 360;
        final imgSize = isSmall ? 62.0 : 72.0;
        final gap = isSmall ? 10.0 : 14.0;
        final priceFontSize = isSmall ? 14.5 : 16.0;
        final nameFontSize = isSmall ? 13.5 : 14.5;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: 12),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RC.bg(Color(0xFFE2E8F0)), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: RC.bg(Colors.black).withOpacity(0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl, // RTL: First child (Image) on Right, Last child (Price) on Left
            children: [
              // وێنەی بەرهەم لە لای ڕاست (Image on the right)
              GestureDetector(
                onTap: () => showFullScreenImageDialog(context, imageUrl: imgUrl, title: name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imgUrl,
                    width: imgSize,
                    height: imgSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: imgSize,
                      height: imgSize,
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFFFF2E8)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.fastfood_rounded, size: 28, color: RC.fg(Color(0xFFFF6418))),
                    ),
                  ),
                ),
              ),

              SizedBox(width: gap),

              // ناوی بەرهەم (لە تەنیشت وێنە بەبێ Bold، ڕاست‌چین)
              Expanded(
                child: Text(
                  tx(name),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: nameFontSize,
                    color: RC.fg(Color(0xFF0F172A)),
                    letterSpacing: 0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(width: gap),

              // نرخ و بڕی داواکاری لە لای چەپ (د.ع 8,500  X 1 وەک ناو وێنەکە)
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.ltr,
                    children: [
                      Text(
                        tx('د.ع'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF64748B)),
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tx(itemPriceAmount),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF0F172A)),
                          fontWeight: FontWeight.normal,
                          fontSize: priceFontSize,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        tx('X $qtyNumber'),
                        style: TextStyle(
                          color: RC.fg(Color(0xFF10B981)), // ڕەنگی سەوز لە وێنەکەدا
                          fontWeight: FontWeight.normal,
                          fontSize: priceFontSize,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// بۆکسی تێبینی کڕیار (ڕەنگی گەرمی نیشانەی تێبینی لەسەر ڕەنگی پڕایم)
  Widget _buildCustomerNotesBox(String notes) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFFFF7ED)), // Warm soft orange background
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: RC.fg(Color(0xFFEA580C))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tx('تێبینی: $notes'),
              style: TextStyle(
                color: RC.fg(Color(0xFF9A3412)),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge(DateTime time) {
    final hourStr = time.hour.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    final timeDisplay = '$hourStr:$minStr';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 13,
            color: RC.fg(Color(0xFF64748B)),
          ),
          const SizedBox(width: 4),
          Text(
            tx(timeDisplay),
            style: TextStyle(
              color: RC.fg(Color(0xFF64748B)),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        t('هیچ داواکارییەک نییە'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: RC.fg(const Color(0xFFCBD5E1)),
          fontFamily: kAppFontFamily,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Future<void> _showRejectReasonDialog(Order order) async {
    final noteCtrl = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: RC.fg(const Color(0xFFE11D48)), size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('ڕەتکردنەوە'),
                              style: TextStyle(
                                color: RC.fg(const Color(0xFFE11D48)),
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 4,
                        minLines: 3,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: kAppFontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: RC.fg(const Color(0xFF0F172A)),
                        ),
                        decoration: InputDecoration(
                          hintText: t('تێبینی'),
                          hintStyle: TextStyle(
                            color: RC.fg(const Color(0xFF94A3B8)),
                            fontFamily: kAppFontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                          errorText: errorText,
                          filled: true,
                          fillColor: RC.bg(Colors.white),
                          contentPadding: const EdgeInsets.all(14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFE2E8F0)), width: 1.4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFE11D48)), width: 1.6),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFE11D48)), width: 1.4),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: RC.bg(const Color(0xFFE11D48)), width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final note = noteCtrl.text.trim();
                                if (note.isEmpty) {
                                  setDialogState(() {
                                    errorText = t('تکایە هۆکاری ڕەتکردنەوە بنووسە');
                                  });
                                  return;
                                }
                                Navigator.pop(ctx, true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(const Color(0xFFE55B5B)),
                                foregroundColor: RC.fg(Colors.white),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                t('ڕەتکردنەوە'),
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: kAppFontFamily),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RC.bg(const Color(0xFFF1F5F9)),
                                foregroundColor: RC.fg(const Color(0xFF0F172A)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                t('پاشگەزبوونەوە'),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, fontFamily: kAppFontFamily),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final reason = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed == true && reason.isNotEmpty) {
      onUpdateStatus(order.id, OrderStatus.rejected, reason: reason);
    }
  }

  Future<void> _confirmDeleteOrder(Order order) async {
    const coral = Color(0xFFE55B5B);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: RC.bg(Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: RC.fg(coral), size: 28),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          t('سرینەوەی داواکاری'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RC.fg(coral),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('ئایا دڵنیایت لە سرینەوەی ئەم داواکارییە؟'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RC.fg(const Color(0xFF64748B)),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: kAppFontFamily,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RC.bg(const Color(0xFFF1F5F9)),
                              foregroundColor: RC.fg(const Color(0xFF0F172A)),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              t('پاشگەزبوونەوە'),
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, fontFamily: kAppFontFamily),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RC.bg(coral),
                              foregroundColor: RC.fg(Colors.white),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              t('سرینەوە'),
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: kAppFontFamily),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok == true) {
      widget.onDeleteOrder?.call(order.id);
    }
  }

  Widget _buildActiveStageOrderCard(Order order) {
    const teal = Color(0xFF0F8A5F);
    const orange = Color(0xFFE87824);
    const redPrice = Color(0xFFB03030);
    final neighborhood = _extractNeighborhood(order.deliveryAddress);
    final phone = order.customerPhone.trim().isEmpty
        ? '—'
        : IraqPhoneFormatter.display(order.customerPhone);
    final address = order.deliveryAddress.trim().isEmpty ? '—' : order.deliveryAddress;
    final driverName = (order.driverName != null && order.driverName!.trim().isNotEmpty)
        ? order.driverName!.trim()
        : t('چاوەڕوانی شۆفێر');
    final amountOnly = formatAmountOnly(order.total.toInt());
    final statusLabel = _statusLabelForActionBox(order.status);
    final actionLabel = _actionButtonLabel(order.status);
    final next = _nextStatusAfterAction(order.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(const Color(0xFFE5E7EB)), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _selectedOrderId = order.id);
                _openOrderActionBox(order);
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status (right) + price (left) — TB
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: RC.fg(teal),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          textDirection: TextDirection.rtl,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tx(amountOnly),
                              style: TextStyle(
                                color: RC.fg(redPrice),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t('دینار'),
                              style: TextStyle(
                                color: RC.fg(const Color(0xFF94A3B8)),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _tbOrderInfoRow(
                      kind: _TbInfoIcon.person,
                      iconColor: orange,
                      label: t('ناوی کڕیار'),
                      value: order.customerName.trim().isEmpty ? 'کڕیار' : order.customerName,
                    ),
                    const SizedBox(height: 12),
                    _tbOrderInfoRow(
                      kind: _TbInfoIcon.phone,
                      iconColor: teal,
                      label: t('ژمارەی مۆبایل'),
                      value: phone,
                      valueLtr: true,
                    ),
                    const SizedBox(height: 12),
                    _tbOrderInfoRow(
                      kind: _TbInfoIcon.pin,
                      iconColor: orange,
                      label: t('ناونیشانی کڕیار'),
                      value: address,
                    ),
                    const SizedBox(height: 12),
                    _tbOrderInfoRow(
                      kind: _TbInfoIcon.driver,
                      iconColor: teal,
                      label: t('شۆفێر'),
                      value: driverName,
                      valueColor: teal,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: RC.bg(orange),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      CustomPaint(
                        size: const Size(16, 16),
                        painter: _ChatBubblePainter(color: RC.fg(Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx('کڕیار لە $neighborhood داوای دەکات'),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: RC.fg(Colors.white),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Material(
                    color: RC.bg(teal),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        if (next != null) {
                          onUpdateStatus(order.id, next);
                          setState(() => _statusTab = _tabIndexForStatus(next));
                        } else {
                          _openOrderActionBox(order);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.rtl,
                        children: [
                          CustomPaint(
                            size: const Size(18, 18),
                            painter: _FlameIconPainter(color: RC.fg(Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            actionLabel,
                            style: TextStyle(
                              color: RC.fg(Colors.white),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              fontFamily: kAppFontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// TB order detail row: colored icon + label (right) / value (left).
  Widget _tbOrderInfoRow({
    required _TbInfoIcon kind,
    required Color iconColor,
    required String label,
    required String value,
    bool valueLtr = false,
    Color valueColor = const Color(0xFF0F172A),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        CustomPaint(
          size: const Size(20, 20),
          painter: _TbInfoIconPainter(kind: kind, color: RC.fg(iconColor)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: Text(
            tx(label),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: RC.fg(const Color(0xFF64748B)),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFamily: kAppFontFamily,
            ),
          ),
        ),
        Expanded(
          child: Text(
            tx(value),
            textAlign: TextAlign.left,
            textDirection: valueLtr ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(
              color: RC.fg(valueColor),
              fontWeight: FontWeight.w800,
              fontSize: 14,
              fontFamily: kAppFontFamily,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedOrderCard(Order order) {
    const green = Color(0xFF0F8A5F);
    const orange = Color(0xFFFF6418);
    const redPrice = Color(0xFFE11D48);
    final neighborhood = _extractNeighborhood(order.deliveryAddress);
    final phone = order.customerPhone.trim().isEmpty
        ? '—'
        : IraqPhoneFormatter.display(order.customerPhone);
    final address = order.deliveryAddress.trim().isEmpty ? '—' : order.deliveryAddress;
    final driverName = (order.driverName != null && order.driverName!.trim().isNotEmpty)
        ? order.driverName!.trim()
        : t('چاوەڕوانی شۆفێر');
    final priceStr = '${formatAmountOnly(order.total.toInt())} ${t('دینار')}';

    // Tap name / anywhere on the card reopens the order action box (TB image 2).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOrderActionBox(order),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0)), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    t('تەواوبوو'),
                    style: TextStyle(
                      color: RC.fg(green),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tx(priceStr),
                    style: TextStyle(
                      color: RC.fg(redPrice),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _completedInfoRow(Icons.person_outline_rounded, t('ناوی کڕیار'), order.customerName.trim().isEmpty ? 'کڕیار' : order.customerName),
              const SizedBox(height: 10),
              _completedInfoRow(Icons.phone_outlined, t('ژمارەی مۆبایل'), phone, valueLtr: true),
              const SizedBox(height: 10),
              _completedInfoRow(Icons.location_on_outlined, t('ناونیشانی کڕیار'), address),
              const SizedBox(height: 12),
              _completedInfoRow(Icons.pedal_bike_rounded, t('شۆفێر'), driverName, valueColor: green),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: RC.bg(orange),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: RC.fg(Colors.white), size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx('کڕیار لە $neighborhood داوای دەکات'),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: RC.fg(Colors.white),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Material(
                      color: RC.bg(const Color(0xFFFEE2E2)),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _confirmDeleteOrder(order),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline_rounded, color: RC.fg(const Color(0xFFDC2626)), size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  t('سڕینەوەی داواکاری'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: RC.fg(const Color(0xFFDC2626)),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: RC.bg(Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _openOrderActionBox(order),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t('وردەکاری'),
                                style: TextStyle(
                                  color: RC.fg(const Color(0xFF0F172A)),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_left_rounded, color: RC.fg(const Color(0xFF334155)), size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _completedInfoRow(
    IconData icon,
    String label,
    String value, {
    bool valueLtr = false,
    Color valueColor = const Color(0xFF0F172A),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 18, color: RC.fg(const Color(0xFF64748B))),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: Text(
            tx(label),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: RC.fg(const Color(0xFF64748B)),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFamily: kAppFontFamily,
            ),
          ),
        ),
        Expanded(
          child: Text(
            tx(value),
            textAlign: TextAlign.left,
            textDirection: valueLtr ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(
              color: RC.fg(valueColor),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              fontFamily: kAppFontFamily,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewOrderArrivalCard(Order order) {
    const orange = Color(0xFFFF6418);
    final neighborhood = _extractNeighborhood(order.deliveryAddress);
    final phone = order.customerPhone.trim().isEmpty
        ? '—'
        : IraqPhoneFormatter.display(order.customerPhone);
    final address = order.deliveryAddress.trim().isEmpty ? '—' : order.deliveryAddress;
    final name = order.customerName.trim().isEmpty ? 'کڕیار' : order.customerName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RC.bg(orange), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: RC.bg(orange).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('داواکاری نوێ'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RC.fg(orange),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              fontFamily: kAppFontFamily,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          _buildNewOrderIconRow(Icons.person_outline_rounded, t('ناوی کڕیار'), name),
          const SizedBox(height: 12),
          _buildNewOrderIconRow(Icons.phone_outlined, t('ژمارەی مۆبایل'), phone, valueLtr: true),
          const SizedBox(height: 12),
          _buildNewOrderIconRow(Icons.location_on_outlined, t('ناونیشانی کڕیار'), address),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: RC.bg(orange),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: RC.fg(Colors.white), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tx('کڕیار لە $neighborhood داوای دەکات'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: RC.fg(Colors.white),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // TB: ڕەتکردنەوە (right) + قبوڵکردن wide (left) in RTL
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _buildRedButton(
                  label: t('ڕەتکردنەوە'),
                  onTap: () => _showRejectReasonDialog(order),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildGreenButton(
                  label: t('قبوڵکردن'),
                  icon: Icons.check_rounded,
                  onTap: () => _acceptOrderAndOpenBox(order),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewOrderIconRow(IconData icon, String label, String value, {bool valueLtr = false}) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: RC.fg(const Color(0xFF64748B))),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            tx(label),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: RC.fg(const Color(0xFF64748B)),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              fontFamily: kAppFontFamily,
            ),
          ),
        ),
        Expanded(
          child: Text(
            tx(value),
            textAlign: TextAlign.left,
            textDirection: valueLtr ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(
              color: RC.fg(const Color(0xFF0F172A)),
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              fontFamily: kAppFontFamily,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  void _acceptOrderAndOpenBox(Order order) {
    // Accept → show قبوڵکراو list card (TB image), not the sliding top box.
    onUpdateStatus(order.id, OrderStatus.accepted);
    setState(() {
      _statusTab = 1;
      _selectedOrderId = order.id;
    });
  }

  (int qty, String name) _parseOrderItem(String itemText) {
    int qtyNumber = 1;
    String name = itemText.trim();
    final regex = RegExp(r'^([0-9١-٩]+)\s*[xX*×]\s*(.*)$');
    final match = regex.firstMatch(itemText.trim());
    if (match != null) {
      String numPart = match.group(1)!;
      const arabicToStandard = {
        '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5',
        '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      };
      arabicToStandard.forEach((k, v) {
        numPart = numPart.replaceAll(k, v);
      });
      qtyNumber = int.tryParse(numPart) ?? 1;
      name = match.group(2)!.trim();
    }
    return (qtyNumber, name);
  }

  String _statusLabelForActionBox(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return t('داواکاری نوێ');
      case OrderStatus.accepted:
        return t('قبوڵکراو');
      case OrderStatus.preparing:
        return t('لە ئامادەکردندایە');
      case OrderStatus.ready:
        return t('ئامادەیە بۆ شۆفێر');
      case OrderStatus.completed:
        return t('تەواوبوو');
      case OrderStatus.rejected:
        return t('ڕەتکردنەوە');
    }
  }

  String _actionButtonLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        return t('دەستپێکردنی ئامادەکردن');
      case OrderStatus.preparing:
        return t('ئامادەیە بۆ شۆفێر');
      case OrderStatus.ready:
        return t('ڕادەستکردن بە شۆفێر');
      case OrderStatus.completed:
        return t('تەواوبوو');
      default:
        return t('تەواوبوو');
    }
  }

  int _tabIndexForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.completed:
        return 4;
      case OrderStatus.rejected:
        return 0;
    }
  }

  OrderStatus? _nextStatusAfterAction(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  Future<void> _openOrderActionBox(Order order) async {
    const green = Color(0xFF0F8A5F);
    const softGreen = Color(0xFFE8F6EF);
    const softGreenBtn = Color(0xFF7BC49A);
    const orange = Color(0xFFFF6418);
    final neighborhood = _extractNeighborhood(order.deliveryAddress);
    final phone = order.customerPhone.trim().isEmpty
        ? '—'
        : IraqPhoneFormatter.display(order.customerPhone);
    final totalStr = '${formatAmountOnly(order.total.toInt())} ${t('دینار')}';
    final driverName = (order.driverName != null && order.driverName!.trim().isNotEmpty)
        ? order.driverName!.trim()
        : t('چاوەڕوانی شۆفێر');
    const prepMinutes = 20;
    var liveStatus = order.status;
    if (liveStatus == OrderStatus.pending) {
      liveStatus = OrderStatus.accepted;
    }
    final deadline = (order.acceptedAt ?? order.timestamp).add(const Duration(minutes: prepMinutes));
    Timer? countdownTimer;

    String remainingLabel() {
      if (liveStatus == OrderStatus.completed) return '-';
      final left = deadline.difference(DateTime.now());
      if (left.inSeconds <= 0) return '-';
      final mins = left.inMinutes;
      final secs = left.inSeconds % 60;
      if (mins >= 1) return '$mins ${t('خولەک')}';
      return '$secs ${t('چرکە')}';
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'order-action',
      barrierColor: RC.bg(Colors.white),
      useRootNavigator: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, anim, secondary) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (dialogCtx.mounted) setDialogState(() {});
            });
            final remaining = remainingLabel();
            final next = _nextStatusAfterAction(liveStatus);
            final btnLabel = _actionButtonLabel(liveStatus);
            final isDone = liveStatus == OrderStatus.completed;

            // Full-screen order box (no floating card margins).
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                backgroundColor: RC.bg(Colors.white),
                body: SafeArea(
                  child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      icon: Icon(Icons.arrow_forward_ios_rounded, color: RC.fg(orange), size: 20),
                                    ),
                                    Expanded(
                                      child: Text(
                                        t('داواکاری نوێ'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: RC.fg(const Color(0xFF0F172A)),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          fontFamily: kAppFontFamily,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  child: Column(
                                    children: [
                                      ...order.items.map((raw) {
                                        final (qty, name) = _parseOrderItem(raw);
                                        final price = getEstimatedItemPrice(name, qty);
                                        final imgUrl = getProductImageUrl(name);
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                          decoration: BoxDecoration(
                                            color: RC.bg(Colors.white),
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                                          ),
                                          child: Row(
                                            textDirection: TextDirection.rtl,
                                            children: [
                                              ClipOval(
                                                child: Image.network(
                                                  imgUrl,
                                                  width: 58,
                                                  height: 58,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    width: 58,
                                                    height: 58,
                                                    color: RC.bg(const Color(0xFFFFF2E8)),
                                                    child: Icon(Icons.fastfood_rounded, color: RC.fg(orange)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Text(
                                                      tx(name),
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 15,
                                                        color: RC.fg(const Color(0xFF0F172A)),
                                                        fontFamily: kAppFontFamily,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: RC.bg(orange),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Text(
                                                          '${qty}X',
                                                          style: TextStyle(
                                                            color: RC.fg(Colors.white),
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                tx('${formatAmountOnly(price)} ${t('دینار')}'),
                                                textAlign: TextAlign.left,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                  color: RC.fg(const Color(0xFF0F172A)),
                                                  fontFamily: kAppFontFamily,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: RC.bg(orange),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          tx('${t('تێبینی : کڕیار لە')} $neighborhood ${t('داوای دەکات')}'),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: RC.fg(Colors.white),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            fontFamily: kAppFontFamily,
                                          ),
                                        ),
                                      ),
                                      _actionBoxTwoColCard(
                                        softGreen: softGreen,
                                        rows: [
                                          (t('کۆی گشتی :'), totalStr, green, false, false),
                                          (t('کاتی پێچوون :'), '$prepMinutes ${t('خولەک')}', green, false, false),
                                          (t('کاتی ماوە :'), remaining, green, false, false),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _actionBoxTwoColCard(
                                        softGreen: Colors.white,
                                        borderColor: green,
                                        rows: [
                                          (
                                            t('ناوی کڕیار'),
                                            order.customerName.trim().isEmpty ? 'کڕیار' : order.customerName,
                                            green,
                                            false,
                                            false,
                                          ),
                                          (t('مۆبایلی کڕیار'), phone, const Color(0xFF0F172A), true, false),
                                          (t('دۆخ'), _statusLabelForActionBox(liveStatus), green, false, false),
                                          (t('شۆفێر'), driverName, green, false, true),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (isDone || next == null) {
                                        Navigator.pop(dialogCtx);
                                        return;
                                      }
                                      onUpdateStatus(order.id, next);
                                      setState(() => _statusTab = _tabIndexForStatus(next));
                                      setDialogState(() => liveStatus = next);
                                      if (next == OrderStatus.completed) {
                                        // Close box → completed card appears in تەواوبوو tab (TB image 1).
                                        Navigator.pop(dialogCtx);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: RC.bg(isDone ? softGreenBtn : green),
                                      foregroundColor: RC.fg(Colors.white),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    child: Text(
                                      btnLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        fontFamily: kAppFontFamily,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
    countdownTimer?.cancel();
  }

  Widget _actionBoxTwoColCard({
    required Color softGreen,
    Color? borderColor,
    required List<(String label, String value, Color valueColor, bool valueLtr, bool pill)> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RC.bg(softGreen),
        borderRadius: BorderRadius.circular(18),
        border: borderColor != null
            ? Border.all(color: RC.bg(borderColor), width: 1.6)
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Labels column (right in RTL)
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Text(
                      tx(rows[i].$1),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: RC.fg(const Color(0xFF475569)),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        fontFamily: kAppFontFamily,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(width: 1, color: RC.bg(const Color(0xFFCBD5E1))),
            ),
            // Values column (left in RTL)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: rows[i].$5
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: RC.bg(const Color(0xFFE8F6EF)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tx(rows[i].$2),
                                style: TextStyle(
                                  color: RC.fg(rows[i].$3),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            )
                          : Text(
                              tx(rows[i].$2),
                              textAlign: TextAlign.left,
                              textDirection: rows[i].$4 ? TextDirection.ltr : TextDirection.rtl,
                              style: TextStyle(
                                color: RC.fg(rows[i].$3),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                fontFamily: kAppFontFamily,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    String text;
    switch (status) {
      case OrderStatus.pending:
        color = RC.bg(Color(0xFFEA580C)); // REGA Prime Orange
        text = t('داواکاری نوێ');
        break;
      case OrderStatus.accepted:
        color = RC.bg(Color(0xFF16A34A));
        text = t('قبوڵکراو');
        break;
      case OrderStatus.preparing:
        color = RC.bg(Color(0xFFD97706)); // Warm Amber Orange
        text = t('لە ئامادەکردندایە');
        break;
      case OrderStatus.ready:
        color = RC.bg(Color(0xFF16A34A)); // Clean Ready Green
        text = t('ئامادەیە بۆ شۆفێر');
        break;
      case OrderStatus.completed:
        color = RC.bg(Color(0xFF64748B));
        text = t('تەواوبوو');
        break;
      default:
        color = RC.bg(Color(0xFF64748B));
        text = 'نادیار';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        tx(text),
        style: TextStyle(
          color: RC.fg(Colors.white),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, Order order) {
    if (order.status == OrderStatus.pending) {
      return [
        Expanded(
          flex: 2,
          child: _buildGreenButton(
            label: t('قبوڵکردن'),
            icon: Icons.check_rounded,
            onTap: () => _acceptOrderAndOpenBox(order),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRedButton(
            label: t('رەتکردنەوە'),
            onTap: () => _showRejectReasonDialog(order),
          ),
        ),
      ];
    } else if (order.status == OrderStatus.accepted ||
        order.status == OrderStatus.preparing ||
        order.status == OrderStatus.ready) {
      return [
        Expanded(
          child: _buildGreenButton(
            label: _actionButtonLabel(order.status),
            icon: Icons.arrow_forward_rounded,
            onTap: () => _openOrderActionBox(order),
          ),
        ),
      ];
    }
    return [];
  }

  Widget _buildGreenButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFF16A34A)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: RC.fg(Colors.white), size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tx(label),
                  style: TextStyle(
                    color: RC.fg(Colors.white),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: RC.bg(Color(0xFFE50010)), // Red from screenshot
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tx(label),
              style: TextStyle(
                color: RC.fg(Colors.white),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showOrderDetails(BuildContext context, Order order) {
    int hour12 = order.timestamp.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = order.timestamp.minute.toString().padLeft(2, '0');
    final periodStr = order.timestamp.hour >= 12 ? 'م' : 'ب';
    final timeFormatted = '$hourStr:$minStr $periodStr';
    final formattedPrice = '${order.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    String idDisplay = order.id;
    if (!idDisplay.endsWith('#') && !idDisplay.startsWith('#')) {
      idDisplay = '$idDisplay#';
    }

    // Status details
    String statusLabel = 'نادیار';
    Color statusBg = RC.bg(Color(0xFFF3F4F6));
    Color statusTextColor = RC.bg(Color(0xFF374151));

    switch (order.status) {
      case OrderStatus.pending:
        statusLabel = 'داواکاری نوێ';
        statusBg = RC.bg(Color(0xFFFFEDD5));
        statusTextColor = RC.bg(Color(0xFF9A3412));
        break;
      case OrderStatus.accepted:
        statusLabel = 'قبوڵکراو';
        statusBg = RC.bg(Color(0xFFDCFCE7));
        statusTextColor = RC.bg(Color(0xFF166534));
        break;
      case OrderStatus.preparing:
        statusLabel = 'لە ئامادەکردندایە';
        statusBg = RC.bg(Color(0xFFDBEAFE));
        statusTextColor = RC.bg(Color(0xFF1E40AF));
        break;
      case OrderStatus.ready:
        statusLabel = 'ئامادەیە بۆ شۆفێر';
        statusBg = RC.bg(Color(0xFFD1FAE5));
        statusTextColor = RC.bg(Color(0xFF065F46));
        break;
      case OrderStatus.completed:
        statusLabel = 'گەیەندرا و تەواوبوو';
        statusBg = RC.bg(Color(0xFFD1FAE5));
        statusTextColor = RC.bg(Color(0xFF047857));
        break;
      case OrderStatus.rejected:
        statusLabel = 'ڕەتکراوەتەوە';
        statusBg = RC.bg(Color(0xFFFFE4E6));
        statusTextColor = RC.bg(Color(0xFFBE123C));
        break;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            backgroundColor: RC.bg(Colors.white),
            elevation: 16,
            insetPadding: RegaResponsive.dialogInset(dialogCtx, cap: 440, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(dialogCtx, cap: 440),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Close button, Order Number & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFFF6418)),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: RC.bg(Color(0xFFFF6418)).withOpacity(0.35),
                                    blurRadius: 5,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.close_rounded, color: RC.fg(Colors.white), size: 18),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                tx(idDisplay),
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: RC.fg(Color(0xFF1B2028)),
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tx(statusLabel),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: statusTextColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    tx('تۆمارکراوە: $timeFormatted'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: RC.fgn(Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: RC.bg(Color(0xFFEEEEEE))),
                      const SizedBox(height: 10),

                      // Customer & Delivery Information
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFFF8F9FA)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: RC.bg(Color(0xFFE9ECEF))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 15, color: RC.fg(Color(0xFFEA580C))),
                                const SizedBox(width: 5),
                                Text(tx('کڕیار: '), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    tx(order.customerName),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.phone_rounded, size: 15, color: RC.fg(Color(0xFFEA580C))),
                                const SizedBox(width: 5),
                                Text(tx('مۆبایل: '), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      tx(IraqPhoneFormatter.display(order.customerPhone)),
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF1B2028))),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 15, color: RC.fg(Color(0xFFEA580C))),
                                const SizedBox(width: 5),
                                Text(tx('ناونیشان: '), style: TextStyle(fontSize: 12, color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    tx(order.deliveryAddress),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (order.customerNotes != null && order.customerNotes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _buildCustomerNotesBox(order.customerNotes!),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Order Items List ("لیستی کڕین")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tx('لیستی کڕین'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: RC.fg(Color(0xFF1B2028)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: RC.bg(Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              tx('${order.items.length} بەرهەم'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: RC.fg(Color(0xFF4B5563)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      ...order.items.map((itemText) {
                        String qty = "1x";
                        int qtyNumber = 1;
                        String name = itemText.trim();
                        final regex = RegExp(r'^([0-9١-٩]+)\s*[xX*×]\s*(.*)$');
                        final match = regex.firstMatch(itemText.trim());
                        if (match != null) {
                          String numPart = match.group(1)!;
                          final arabicToStandard = {
                            '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5',
                            '٦': '6', '٧': '7', '٨': '8', '٩': '9',
                          };
                          arabicToStandard.forEach((k, v) {
                            numPart = numPart.replaceAll(k, v);
                          });
                          qtyNumber = int.tryParse(numPart) ?? 1;
                          qty = '${numPart}x';
                          name = match.group(2)!.trim();
                        }
                        final rawItemPrice = getEstimatedItemPrice(name, qtyNumber);
                        final itemPriceAmount = formatAmountOnly(rawItemPrice);
                        final imgUrl = getProductImageUrl(name);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: RC.bg(Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Colors.black).withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (itemCtx, itemConstraints) {
                              final compact = itemConstraints.maxWidth < 360;
                              final imgSize = compact ? 56.0 : 78.0;
                              final priceBlock = FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: TextDirection.ltr,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          tx('د.ع'),
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                            color: RC.fg(Color(0xFF6B7280)),
                                            fontWeight: FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          tx(itemPriceAmount),
                                          textDirection: TextDirection.ltr,
                                          style: TextStyle(
                                            color: RC.fg(Color(0xFF1E2024)),
                                            fontWeight: FontWeight.normal,
                                            fontSize: compact ? 16 : 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: compact ? 8 : 12),
                                    Text(
                                      tx('X $qtyNumber'),
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFF16A34A)),
                                        fontWeight: FontWeight.normal,
                                        fontSize: compact ? 16 : 20,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              final nameText = Text(
                                tx(name),
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: compact ? 13 : 14,
                                  color: RC.fg(Color(0xFF1E2024)),
                                ),
                                maxLines: compact ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                              );
                              final image = GestureDetector(
                                onTap: () => showFullScreenImageDialog(dialogCtx, imageUrl: imgUrl, title: name),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    imgUrl,
                                    width: imgSize,
                                    height: imgSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: imgSize,
                                      height: imgSize,
                                      color: RC.bg(Color(0xFFF3F4F6)),
                                      child: Icon(Icons.fastfood_rounded, size: compact ? 24 : 30, color: RC.fg(Color(0xFF9CA3AF))),
                                    ),
                                  ),
                                ),
                              );
                              if (compact) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    image,
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          nameText,
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: AlignmentDirectional.centerEnd,
                                            child: priceBlock,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  image,
                                  const SizedBox(width: 12),
                                  Expanded(child: nameText),
                                  const SizedBox(width: 8),
                                  Flexible(child: priceBlock),
                                ],
                              );
                            },
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // Simplified Financials (Dark Card)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: RC.bg(Color(0xFF1B2028)),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: RC.bg(Colors.black).withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tx('کۆی نرخ'), style: TextStyle(color: RC.fg(Color(0xFF9CA3AF)), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(tx(formattedPrice), style: TextStyle(color: RC.fg(Colors.white), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tx('داشکان'), style: TextStyle(color: RC.fg(Color(0xFF9CA3AF)), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(tx('٠ د.ع'), style: TextStyle(color: RC.fg(Color(0xFFF87171)), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(height: 1, color: RC.bg(Color(0xFF374151))),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tx('کۆی گشتی حساب'),
                                  style: TextStyle(
                                    color: RC.fg(Color(0xFF34D399)),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  tx(formattedPrice),
                                  style: TextStyle(
                                    color: RC.fg(Colors.white),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Contextual Action Buttons in Details Modal
                      if (order.status == OrderStatus.pending) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(Color(0xFF16A34A)),
                                  foregroundColor: RC.fg(Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  _acceptOrderAndOpenBox(order);
                                },
                                child: Text(t('قبوڵکردن'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(Color(0xFFE50010)),
                                  foregroundColor: RC.fg(Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  _showRejectReasonDialog(order);
                                },
                                child: Text(t('رەتکردنەوە'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.accepted) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFF16A34A)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            onUpdateStatus(order.id, OrderStatus.preparing);
                            setState(() => _statusTab = 2);
                          },
                          child: Text(t('دەستپێکردنی ئامادەکردن'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.preparing) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFF16A34A)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            onUpdateStatus(order.id, OrderStatus.ready);
                            setState(() => _statusTab = 3);
                          },
                          child: Text(t('ئامادەیە بۆ شۆفێر'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.ready) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(Color(0xFF16A34A)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            onUpdateStatus(order.id, OrderStatus.completed);
                          },
                          child: Text(t('ڕادەستکردن بە شۆفێر'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RC.bg(const Color(0xFFDC2626)),
                            foregroundColor: RC.fg(Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text(
                            t('داخستن'),
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: RC.fg(Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class ProductsScreen extends StatefulWidget {
  final List<Product> products;
  final List<String> categories;
  final Function(String) onToggle;
  final Function(String) onDelete;
  final Function(Product) onAdd;
  final Function(Product) onEdit;
  final void Function(String name, {String? imageUrl}) onAddCategory;
  final Function(String)? onDeleteCategory;
  final Future<void> Function(int percent)? onStoreDiscount;

  const ProductsScreen({
    super.key, 
    required this.products, 
    required this.categories,
    required this.onToggle, 
    required this.onDelete,
    required this.onAdd,
    required this.onEdit,
    required this.onAddCategory,
    this.onDeleteCategory,
    this.onStoreDiscount,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

enum _ProductAvailFilter { all, available, unavailable, discounted }

class _ProductsScreenState extends State<ProductsScreen> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProductAvailFilter _availFilter = _ProductAvailFilter.all;
  final Set<String> _disabledCategories = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteCategory(BuildContext context, String category) {
    final count = widget.products.where((p) => p.category.trim() == category.trim()).length;
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: RC.bg(Colors.white),
          insetPadding: RegaResponsive.dialogInset(dialogCtx, cap: 420),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFEBEE)),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: RC.fg(Color(0xFFE50010)), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx('سڕینەوەی بەش'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: RegaResponsive.dialogMaxWidth(dialogCtx, cap: 420),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx('ئایا دڵنیایت لە سڕینەوەی بەشی "$category"؟'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF374151)), height: 1.4),
              ),
              if (count > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFFFBEB)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RC.bg(Color(0xFFFDE68A))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: RC.fg(Color(0xFFB45309))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx('ئەم بەشە $count بەرهەمی تێدایە.'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF92400E))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(tx('پاشگەزبوونەوە'), style: TextStyle(color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFE50010)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() {
                  if (_selectedCategory == category) {
                    _selectedCategory = null;
                  }
                  widget.categories.remove(category);
                });
                widget.onDeleteCategory?.call(category);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tx('بەشی "$category" بە سەرکەوتوویی سڕایەوە'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: RC.bg(Color(0xFFE50010)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(tx('سڕینەوە'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: RC.bg(Colors.white),
          insetPadding: RegaResponsive.dialogInset(dialogCtx, cap: 420),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RC.bg(Color(0xFFFFEBEE)),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: RC.fg(Color(0xFFE50010)), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tx('سڕینەوەی بەرهەم'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF1B2028))),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: RegaResponsive.dialogMaxWidth(dialogCtx, cap: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx('ئایا دڵنیایت لە سڕینەوەی بەرهەمی "${product.name}"؟'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: RC.fg(Color(0xFF374151)), height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  tx('ئەم بەرهەمە لە مێنۆکەت دەسڕدرێتەوە.'),
                  style: TextStyle(fontSize: 12, color: RC.fgn(Colors.grey[600])),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(tx('پاشگەزبوونەوە'), style: TextStyle(color: RC.fg(Color(0xFF6B7280)), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RC.bg(Color(0xFFE50010)),
                foregroundColor: RC.fg(Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.onDelete(product.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tx('بەرهەمی "${product.name}" بە سەرکەوتوویی سڕایەوە'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: RC.bg(Color(0xFFE50010)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(tx('سڕینەوە'), style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  bool _productHasDiscount(Product p) =>
      p.discountPrice != null && p.discountPrice! > 0 && p.discountPrice! < p.price;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6418);
    const teal = Color(0xFF0D9488);
    final padH = RegaResponsive.pagePadding(context);

    // Empty categories: match T.B empty menu landing.
    if (widget.categories.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, 14, padH, 8),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Text(
                          t('بەشەکانی مێنۆ'),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: RC.fg(const Color(0xFF0F172A)),
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: RC.bg(orange),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () async {
                            await _showAddCategoryDialog(context);
                            if (mounted) setState(() {});
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, color: RC.fg(Colors.white), size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  t('زیادکردنی بەش'),
                                  style: TextStyle(
                                    color: RC.fg(Colors.white),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      t('هیچ بەشێک زیاد نەکراوە'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: RC.fg(const Color(0xFFCBD5E1)),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFamily: kAppFontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredProducts = widget.products.where((p) {
      final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesAvail = switch (_availFilter) {
        _ProductAvailFilter.all => true,
        _ProductAvailFilter.available => p.isAvailable,
        _ProductAvailFilter.unavailable => !p.isAvailable,
        _ProductAvailFilter.discounted => _productHasDiscount(p),
      };
      return matchesCategory && matchesSearch && matchesAvail;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              // Header: title + new product
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 10, padH, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('مێنۆ و بەرهەمەکان'),
                        style: TextStyle(
                          color: RC.fg(const Color(0xFF1E293B)),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          fontFamily: kAppFontFamily,
                        ),
                      ),
                    ),
                    Material(
                      color: RC.bg(orange),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _showAddProductDialog(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, color: RC.fg(Colors.white), size: 20),
                              const SizedBox(width: 4),
                              Text(
                                t('بەرهەمی نوێ'),
                                style: TextStyle(
                                  color: RC.fg(Colors.white),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Categories row
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 0, padH, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                  ),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Material(
                          color: RC.bg(const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => _showCategoriesManageSheet(context),
                            onLongPress: () => _showStoreDiscountDialog(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 16, color: RC.fg(const Color(0xFF64748B))),
                                  const SizedBox(width: 6),
                                  Text(
                                    t('بەشەکان'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: RC.fg(const Color(0xFF334155)),
                                      fontFamily: kAppFontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _categoryChip(
                          label: '${t('هەمووی')} ${widget.products.length}',
                          selected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                          orange: orange,
                        ),
                        ...widget.categories.where((c) => !_disabledCategories.contains(c)).map((cat) {
                          final count = widget.products.where((p) => p.category.trim() == cat.trim()).length;
                          final selected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: _categoryChip(
                              label: '$cat $count',
                              selected: selected,
                              onTap: () => setState(() => _selectedCategory = selected ? null : cat),
                              onLongPress: () => _confirmDeleteCategory(context, cat),
                              orange: orange,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // Availability filters
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 0, padH, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _availChip(t('هەمووی'), _ProductAvailFilter.all, orange),
                      const SizedBox(width: 8),
                      _availChip(t('بەردەستە'), _ProductAvailFilter.available, orange),
                      const SizedBox(width: 8),
                      _availChip(t('نەماوە'), _ProductAvailFilter.unavailable, orange),
                      const SizedBox(width: 8),
                      _availChip(t('داشکاندن'), _ProductAvailFilter.discounted, orange),
                    ],
                  ),
                ),
              ),

              // Search
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 0, padH, 10),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: RC.fg(const Color(0xFF94A3B8)), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textAlign: TextAlign.right,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: t('...گەڕان'),
                            hintStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: RC.fg(const Color(0xFF94A3B8)),
                              fontFamily: kAppFontFamily,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RC.fg(const Color(0xFF0F172A)),
                            fontFamily: kAppFontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Product list
              Expanded(
                child: filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(padH, 0, padH, 16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(context, filteredProducts[index], teal: teal);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Color orange,
  }) {
    return Material(
      color: selected ? RC.bg(const Color(0xFFFFF7ED)) : RC.bg(const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? orange : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            tx(label),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? RC.fg(orange) : RC.fg(const Color(0xFF334155)),
              fontFamily: kAppFontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _availChip(String label, _ProductAvailFilter filter, Color orange) {
    final selected = _availFilter == filter;
    return Material(
      color: selected ? RC.bg(orange) : RC.bg(const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _availFilter = filter),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: selected ? RC.fg(Colors.white) : RC.fg(const Color(0xFF475569)),
              fontFamily: kAppFontFamily,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_outlined, color: RC.fg(Color(0xFFEA580C)), size: 48),
          const SizedBox(height: 24),
          Text(t('هیچ بەرهەمێک نەدۆزرایەوە'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(t('دەتوانیت بە کلیک لەسەر دوگمەی (بەرهەمی نوێ) یەکەمین کاڵا زیادبکەیت.'), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, {required Color teal}) {
    final resolvedUrl = VendorApiService.instance.resolveMediaUrl(product.imageUrl);
    ImageProvider imageProvider;
    if (!kIsWeb && product.imagePath != null && product.imagePath!.isNotEmpty) {
      try {
        final f = File(product.imagePath!);
        if (f.existsSync()) {
          imageProvider = FileImage(f);
        } else if (resolvedUrl.isNotEmpty) {
          imageProvider = NetworkImage(resolvedUrl);
        } else {
          imageProvider = NetworkImage(getProductImageUrl(product.name));
        }
      } catch (_) {
        imageProvider = resolvedUrl.isNotEmpty
            ? NetworkImage(resolvedUrl)
            : NetworkImage(getProductImageUrl(product.name));
      }
    } else if (resolvedUrl.isNotEmpty) {
      imageProvider = NetworkImage(resolvedUrl);
    } else {
      imageProvider = NetworkImage(getProductImageUrl(product.name));
    }

    final hasDiscount = _productHasDiscount(product);
    final displayPrice = hasDiscount ? product.discountPrice!.toInt() : product.price.toInt();
    final priceStr = '${formatAmountOnly(displayPrice)} ${t('دینار')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          GestureDetector(
            onTap: () => showFullScreenImageDialog(context, imageProvider: imageProvider, title: product.name),
            child: ClipOval(
              child: Image(
                image: imageProvider,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: RC.bg(const Color(0xFFFFF7ED)),
                  child: Icon(Icons.fastfood_rounded, color: RC.fg(const Color(0xFFFF6418))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(product.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: RC.fg(const Color(0xFF0F172A)),
                    fontFamily: kAppFontFamily,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tx(priceStr),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: RC.fg(teal),
                    fontFamily: kAppFontFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                onPressed: () => _showEditProductDialog(context, product),
                onLongPress: () => _confirmDeleteProduct(context, product),
                icon: Icon(Icons.edit_square, color: RC.fg(teal), size: 22),
                tooltip: t('دەستکاری'),
                visualDensity: VisualDensity.compact,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.isAvailable ? t('بەردەستە') : t('نەماوە'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: product.isAvailable ? RC.fg(teal) : RC.fg(const Color(0xFF94A3B8)),
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch.adaptive(
                    value: product.isAvailable,
                    activeColor: teal,
                    onChanged: (_) => widget.onToggle(product.id),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyCategoryRename(String oldName, String newName) {
    if (newName.isEmpty || newName == oldName) return;
    if (widget.categories.contains(newName) && newName != oldName) return;
    setState(() {
      final idx = widget.categories.indexOf(oldName);
      if (idx != -1) widget.categories[idx] = newName;
      for (final p in widget.products) {
        if (p.category.trim() == oldName.trim()) {
          p.category = newName;
        }
      }
      if (_selectedCategory == oldName) _selectedCategory = newName;
      if (_disabledCategories.remove(oldName)) {
        _disabledCategories.add(newName);
      }
    });
  }

  Future<void> _showCategoriesManageSheet(BuildContext context) async {
    const orange = Color(0xFFFF6418);
    const teal = Color(0xFF0D9488);

    String? editingCategory;
    TextEditingController? editCtrl;
    String? editImageUrl;
    String? editLocalPath;
    Uint8List? editPreviewBytes;
    var editImageBusy = false;

    void disposeEdit() {
      editCtrl?.dispose();
      editCtrl = null;
      editingCategory = null;
      editImageUrl = null;
      editLocalPath = null;
      editPreviewBytes = null;
      editImageBusy = false;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'categories-manage',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, anim, secondary) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            void startEdit(String cat) {
              editCtrl?.dispose();
              editingCategory = cat;
              editCtrl = TextEditingController(text: cat);
              editImageUrl = null;
              editLocalPath = null;
              editPreviewBytes = null;
              editImageBusy = false;
              setSheetState(() {});
            }

            void cancelEdit() {
              disposeEdit();
              setSheetState(() {});
            }

            Future<void> saveEdit() async {
              final oldName = editingCategory;
              final newName = editCtrl?.text.trim() ?? '';
              if (oldName == null || newName.isEmpty) return;
              if (editImageBusy) return;
              final imageToSave = editImageUrl;
              final hasServerId = VendorApiService.instance.categoryNameToId.containsKey(oldName);
              if (hasServerId) {
                final (ok, msg) = await VendorApiService.instance.updateCategory(
                  oldNameKu: oldName,
                  newNameKu: newName,
                  imageUrl: imageToSave,
                );
                if (!mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tx(msg), textAlign: TextAlign.center),
                      backgroundColor: RC.bg(const Color(0xFFE50010)),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
              }
              _applyCategoryRename(oldName, newName);
              disposeEdit();
              setSheetState(() {});
              setState(() {});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tx('بەش نوێکرایەوە'), textAlign: TextAlign.center),
                  backgroundColor: RC.bg(const Color(0xFF00894C)),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: math.min(MediaQuery.sizeOf(dialogCtx).width - 20, 440),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.92,
                      ),
                      decoration: BoxDecoration(
                        color: RC.bg(Colors.white),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    disposeEdit();
                                    Navigator.pop(dialogCtx);
                                  },
                                  icon: Icon(Icons.arrow_forward_ios_rounded, color: RC.fg(orange), size: 20),
                                ),
                                Expanded(
                                  child: Text(
                                    t('بەڕێوەبردنی بەشەکان'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: RC.fg(const Color(0xFF0F172A)),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      fontFamily: kAppFontFamily,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _showAddCategoryDialog(context);
                                  setSheetState(() {});
                                  setState(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(orange),
                                  foregroundColor: RC.fg(Colors.white),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  '+ ${t('زیادکردنی بەشی نوێ')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                t('بەشەکانی مێنۆ'),
                                style: TextStyle(
                                  color: RC.fg(const Color(0xFF334155)),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  fontFamily: kAppFontFamily,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: widget.categories.isEmpty
                                ? Center(
                                    child: Text(
                                      t('هیچ بەشێک نییە'),
                                      style: TextStyle(
                                        color: RC.fg(const Color(0xFF94A3B8)),
                                        fontFamily: kAppFontFamily,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    itemCount: widget.categories.length,
                                    itemBuilder: (context, index) {
                                      final cat = widget.categories[index];
                                      final enabled = !_disabledCategories.contains(cat);
                                      final isEditing = editingCategory == cat;

                                      if (isEditing) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                          decoration: BoxDecoration(
                                            color: RC.bg(Colors.white),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                textDirection: TextDirection.rtl,
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller: editCtrl,
                                                      textAlign: TextAlign.right,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                        fontFamily: kAppFontFamily,
                                                        color: RC.fg(const Color(0xFF0F172A)),
                                                      ),
                                                      decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                        enabledBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(color: RC.bg(orange), width: 1.5),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(color: RC.bg(orange), width: 1.8),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Material(
                                                    color: RC.bg(teal),
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: InkWell(
                                                      onTap: saveEdit,
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: SizedBox(
                                                        width: 40,
                                                        height: 40,
                                                        child: Icon(Icons.check_rounded, color: RC.fg(Colors.white), size: 22),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Material(
                                                    color: RC.bg(const Color(0xFFF1F5F9)),
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: InkWell(
                                                      onTap: cancelEdit,
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: SizedBox(
                                                        width: 40,
                                                        height: 40,
                                                        child: Icon(Icons.close_rounded, color: RC.fg(const Color(0xFF64748B)), size: 22),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: Material(
                                                  color: RC.bg(const Color(0xFFFFF7ED)),
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: InkWell(
                                                    onTap: editImageBusy
                                                        ? null
                                                        : () => _pickCompressUploadProductImage(
                                                              setSheetState,
                                                              onBusy: (v) {
                                                                editImageBusy = v;
                                                                setSheetState(() {});
                                                              },
                                                              onError: (_) {},
                                                              onResult: (path, url, bytes) {
                                                                editLocalPath = path;
                                                                editImageUrl = url;
                                                                editPreviewBytes = bytes;
                                                                setSheetState(() {});
                                                              },
                                                            ),
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (editPreviewBytes != null) ...[
                                                            ClipRRect(
                                                              borderRadius: BorderRadius.circular(6),
                                                              child: Image.memory(editPreviewBytes!, width: 22, height: 22, fit: BoxFit.cover),
                                                            ),
                                                            const SizedBox(width: 8),
                                                          ] else
                                                            Icon(Icons.image_outlined, size: 18, color: RC.fg(orange)),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            t('وێنەی بەش'),
                                                            style: TextStyle(
                                                              color: RC.fg(orange),
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 12.5,
                                                              fontFamily: kAppFontFamily,
                                                            ),
                                                          ),
                                                          if (editImageBusy) ...[
                                                            const SizedBox(width: 8),
                                                            SizedBox(
                                                              width: 14,
                                                              height: 14,
                                                              child: CircularProgressIndicator(strokeWidth: 2, color: RC.fg(orange)),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: RC.bg(Colors.white),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
                                        ),
                                        child: Row(
                                          textDirection: TextDirection.rtl,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tx(cat),
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  color: RC.fg(const Color(0xFF0F172A)),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  fontFamily: kAppFontFamily,
                                                ),
                                              ),
                                            ),
                                            Switch.adaptive(
                                              value: enabled,
                                              activeColor: teal,
                                              onChanged: (v) {
                                                setSheetState(() {
                                                  if (v) {
                                                    _disabledCategories.remove(cat);
                                                  } else {
                                                    _disabledCategories.add(cat);
                                                    if (_selectedCategory == cat) {
                                                      _selectedCategory = null;
                                                    }
                                                  }
                                                });
                                                setState(() {});
                                              },
                                            ),
                                            IconButton(
                                              onPressed: () => startEdit(cat),
                                              icon: Icon(Icons.edit_square, color: RC.fg(teal), size: 22),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                if (editingCategory == cat) cancelEdit();
                                                _confirmDeleteCategory(context, cat);
                                                Future.delayed(const Duration(milliseconds: 300), () {
                                                  if (dialogCtx.mounted) setSheetState(() {});
                                                  if (mounted) setState(() {});
                                                });
                                              },
                                              icon: Icon(Icons.delete_outline_rounded, color: RC.fg(const Color(0xFF0F172A)), size: 22),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  disposeEdit();
                                  Navigator.pop(dialogCtx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RC.bg(const Color(0xFFE11D48)),
                                  foregroundColor: RC.fg(Colors.white),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  t('داخستن'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    fontFamily: kAppFontFamily,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    disposeEdit();
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final categoryController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            insetPadding: RegaResponsive.dialogInset(context, cap: 380),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(18),
              constraints: BoxConstraints(
                maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 380),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('زیادکردنی بەشی نوێ'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('تکایە ناوی ئەو بەشە بنووسە کە دەتەوێت زیادی بکەیت'),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: RC.fg(Colors.grey), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(t('ناوی بەش')),
                    _buildTextField(categoryController, 'بۆ نموونە: پیتزاکان'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(t('پاشگەزبونەوە'), style: TextStyle(color: RC.fg(Colors.grey), fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final name = categoryController.text.trim();
                              if (name.isNotEmpty) {
                                widget.onAddCategory(name);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RC.bg(Color(0xFFFF6418)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: Text(
                              t('زیادکردن'),
                              style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w900, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const List<int> _discountPercents = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100];

  int? _percentFromPrices(double price, double? discountPrice) {
    if (discountPrice == null || discountPrice <= 0 || price <= 0 || discountPrice >= price) {
      return null;
    }
    final raw = (((price - discountPrice) / price) * 100).round();
    final snapped = ((raw / 5).round() * 5).clamp(5, 100);
    return snapped;
  }

  double? _priceFromPercent(double price, int? percent) {
    if (percent == null || percent <= 0 || price <= 0) return null;
    final v = (price * (100 - percent) / 100).roundToDouble();
    return v < price ? v : (price - 1).clamp(0, price);
  }

  Widget _buildDiscountPercentDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: Text(t('بێ داشکاندن'), style: TextStyle(color: RC.fg(Colors.grey.shade500), fontSize: 13)),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(t('بێ داشکاندن'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            ..._discountPercents.map(
              (p) => DropdownMenuItem<int?>(
                value: p,
                child: Text(tx('$p%'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showStoreDiscountDialog(BuildContext context) {
    int? selectedPercent = 10;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: Trans.direction,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: RegaResponsive.dialogInset(ctx, cap: 380),
              title: Text(t('داشکاندنی دوکان'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              content: SizedBox(
                width: RegaResponsive.dialogMaxWidth(ctx, cap: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('داشکاندن بۆ هەموو بەرهەمەکان جێبەجێ دەکرێت'),
                      style: TextStyle(fontSize: 12.5, color: RC.fg(Colors.grey.shade600), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    _buildLabel(t('ڕێژەی داشکاندن هەڵبژێرە')),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedPercent,
                          isExpanded: true,
                          items: _discountPercents
                              .map((p) => DropdownMenuItem(value: p, child: Text(tx('$p%'), style: const TextStyle(fontWeight: FontWeight.w800))))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedPercent = v ?? 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RC.bg(Color(0xFFE11D48)),
                          foregroundColor: RC.fg(Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                setDialogState(() => saving = true);
                                await widget.onStoreDiscount?.call(selectedPercent ?? 10);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Text(t('جێبەجێکردنی داشکاندن')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setDialogState(() => saving = true);
                                await widget.onStoreDiscount?.call(0);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        child: Text(t('لابردنی داشکاندنی دوکان'), style: TextStyle(color: RC.fg(Color(0xFFE11D48)))),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        child: Text(t('پاشگەزبونەوە')),
                      ),
                    ),
                  ],
                ),
              ),
              actions: const [],
            ),
          );
        },
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toInt().toString());
    final costController = TextEditingController(text: product.costPrice.toInt().toString());
    final descKuController = TextEditingController(text: product.id == '3' ? 'بەرگری گۆشتی فرێش لەگەڵ پەنیر و سەوزە' : '');
    final descArController = TextEditingController();
    String selectedCategory = product.category;
    String? localImagePath = product.imagePath;
    String? uploadedImageUrl = product.imageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;
    String? imageError;
    int? selectedDiscountPct = _percentFromPrices(product.price, product.discountPrice);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: RegaResponsive.dialogInset(context, cap: 420, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 420),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFFFF7ED)),
                                  border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: RC.fg(Color(0xFFEA580C)),
                                    size: 20,
                                    shadows: [Shadow(color: RC.bg(Color(0xFFEA580C)), blurRadius: 1)],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    t('دەستکاریکردنی بەرهەم'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: RC.bg(Color(0xFFEEEEEE))),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(t('ناوی بەرهەم *')),
                              _buildTextField(nameController, '...Pizza'),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('بەش / پۆڵێن *')),
                              _buildDropdown(
                                value: selectedCategory,
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedCategory = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('نرخی کڕین (تێچوو) *')),
                              _buildTextField(costController, '5000', onChanged: (_) => setDialogState(() {})),
                              const SizedBox(height: 10),

                              _buildLabel(t('نرخی فرۆشتن *')),
                              _buildTextField(priceController, '7500', onChanged: (_) => setDialogState(() {})),
                              Builder(
                                builder: (_) {
                                  final sell = double.tryParse(priceController.text) ?? 0;
                                  final cost = double.tryParse(costController.text) ?? 0;
                                  final gross = sell - cost;
                                  if (sell <= 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('قازانجی سەرەتایی')}: ${gross.toInt()} د.ع'),
                                      style: TextStyle(
                                        color: gross > 0 ? RC.bg(Color(0xFF059669)) : RC.bg(Color(0xFFDC2626)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              _buildLabel('${t('داشکاندنی بەرهەم (٪)')} — ${t('داشکاندن بۆ بەرهەمێک')}'),
                              _buildDiscountPercentDropdown(
                                value: selectedDiscountPct,
                                onChanged: (v) => setDialogState(() => selectedDiscountPct = v),
                              ),
                              Builder(
                                builder: (_) {
                                  final base = double.tryParse(priceController.text) ?? product.price;
                                  final after = _priceFromPercent(base, selectedDiscountPct);
                                  if (after == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('نرخی دوای داشکاندن')}: ${after.toInt()} د.ع  (−${selectedDiscountPct}%)'),
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFF059669)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وێنەی بەرهەم')),
                              _buildImagePicker(
                                thumbnail: uploadedImageUrl ??
                                    (product.id == '3'
                                        ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=100'
                                        : product.imageUrl),
                                localImagePath: localImagePath,
                                previewBytes: previewBytes,
                                busy: imageBusy,
                                errorText: txn(imageError),
                                onTap: imageBusy
                                    ? null
                                    : () => _pickCompressUploadProductImage(
                                          setDialogState,
                                          onBusy: (v) => imageBusy = v,
                                          onError: (e) => imageError = e,
                                          onResult: (path, url, bytes) {
                                            localImagePath = path;
                                            uploadedImageUrl = url;
                                            previewBytes = bytes;
                                          },
                                        ),
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - کوردی (ئارەزوومەندانە)')),
                              _buildTextField(descKuController, '', maxLines: 2),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - عەرەبی')),
                              _buildTextField(descArController, '', maxLines: 1),
                              const SizedBox(height: 14),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: imageBusy
                                      ? null
                                      : () {
                                          if (nameController.text.isNotEmpty) {
                                            final base = double.tryParse(priceController.text) ?? 0;
                                            final cost = double.tryParse(costController.text) ?? 0;
                                            if (cost < 0 || cost >= base) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(tx('نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت'), textAlign: TextAlign.center),
                                                  backgroundColor: RC.bg(Color(0xFFDC2626)),
                                                ),
                                              );
                                              return;
                                            }
                                            widget.onEdit(Product(
                                              id: product.id,
                                              name: nameController.text,
                                              category: selectedCategory,
                                              price: base,
                                              costPrice: cost,
                                              discountPrice: _priceFromPercent(base, selectedDiscountPct),
                                              isAvailable: product.isAvailable,
                                              imagePath: localImagePath,
                                              imageUrl: uploadedImageUrl ?? product.imageUrl,
                                            ));
                                            Navigator.pop(context);
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(Color(0xFF00C853)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(t('تۆمارکردنی بەرهەم'),
                                    style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w900, fontSize: 14.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _pickCompressUploadProductImage(
    StateSetter setDialogState, {
    required void Function(bool busy) onBusy,
    required void Function(String? error) onError,
    required void Function(String? path, String url, Uint8List bytes) onResult,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: Trans.direction,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: RC.bgn(Colors.grey[300]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header (Title & Close Button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('هەڵبژاردنی وێنە'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: RC.fg(Color(0xFF1E293B))),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: RC.bgn(Colors.grey[100]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: RC.fg(Colors.grey)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                
                // Camera Option Card
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RC.bg(Color(0xFFFF9800)), RC.bg(Color(0xFFF57C00))],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFFF9800)).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: RC.fg(Colors.white), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('کامێرا'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RC.fg(Color(0xFF1E293B))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەی نوێ وەبگرە'),
                                style: TextStyle(color: RC.fgn(Colors.grey[600]), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF3E0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: RC.fg(Color(0xFFFF9800)),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Gallery Option Card
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.bg(Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [RC.bg(Color(0xFFFF9800)), RC.bg(Color(0xFFF57C00))],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: RC.bg(Color(0xFFFF9800)).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.photo_library_rounded, color: RC.fg(Colors.white), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('گالەری'),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: RC.fg(Color(0xFF1E293B))),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەیەک لە موبایلەکەت هەڵبژێرە'),
                                style: TextStyle(color: RC.fgn(Colors.grey[600]), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF3E0)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: RC.fg(Color(0xFFFF9800)),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: RC.bg(Color(0xFFE50010)),
                      foregroundColor: RC.fg(Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t('پاشگەزبوونەوە'),
                      style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

    if (source == null) return;

    setDialogState(() {
      onBusy(true);
      onError(null);
    });
    try {
      final picked = await pickVendorImage(fromCamera: source == ImageSource.camera);
      if (picked == null) {
        setDialogState(() => onBusy(false));
        return;
      }
      if (picked.bytes.isEmpty) {
        throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
      }
      final compressed = await ImageCompressService.compressForUpload(
        name: picked.name.isNotEmpty ? picked.name : 'product.jpg',
        bytes: picked.bytes,
      );
      final up = await VendorApiService.instance.uploadMedia(
        compressed.bytes,
        compressed.name,
      );
      final url = up['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
      }
      if (!mounted) return;
      setDialogState(() {
        onResult(null, url, compressed.bytes);
        onBusy(false);
        onError(null);
      });
    } catch (e) {
      if (!mounted) return;
      setDialogState(() {
        onBusy(false);
        onError(e.toString());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tx(e.toString()), textAlign: TextAlign.center),
          backgroundColor: RC.bg(Color(0xFFE50010)),
        ),
      );
    }
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costController = TextEditingController();
    final descKuController = TextEditingController();
    final descArController = TextEditingController();
    String selectedCategory = widget.categories.isNotEmpty ? widget.categories.first : 'پیتزا';
    String? localImagePath;
    String? uploadedImageUrl;
    Uint8List? previewBytes;
    var imageBusy = false;
    String? imageError;
    int? selectedDiscountPct;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: RegaResponsive.dialogInset(context, cap: 420, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: RegaResponsive.dialogMaxWidth(context, cap: 420),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: RC.bg(Color(0xFFFFF7ED)),
                                  border: Border.all(color: RC.bg(Color(0xFFFED7AA)), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: RC.fg(Color(0xFFEA580C)),
                                    size: 20,
                                    shadows: [Shadow(color: RC.bg(Color(0xFFEA580C)), blurRadius: 1)],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    tx('زیادکردنی بەرهەمی نوێ'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32), // Balance the close button
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: RC.bg(Color(0xFFEEEEEE))),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(t('ناوی بەرهەم *')),
                              _buildTextField(nameController, '...Pizza'),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('بەش / پۆڵێن *')),
                              _buildDropdown(
                                value: selectedCategory,
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedCategory = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('نرخی کڕین (تێچوو) *')),
                              _buildTextField(costController, '5000', onChanged: (_) => setDialogState(() {})),
                              const SizedBox(height: 10),

                              _buildLabel(t('نرخی فرۆشتن *')),
                              _buildTextField(priceController, '7500', onChanged: (_) => setDialogState(() {})),
                              Builder(
                                builder: (_) {
                                  final sell = double.tryParse(priceController.text) ?? 0;
                                  final cost = double.tryParse(costController.text) ?? 0;
                                  final gross = sell - cost;
                                  if (sell <= 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('قازانجی سەرەتایی')}: ${gross.toInt()} د.ع'),
                                      style: TextStyle(
                                        color: gross > 0 ? RC.bg(Color(0xFF059669)) : RC.bg(Color(0xFFDC2626)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              _buildLabel('${t('داشکاندنی بەرهەم (٪)')} — ${t('داشکاندن بۆ بەرهەمێک')}'),
                              _buildDiscountPercentDropdown(
                                value: selectedDiscountPct,
                                onChanged: (v) => setDialogState(() => selectedDiscountPct = v),
                              ),
                              Builder(
                                builder: (_) {
                                  final base = double.tryParse(priceController.text) ?? 0;
                                  final after = _priceFromPercent(base, selectedDiscountPct);
                                  if (after == null) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      tx('${t('نرخی دوای داشکاندن')}: ${after.toInt()} د.ع  (−${selectedDiscountPct}%)'),
                                      style: TextStyle(
                                        color: RC.fg(Color(0xFF059669)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وێنەی بەرهەم')),
                              _buildImagePicker(
                                thumbnail: uploadedImageUrl,
                                localImagePath: localImagePath,
                                previewBytes: previewBytes,
                                busy: imageBusy,
                                errorText: txn(imageError),
                                onTap: imageBusy
                                    ? null
                                    : () => _pickCompressUploadProductImage(
                                          setDialogState,
                                          onBusy: (v) => imageBusy = v,
                                          onError: (e) => imageError = e,
                                          onResult: (path, url, bytes) {
                                            localImagePath = path;
                                            uploadedImageUrl = url;
                                            previewBytes = bytes;
                                          },
                                        ),
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - کوردی (ئارەزوومەندانە)')),
                              _buildTextField(descKuController, '', maxLines: 2),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وەسفی بەرهەم - عەرەبی')),
                              _buildTextField(descArController, '', maxLines: 1),
                              const SizedBox(height: 14),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: imageBusy
                                      ? null
                                      : () {
                                          if (nameController.text.isNotEmpty) {
                                            final base = double.tryParse(priceController.text) ?? 0;
                                            final cost = double.tryParse(costController.text) ?? 0;
                                            if (cost < 0 || cost >= base) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(tx('نرخی فرۆشتن دەبێت لە نرخی کڕین زیاتر بێت'), textAlign: TextAlign.center),
                                                  backgroundColor: RC.bg(Color(0xFFDC2626)),
                                                ),
                                              );
                                              return;
                                            }
                                            widget.onAdd(Product(
                                              id: DateTime.now().toString(),
                                              name: nameController.text,
                                              category: selectedCategory,
                                              price: base,
                                              costPrice: cost,
                                              discountPrice: _priceFromPercent(base, selectedDiscountPct),
                                              imagePath: localImagePath,
                                              imageUrl: uploadedImageUrl,
                                            ));
                                            Navigator.pop(context);
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RC.bg(Color(0xFF00C853)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(t('تۆمارکردنی بەرهەم'),
                                    style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w900, fontSize: 14.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(tx(text), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: RC.fg(Colors.black))),
  );
  
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    Color? hintColor,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: txn(hint),
          hintStyle: TextStyle(color: hintColor ?? RC.bgn(Colors.grey[400]), fontSize: 12),
          filled: true,
          fillColor: RC.bg(Colors.white),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: RC.bg(Colors.grey[200]!)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: RC.bg(Color(0xFF00C853))),
          ),
        ),
      );

  Widget _buildDropdown({String? value, Function(String?)? onChanged}) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: RC.bg(Colors.white),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: RC.bg(Colors.grey[200]!)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        icon: Icon(Icons.keyboard_arrow_down, color: RC.fg(Colors.grey), size: 20),
        items: widget.categories.map((e) => DropdownMenuItem(value: e, child: Text(tx(e), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
        onChanged: onChanged,
        hint: Text(tx(widget.categories.isNotEmpty ? widget.categories.first : t('بەشێک هەڵبژێرە')), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: RC.fg(Colors.black))),
      ),
    ),
  );

  Widget _buildImagePicker({
    String? thumbnail,
    String? localImagePath,
    Uint8List? previewBytes,
    bool busy = false,
    String? errorText,
    VoidCallback? onTap,
  }) {
    Widget thumb;
    if (previewBytes != null) {
      thumb = Image.memory(
        previewBytes,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: RC.fg(Colors.grey), size: 28),
      );
    } else if (!kIsWeb && localImagePath != null && localImagePath.isNotEmpty) {
      thumb = Image.file(
        File(localImagePath),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: RC.fg(Colors.grey), size: 28),
      );
    } else if (thumbnail != null && thumbnail.isNotEmpty) {
      thumb = Image.network(
        thumbnail,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: RC.fg(Colors.grey), size: 28),
      );
    } else {
      thumb = Icon(Icons.add_photo_alternate_rounded, color: RC.fg(Color(0xFFEA580C)), size: 28);
    }

    final hasImage = previewBytes != null ||
        (localImagePath != null && localImagePath.isNotEmpty) ||
        (thumbnail != null && thumbnail.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 120,
              decoration: BoxDecoration(
                color: RC.bg(Color(0xFFFFF7ED)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: errorText != null
                      ? RC.bg(Color(0xFFE11D48))
                      : (hasImage ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFFED7AA))),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: thumb)),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        thumb,
                        const SizedBox(height: 8),
                        Text(
                          t('کرتە بکە بۆ هەڵبژاردنی وێنە'),
                          style: TextStyle(
                            color: RC.fg(Color(0xFF9A3412)),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  if (busy)
                    Container(
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0x880F172A)),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: RC.bg(Colors.white)),
                          const SizedBox(height: 8),
                          Text(
                            t('بارکردنی وێنە...'),
                            style: TextStyle(color: RC.fg(Colors.white), fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: RC.bg(Color(0xFFEA580C)),
              foregroundColor: RC.fg(Colors.white),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: RC.bg(Colors.white)),
                  )
                : Icon(hasImage ? Icons.sync_rounded : Icons.cloud_upload_rounded, size: 18),
            label: Text(
              tx(busy
                  ? t('بارکردنی وێنە...')
                  : (hasImage ? t('گۆڕینی وێنە') : t('هەڵبژاردن و بارکردنی وێنە'))),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            tx(errorText),
            style: TextStyle(color: RC.fg(Color(0xFFE11D48)), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class RevenueScreen extends StatefulWidget {
  final List<Order> orders;
  final Future<void> Function()? onRefresh;
  const RevenueScreen({super.key, required this.orders, this.onRefresh});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  int _selectedTabIndex = 0; // 0 today, 1 week, 2 month, 3 custom date
  int? _selectedBarIndex;
  DateTime? _customDate;
  Map<String, dynamic>? _analytics;
  bool _analyticsLoading = false;

  String _formatAmount(num value) {
    final intVal = value.round();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String get _apiPeriod => switch (_selectedTabIndex) {
        1 => 'week',
        2 => 'month',
        3 => 'today',
        _ => 'today',
      };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _analyticsLoading = true);
    final data = await VendorApiService.instance.fetchRevenueAnalytics(period: _apiPeriod);
    if (!mounted) return;
    setState(() {
      _analytics = data;
      _analyticsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<Order> filteredOrders;
    String periodTitle = t('ئەمڕۆ');
    String chartTitle = t('شیکاری فرۆشی کاتژمێری');
    List<String> chartLabels = ['١٠ب', '١٢ن', '٢پ', '٤ئ', '٦ئ', '٨ش', '١٠ش'];
    List<String> chartFullLabels = [
      '١٠:٠٠ بەیانی',
      '١٢:٠٠ نیوەڕۆ',
      '٠٢:٠٠ پاشنیوەڕۆ',
      '٠٤:٠٠ ئێوارە',
      '٠٦:٠٠ ئێوارە',
      '٠٨:٠٠ شەو',
      '١٠:٠٠ شەو',
    ];
    List<double> chartValues = [0, 0, 0, 0, 0, 0, 0];

    if (_selectedTabIndex == 0) {
      // 1. Today
      filteredOrders = widget.orders.where((o) =>
        o.timestamp.year == now.year &&
        o.timestamp.month == now.month &&
        o.timestamp.day == now.day
      ).toList();
      periodTitle = t('ئەمڕۆ');
      chartTitle = t('شیکاری فرۆشی کاتژمێری');
      chartLabels = ['١٠ب', '١٢ن', '٢پ', '٤ئ', '٦ئ', '٨ش', '١٠ش'];
      chartFullLabels = [
        '١٠:٠٠ بەیانی',
        '١٢:٠٠ نیوەڕۆ',
        '٠٢:٠٠ پاشنیوەڕۆ',
        '٠٤:٠٠ ئێوارە',
        '٠٦:٠٠ ئێوارە',
        '٠٨:٠٠ شەو',
        '١٠:٠٠ شەو',
      ];
      final hoursMap = [10, 12, 14, 16, 18, 20, 22];
      chartValues = List.generate(7, (i) {
        final targetHour = hoursMap[i];
        return filteredOrders
            .where((o) => (o.timestamp.hour - targetHour).abs() <= 1)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    } else if (_selectedTabIndex == 1) {
      // 2. This Week
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      filteredOrders = widget.orders.where((o) => o.timestamp.isAfter(sevenDaysAgo)).toList();
      periodTitle = t('ئەم هەفتەیە');
      chartTitle = t('شیکاری فرۆشی ٧ ڕۆژی ڕابردوو');
      chartLabels = ['شەم', 'یەک', 'دوو', 'سێ', 'چوار', 'پێنج', 'هەینی'];
      chartFullLabels = [
        'شەممە',
        'یەکشەممە',
        'دووشەممە',
        'سێشەممە',
        'چوارشەممە',
        'پێنجشەممە',
        'هەینی',
      ];
      chartValues = List.generate(7, (i) {
        final dayOffset = 6 - i;
        final d = now.subtract(Duration(days: dayOffset));
        return filteredOrders
            .where((o) => o.timestamp.year == d.year && o.timestamp.month == d.month && o.timestamp.day == d.day)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    } else if (_selectedTabIndex == 3 && _customDate != null) {
      final d = _customDate!;
      filteredOrders = widget.orders
          .where((o) =>
              o.timestamp.year == d.year &&
              o.timestamp.month == d.month &&
              o.timestamp.day == d.day)
          .toList();
      periodTitle = t('بەرواری دیاریکراو');
      chartTitle = t('شیکاری فرۆشی کاتژمێری');
      chartLabels = ['١٠ب', '١٢ن', '٢پ', '٤ئ', '٦ئ', '٨ش', '١٠ش'];
      chartFullLabels = chartLabels;
      final hoursMap = [10, 12, 14, 16, 18, 20, 22];
      chartValues = List.generate(7, (i) {
        final targetHour = hoursMap[i];
        return filteredOrders
            .where((o) => (o.timestamp.hour - targetHour).abs() <= 1)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    } else {
      // 3. This Month
      filteredOrders = widget.orders.where((o) =>
        o.timestamp.year == now.year && o.timestamp.month == now.month
      ).toList();
      periodTitle = t('ئەم مانگە');
      chartTitle = t('شیکاری فرۆشی ٤ هەفتەی ئەم مانگە');
      chartLabels = ['هەفتەی ١', 'هەفتەی ٢', 'هەفتەی ٣', 'هەفتەی ٤'];
      chartFullLabels = ['هەفتەی یەکەم', 'هەفتەی دووەم', 'هەفتەی سێیەم', 'هەفتەی چوارەم'];
      chartValues = List.generate(4, (weekIdx) {
        final startDay = weekIdx * 7 + 1;
        final endDay = (weekIdx + 1) * 7;
        return filteredOrders
            .where((o) => o.timestamp.day >= startDay && o.timestamp.day <= endDay)
            .fold<double>(0.0, (sum, o) => sum + o.total);
      });
    }

    final double baseSalesLocal = filteredOrders.fold<double>(0.0, (sum, o) => sum + o.total);
    final int baseOrdersLocal = filteredOrders.length;
    final api = _analytics;
    final commissionRatePct = (api?['commission_rate'] as num?)?.toDouble() ?? 20.0;

    // Aggregate Top Selling Products dynamically from filtered orders
    final Map<String, int> productCountMap = {};
    final Map<String, double> productRevMap = {};
    for (final o in filteredOrders) {
      for (final itemStr in o.items) {
        final parts = itemStr.split('x ');
        final qty = parts.length > 1 ? (int.tryParse(parts[0].trim()) ?? 1) : 1;
        final name = parts.length > 1 ? parts.sublist(1).join('x ').trim() : itemStr.trim();
        if (name.isNotEmpty) {
          productCountMap[name] = (productCountMap[name] ?? 0) + qty;
          productRevMap[name] = (productRevMap[name] ?? 0.0) + (o.total / (o.items.isNotEmpty ? o.items.length : 1));
        }
      }
    }

    final sortedProductNames = productCountMap.keys.toList()
      ..sort((a, b) => (productCountMap[b] ?? 0).compareTo(productCountMap[a] ?? 0));

    final int maxSold = sortedProductNames.isNotEmpty ? (productCountMap[sortedProductNames.first] ?? 1) : 1;
    final List<Map<String, dynamic>> topProducts = sortedProductNames.take(5).map((name) {
      final idx = sortedProductNames.indexOf(name) + 1;
      final sold = productCountMap[name] ?? 0;
      final rev = productRevMap[name] ?? 0.0;
      final kuNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      final rankKu = idx.toString().split('').map((c) => int.tryParse(c) != null ? kuNumbers[int.parse(c)] : c).join();
      return {
        'rank': rankKu,
        'name': name,
        'category': 'خواردن و بەرهەم',
        'sold': sold,
        'revenue': rev,
        'image': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&auto=format&fit=crop',
        'percent': maxSold > 0 ? (sold / maxSold).clamp(0.1, 1.0) : 1.0,
      };
    }).toList();

    // Prefer backend realized profit-share: admin_owed = gross_profit × %
    final totalSales = (api?['total_sales'] as num?)?.toDouble() ?? baseSalesLocal;
    final commission = (api?['admin_owed'] as num?)?.toDouble() ??
        (api?['admin_share'] as num?)?.toDouble() ??
        0.0;
    final netProfit = (api?['seller_share'] as num?)?.toDouble() ??
        (api?['net_profit'] as num?)?.toDouble() ??
        (totalSales - commission);
    final baseOrders = (api?['completed_orders_count'] as num?)?.toInt() ?? baseOrdersLocal;
    final avgTicket = baseOrders > 0
        ? ((api?['avg_ticket'] as num?)?.toDouble() ?? (totalSales / baseOrders))
        : 0.0;
    final growthText = baseOrders > 0 ? '+ ٪${(baseOrders * 3.2).toStringAsFixed(1)}' : '٪٠';
    final todayAdminOwed = (api?['today_admin_owed'] as num?)?.toInt() ?? commission.round();

    // Snapshot metrics for the top balance card (today / week / month / active).
    final todaySales = widget.orders
        .where((o) =>
            o.timestamp.year == now.year &&
            o.timestamp.month == now.month &&
            o.timestamp.day == now.day)
        .fold<double>(0, (s, o) => s + o.total);
    final weekSales = widget.orders
        .where((o) => o.timestamp.isAfter(now.subtract(const Duration(days: 7))))
        .fold<double>(0, (s, o) => s + o.total);
    final monthSales = widget.orders
        .where((o) => o.timestamp.year == now.year && o.timestamp.month == now.month)
        .fold<double>(0, (s, o) => s + o.total);
    final activeOrdersTotal = widget.orders
        .where((o) =>
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.accepted ||
            o.status == OrderStatus.preparing ||
            o.status == OrderStatus.ready)
        .fold<double>(0, (s, o) => s + o.total);
    final balanceTotal = (api?['seller_balance'] as num?)?.toDouble() ??
        (api?['lifetime_seller_share'] as num?)?.toDouble() ??
        netProfit;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        color: const Color(0xFFEA580C),
        onRefresh: () async {
          await widget.onRefresh?.call();
          await _loadAnalytics();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: RegaResponsive.pagePadding(context),
            vertical: 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('داهاتی فڕۆشیار'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: RC.fg(const Color(0xFF0F172A)),
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBalanceHeroCard(
                    balance: balanceTotal,
                    today: todaySales,
                    week: weekSales,
                    month: monthSales,
                    active: activeOrdersTotal,
                    loading: _analyticsLoading,
                  ),
                  const SizedBox(height: 14),
                  _buildTabs(),
                  const SizedBox(height: 14),
                  _buildStatsGrid(
                    totalSales: totalSales,
                    commission: commission,
                    netProfit: netProfit,
                    ordersCount: baseOrders,
                    commissionRatePct: commissionRatePct,
                  ),
                  const SizedBox(height: 14),
                  _buildTopProductsCard(topProducts),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBalanceHeroCard({
    required double balance,
    required double today,
    required double week,
    required double month,
    required double active,
    required bool loading,
  }) {
    Widget metric(String label, double value, {Color? valueColor, IconData? icon}) {
      return Expanded(
        child: Column(
          children: [
            Text(
              t(label),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: RC.fg(const Color(0xFF94A3B8)),
                fontFamily: kAppFontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: valueColor ?? RC.fg(const Color(0xFF0F172A))),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    '${_formatAmount(value)} ${t('دینار')}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: valueColor ?? RC.fg(const Color(0xFF0F172A)),
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(balance),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: RC.fg(const Color(0xFF0F172A)),
                    fontFamily: kAppFontFamily,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    t('دینار'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: RC.fg(const Color(0xFFEA580C)),
                      fontFamily: kAppFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              metric('فڕۆشی ئەمڕۆ', today),
              metric('فڕۆشی ئەم هەفتەیە', week),
              metric('فڕۆشی مانگ', month),
              metric(
                'داواکارییە چالاکەکان',
                active,
                valueColor: const Color(0xFF0F8A5F),
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required double totalSales,
    required double commission,
    required double netProfit,
    required int ordersCount,
    required double commissionRatePct,
  }) {
    final rateLabel = commissionRatePct.toStringAsFixed(commissionRatePct % 1 == 0 ? 0 : 1);
    Widget cell(String title, String value, {Color? valueColor}) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: RC.bg(Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RC.bg(const Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RC.fg(const Color(0xFF64748B)),
                  fontFamily: kAppFontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? RC.fg(const Color(0xFF0F172A)),
                  fontFamily: kAppFontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            cell(t('کۆی فرۆش'), '${_formatAmount(totalSales)} ${t('دینار')}'),
            cell(
              '${t('کۆمیسیۆن')} ($rateLabel٪)',
              '${_formatAmount(commission)}- ${t('دینار')}',
              valueColor: const Color(0xFFE11D48),
            ),
          ],
        ),
        Row(
          children: [
            cell(t('داهاتی سافی'), '${_formatAmount(netProfit)} ${t('دینار')}'),
            cell(t('داواکارییەکان'), '$ordersCount ${t('داواکاری')}'),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
  final refreshButton = GestureDetector(
          onTap: () async {
            await widget.onRefresh?.call();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t('داهاتی فرۆشیار نوێکرایەوە'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: RC.bg(Color(0xFFEA580C)),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
              boxShadow: [
                BoxShadow(
                  color: RC.bg(Colors.black).withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 18, color: RC.fg(Color(0xFFEA580C))),
                const SizedBox(width: 6),
                Text(
                  t('نوێکردنەوە'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: RC.fg(Color(0xFFEA580C)),
                  ),
                ),
              ],
            ),
          ),
  );

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('داهاتی فرۆشیار'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: RC.fg(Color(0xFF1E2024)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t('شیکاری وردی فرۆش و قازانجەکانت'),
              style: TextStyle(
                fontSize: 12,
                color: RC.fg(Color(0xFF8E8E93)),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < RegaBreakpoints.phone) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleColumn,
              const SizedBox(height: 10),
              Align(alignment: AlignmentDirectional.centerStart, child: refreshButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: titleColumn),
            refreshButton,
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _buildTabItem(0, t('ئەمڕۆ')),
          _buildTabItem(1, t('ئەم هەفتەیە')),
          _buildTabItem(2, t('ئەم مانگە')),
          _buildTabItem(3, t('بەرواری دیاریکراو')),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (index == 3) {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2023),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked == null) return;
            setState(() {
              _customDate = picked;
              _selectedTabIndex = 3;
              _selectedBarIndex = null;
            });
            _loadAnalytics();
            return;
          }
          setState(() {
            _selectedTabIndex = index;
            _selectedBarIndex = null;
          });
          _loadAnalytics();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? RC.bg(Color(0xFFEA580C)) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              tx(title),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? RC.bg(Colors.white) : RC.bg(Color(0xFF4B5563)),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required double netProfit,
    required double totalSales,
    required double commission,
    required int ordersCount,
    required double avgTicket,
    required String growthText,
    required String periodTitle,
    double commissionRatePct = 20,
    int todayAdminOwed = 0,
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFFFEDD5)), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Net Profit + Growth Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          t('صافی قازانج (قازانجی تۆ)'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: RC.fg(Color(0xFF9A3412)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: RC.bg(Color(0xFFFFF7ED)),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: RC.bg(Color(0xFFFED7AA))),
                          ),
                          child: Text(
                            tx(periodTitle),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: RC.fg(Color(0xFFEA580C)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            tx(_formatAmount(netProfit)),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: RC.fg(Color(0xFFEA580C)),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: RC.bg(Color(0xFFEA580C)),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              tx('د.ع'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: RC.fg(Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Growth badge with flipped arrow
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                decoration: BoxDecoration(
                  color: RC.bg(Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RC.bg(Color(0xFF16A34A)).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: RC.bg(Colors.black).withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.flip(
                      flipX: true,
                      child: Icon(Icons.trending_up, color: RC.fg(Color(0xFF16A34A)), size: 13),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      tx(growthText),
                      style: TextStyle(
                        color: RC.fg(Color(0xFF16A34A)),
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // Grid Metrics Card Inside
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            decoration: BoxDecoration(
              color: RC.bg(Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget divider() => Container(width: 1, height: 22, color: RC.bg(Color(0xFFE5E7EB)));
                final sales = _buildMetricCol(t('کۆی فرۆش'), '${_formatAmount(totalSales)} د.ع', RC.bg(Color(0xFF1E2024)));
                final commissionCol = _buildMetricCol(
                  'قەرزی ئەدمین (${commissionRatePct.toStringAsFixed(0)}٪)',
                  '${_formatAmount(commission)}- د.ع',
                  RC.bg(Color(0xFFD84315)),
                );
                final orders = _buildMetricCol(t('داواکارییەکان'), '$ordersCount دانە', RC.bg(Color(0xFF1E2024)));
                final avg = _buildMetricCol(t('تێکڕای فرۆش'), '${_formatAmount(avgTicket)} د.ع', RC.bg(Color(0xFFEA580C)));

                if (constraints.maxWidth < RegaBreakpoints.tablet) {
                  return Column(
                    children: [
                      Row(children: [sales, divider(), commissionCol]),
                      const SizedBox(height: 8),
                      Row(children: [orders, divider(), avg]),
                    ],
                  );
                }
                return Row(
                  children: [
                    sales,
                    divider(),
                    commissionCol,
                    divider(),
                    orders,
                    divider(),
                    avg,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFECFDF5)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RC.bg(Color(0xFF86EFAC))),
            ),
            child: Text(
              tx(loading
                  ? 'بارکردنی حیسابی قازانج…'
                  : 'ئەمڕۆ پێویستە بدرێت بە ئەدمین: ${_formatAmount(todayAdminOwed)} د.ع  (لەسەر قازانج، نەک فرۆش)'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: RC.fg(Color(0xFF166534))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color valueColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tx(label),
                style: TextStyle(
                  color: RC.fg(Color(0xFF6B7280)),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tx(value),
                style: TextStyle(
                  color: valueColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required List<String> labels,
    required List<String> fullLabels,
    required List<double> values,
  }) {
    int activeIndex = _selectedBarIndex ?? (values.length - 1);
    double maxVal = values.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal == 0) maxVal = 1;

    String highlightText = '${fullLabels[activeIndex]}: ${_formatAmount(values[activeIndex])} د.ع';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RC.bg(Color(0xFFFFF7ED)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bar_chart, color: RC.fg(Color(0xFFEA580C)), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tx(title),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: RC.fg(Color(0xFF1E2024)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: RC.bg(Color(0xFFFFF7ED)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: RC.bg(Color(0xFFFED7AA))),
                  ),
                  child: Text(
                    tx(highlightText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RC.fg(Color(0xFFEA580C)),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Bar Chart Row
          SizedBox(
            height: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (i) {
                bool isActive = i == activeIndex;
                double normalizedHeight = (values[i] / maxVal) * 90;
                if (normalizedHeight < 12) normalizedHeight = 12;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBarIndex = i;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isActive ? 28 : 22,
                          height: normalizedHeight,
                          decoration: BoxDecoration(
                            color: isActive ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFFFFEDD5)),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: RC.bg(Color(0xFFEA580C)).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tx(labels[i]),
                          style: TextStyle(
                            color: isActive ? RC.bg(Color(0xFFEA580C)) : RC.bg(Color(0xFF6B7280)),
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(List<Map<String, dynamic>> topProducts) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: RC.bg(Colors.black).withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final titleRow = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: RC.bg(Color(0xFFFFF3E0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.workspace_premium, color: RC.fg(Color(0xFFF06400)), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      t('پڕداهاتترین بەرهەمەکان'),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: RC.fg(Color(0xFF1E2024)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
              final subtitle = Text(
                t('بەپێی کۆی فرۆش'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: RC.fg(Color(0xFF8E8E93)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
              if (constraints.maxWidth < RegaBreakpoints.phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleRow,
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleRow),
                  const SizedBox(width: 6),
                  Flexible(child: subtitle),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          if (topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  t('هیچ فڕۆشێک تۆمار نەکراوە تا ئێستا'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RC.fg(const Color(0xFFCBD5E1)),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: kAppFontFamily,
                  ),
                ),
              ),
            )
          else
            ...topProducts.map((p) => _buildTopProductItem(p)),
        ],
      ),
    );
  }

  Widget _buildTopProductItem(Map<String, dynamic> item) {
    Color rankBg = const Color(0xFFF1F3F5);
    Color rankColor = RC.bg(Color(0xFF495057));

    if (item['rank'] == '١') {
      rankBg = RC.bg(Color(0xFFFFF8E1));
      rankColor = RC.bg(Color(0xFFFF8F00));
    } else if (item['rank'] == '٢') {
      rankBg = RC.bg(Color(0xFFECEFF1));
      rankColor = RC.bg(Color(0xFF546E7A));
    } else if (item['rank'] == '٣') {
      rankBg = RC.bg(Color(0xFFEFEBE9));
      rankColor = RC.bg(Color(0xFF6D4C41));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFFAFAF7)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RC.bg(Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: rankBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  tx(item['rank']),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item['image'],
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 44,
                    height: 44,
                    color: RC.bgn(Colors.grey[200]),
                    child: Icon(Icons.fastfood, color: RC.fg(Colors.grey), size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx(item['name']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: RC.fg(Color(0xFF1E2024)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx('${item['category']} • ${item['sold']} دانە فرۆشراوە'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: RC.fg(Color(0xFF6B7280)),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Revenue
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    tx('${_formatAmount(item['revenue'])} د.ع'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: RC.fg(Color(0xFFEA580C)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress line
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (item['percent'] as double).clamp(0.0, 1.0),
              backgroundColor: RC.bg(Color(0xFFE5E7EB)),
              valueColor: AlwaysStoppedAnimation<Color>(RC.bg(Color(0xFFEA580C))),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String businessName;
  final Function(String) onNameChange;
  final String language;
  final Function(String) onLangChange;

  const SettingsScreen({
    super.key, 
    required this.businessName, 
    required this.onNameChange,
    required this.language,
    required this.onLangChange,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController nameController;
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 23, minute: 0);

  String? _coverUrl;
  String? _logoUrl;
  Uint8List? _coverPreview;
  Uint8List? _logoPreview;
  bool _coverBusy = false;
  bool _logoBusy = false;
  bool _saving = false;

  Future<void> _pickStoreImage({required bool isCover}) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RC.bg(Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: Trans.direction,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('هەڵبژاردنی وێنە'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: RC.fg(Color(0xFF1E293B)))),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.camera_alt_rounded, color: RC.fg(Color(0xFFFF9800))),
                  title: Text(t('کامێرا')),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: RC.fg(Color(0xFFFF9800))),
                  title: Text(t('گالەری')),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      if (isCover) {
        _coverBusy = true;
      } else {
        _logoBusy = true;
      }
    });
    try {
      final picked = await pickVendorImage(fromCamera: source == ImageSource.camera);
      if (picked == null || !mounted) {
        if (mounted) {
          setState(() {
            if (isCover) {
              _coverBusy = false;
            } else {
              _logoBusy = false;
            }
          });
        }
        return;
      }
      final compressed = await ImageCompressService.compressForUpload(
        name: picked.name.isNotEmpty ? picked.name : (isCover ? 'cover.jpg' : 'logo.jpg'),
        bytes: picked.bytes,
      );
      final up = await VendorApiService.instance.uploadMedia(compressed.bytes, compressed.name);
      final url = up['url']?.toString();
      if (url == null || url.isEmpty) throw Exception(t('بارکردنی وێنە سەرکەوتوو نەبوو'));
      if (!mounted) return;
      setState(() {
        if (isCover) {
          _coverUrl = url;
          _coverPreview = compressed.bytes;
          _coverBusy = false;
        } else {
          _logoUrl = url;
          _logoPreview = compressed.bytes;
          _logoBusy = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isCover) {
          _coverBusy = false;
        } else {
          _logoBusy = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx(e.toString())), backgroundColor: RC.bg(const Color(0xFFD32F2F))),
      );
    }
  }

  Widget _buildImageSubCard({
    required String title,
    required String buttonText,
    required Uint8List? previewBytes,
    required String? existingUrl,
    required IconData defaultIcon,
    required VoidCallback onPick,
    required bool busy,
    bool isWide = false,
  }) {
    final double width = isWide ? 72 : 52;
    const double height = 52;
    Widget preview;
    if (busy) {
      preview = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (previewBytes != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.memory(previewBytes, fit: BoxFit.cover, width: width, height: height),
      );
    } else if (existingUrl != null && existingUrl.trim().isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          VendorApiService.instance.resolveMediaUrl(existingUrl),
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => Icon(defaultIcon, color: RC.fgn(Colors.grey[400]), size: 22),
        ),
      );
    } else {
      preview = Icon(defaultIcon, color: RC.fgn(Colors.grey[400]), size: isWide ? 26 : 22);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RC.bg(Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RC.bg(Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(title),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: RC.fg(Color(0xFF1F2937))),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: busy ? null : onPick,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: RC.bg(Colors.white),
                    border: Border.all(color: RC.bg(Colors.grey[300]!)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: preview),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPick,
                  icon: Icon(Icons.upload_outlined, size: 16, color: RC.fg(Color(0xFF00897B))),
                  label: Text(
                    tx(buttonText),
                    style: TextStyle(
                      color: RC.fg(Color(0xFF1F2937)),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: RC.bg(Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: RC.bg(Colors.grey[300]!)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.businessName);
    _loadStoreImages();
  }

  Future<void> _loadStoreImages() async {
    try {
      final store = await VendorApiService.instance.fetchStoreProfile();
      if (!mounted || store == null) return;
      setState(() {
        _coverUrl = store['cover_url']?.toString();
        _logoUrl = store['logo_url']?.toString();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  String formatTime(TimeOfDay time) {
    final int hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final String period = time.hour >= 12 ? 'PM' : 'AM';
    final String min = time.minute.toString().padLeft(2, '0');
    final String hr = hour.toString().padLeft(2, '0');
    return '$period $hr:$min';
  }

  Future<void> _selectTime(BuildContext context, bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isOpenTime) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Trans.direction,
      child: ColoredBox(
        color: RC.bg(const Color(0xFFF3F4F6)),
        child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: RegaResponsive.pagePadding(context),
          vertical: 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
            // TB: title inside white card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: RC.bg(Colors.white),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                t('ڕێکخستنی دوکان'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: RC.fg(const Color(0xFF0F172A)),
                  fontFamily: kAppFontFamily,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Working Hours
            _buildSectionCard(
              title: t('کاتی کارکردن'),
              icon: Icons.access_time,
              iconColor: RC.fg(Color(0xFF00897B)),
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel(t('کاتی کردنەوە')),
                          GestureDetector(
                            onTap: () => _selectTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFF9FAFB)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RC.bg(Colors.grey[200]!)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx(formatTime(_openTime)),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RC.fg(Color(0xFF1F2937))),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: RC.fgn(Colors.grey[400]), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel(t('کاتی داخستن')),
                          GestureDetector(
                            onTap: () => _selectTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: RC.bg(Color(0xFFF9FAFB)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RC.bg(Colors.grey[200]!)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tx(formatTime(_closeTime)),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RC.fg(Color(0xFF1F2937))),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: RC.fgn(Colors.grey[400]), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Language
            _buildSectionCard(
              title: t('زمانی بەرنامە'),
              icon: Icons.translate,
              iconColor: RC.fg(Color(0xFFF06400)),
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _buildLangBtn(t('کوردی'), 'ku'),
                    const SizedBox(width: 8),
                    _buildLangBtn('عربي', 'ar'),
                    const SizedBox(width: 8),
                    _buildLangBtn('English', 'en'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          final name = nameController.text.trim();
                          widget.onNameChange(name);
                          await VendorApiService.instance.updateStoreInfo(
                            nameKu: name.isEmpty ? widget.businessName : name,
                            openTime: formatTime(_openTime),
                            closeTime: formatTime(_closeTime),
                            coverUrl: _coverUrl,
                            logoUrl: _logoUrl,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('گۆڕانکارییەکان پاشەکەوت کران'))),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tx(e.toString())),
                              backgroundColor: RC.bg(const Color(0xFFD32F2F)),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(const Color(0xFF16A34A)),
                  foregroundColor: RC.fg(Colors.white),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _saving ? t('چاوەڕوان بە...') : t('پاشەکەوتکردنی گۆڕانکارییەکان'),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: kAppFontFamily),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<VendorSessionNotifier>().logout();
                  if (context.mounted) context.go('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: RC.bg(const Color(0xFFE55B5B)),
                  foregroundColor: RC.fg(Colors.white),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t('چوونە دەرەوە لە هەژمار'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: kAppFontFamily),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.logout_rounded, color: RC.fg(Colors.white), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  ),
      ),
      ),
);
  }

  Widget _buildThemeBtn(String label, IconData icon, bool dark, bool current) {
    final selected = dark == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => Trans.setDark(dark),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? RC.bg(Color(0xFFF06400)) : RC.bg(const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RC.bg(Color(0xFFF06400)) : RC.bg(const Color(0xFFE5E7EB)),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? RC.fg(Colors.white) : RC.fg(const Color(0xFF1F2937))),
              const SizedBox(width: 6),
              Text(
                tx(label),
                style: TextStyle(
                  color: selected ? RC.bg(Colors.white) : RC.fg(const Color(0xFF1F2937)),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangBtn(String label, String code) {
    bool isSelected = widget.language == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onLangChange(code),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? RC.bg(Color(0xFFF06400)) : RC.bg(Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? RC.bg(Color(0xFFF06400)) : RC.bg(Colors.grey[200]!),
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: RC.bg(Color(0xFFF06400)).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              tx(label),
              style: TextStyle(
                color: isSelected ? RC.bg(Colors.white) : RC.bgn(Colors.grey[800]),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Color? iconColor,
    String? badge,
    required List<Widget> children,
  }) {
    final badgeWidget = badge == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: RC.bg(Color(0xFFFFF3E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tx(badge),
              style: TextStyle(
                color: RC.fg(Color(0xFFE65100)),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RC.bg(Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RC.bg(Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleRow = Row(
                children: [
                  Icon(icon, color: iconColor ?? RC.fg(Color(0xFF00897B)), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx(title),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RC.fg(Color(0xFF111827))),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
              if (badgeWidget == null) return titleRow;
              if (constraints.maxWidth < RegaBreakpoints.phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleRow,
                    const SizedBox(height: 8),
                    Align(alignment: AlignmentDirectional.centerStart, child: badgeWidget),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleRow),
                  const SizedBox(width: 8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        tx(text),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: RC.fg(Color(0xFF1F2937))),
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return TextField(
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: txn(hint),
        hintStyle: TextStyle(color: RC.fgn(Colors.grey[400]), fontSize: 13),
        filled: true,
        fillColor: RC.bgn(Colors.grey[50]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RC.bg(Colors.grey[200]!)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: RC.bg(Colors.grey[200]!)),
        ),
      ),
    );
  }
}
