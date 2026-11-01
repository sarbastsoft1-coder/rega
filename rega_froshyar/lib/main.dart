import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import "package:flutter/foundation.dart";
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'vendor_api_service.dart';

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
  static Future<void> playNewOrderAlert({bool soundEnabled = true}) async {
    if (!soundEnabled) return;
    try {
      // Play actual music / ringtone sound via AudioPlayer
      await _audioPlayer.stop();
      await _audioPlayer.setSource(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing AudioPlayer sound: $e');
    }

    try {
      // Haptic and system alerts
      for (int i = 0; i < 4; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 350));
      }
    } catch (e) {
      debugPrint('Error playing system alert: $e');
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
const String kAppFontFamily = 'Noto Kufi Arabic';


class Trans {
  static final ValueNotifier<String> lang = ValueNotifier<String>('ku');
  static void setLang(String l) => lang.value = l;
  static TextDirection get direction => lang.value == 'en' ? TextDirection.ltr : TextDirection.rtl;

  static String get(String key) {
    if (lang.value == 'ku') return key;
    return _dict[key]?[lang.value] ?? key;
  }

  static final Map<String, Map<String, String>> _dict = {
     'ڕێکخستن': {'en': 'Settings', 'ar': 'الإعدادات'},
     'داهاتی فرۆشیار': {'en': 'Vendor Revenue', 'ar': 'إيرادات البائع'},
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
     'لە ئامادەکردندایە': {'en': 'Preparing', 'ar': 'جاري التجهيز'},
     'ئامادەیە بۆ شۆفێر': {'en': 'Ready for Driver', 'ar': 'جاهز للسائق'},
     'تەواو': {'en': 'Completed', 'ar': 'مكتمل'},
     'پاشگەزبوونەوە': {'en': 'Cancelled', 'ar': 'ملغى'},
     'ڕەتکردنەوە': {'en': 'Reject', 'ar': 'رفض'},
     'قبولکردن': {'en': 'Accept', 'ar': 'قبول'},
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
     'پاشگەزبونەوە': {'en': 'Cancel', 'ar': 'إلغاء'},
     'زیادکردن': {'en': 'Add', 'ar': 'إضافة'},
     'دەستکاریکردنی بەرهەم': {'en': 'Edit Product', 'ar': 'تعديل المنتج'},
     'ناوی بەرهەم *': {'en': 'Product Name *', 'ar': 'اسم المنتج *'},
     'بەش / پۆڵێن *': {'en': 'Category *', 'ar': 'القسم / التصنيف *'},
     'بەشێک هەڵبژێرە': {'en': 'Select Category', 'ar': 'اختر القسم'},
     'نرخی ئاسایی *': {'en': 'Regular Price *', 'ar': 'السعر العادي *'},
     'نرخی دوای داشکان': {'en': 'Price after Discount', 'ar': 'السعر بعد الخصم'},
     'وەسفی بەرهەم - کوردی (ئارەزوومەندانە)': {'en': 'Product Description - Kurdish (Optional)', 'ar': 'وصف المنتج - كردي (اختياري)'},
     'وەسفی بەرهەم - عەرەبی': {'en': 'Product Description - Arabic', 'ar': 'وصف المنتج - عربي'},
     'وێنەی بەرهەم': {'en': 'Product Image', 'ar': 'صورة المنتج'},
     'هەڵبژاردنی فایل': {'en': 'Choose File', 'ar': 'اختر ملف'},
     'هیچ فایلێک دیاری نەکراوە': {'en': 'No file selected', 'ar': 'لم يتم تحديد ملف'},
     'بەردەست': {'en': 'Available', 'ar': 'متاح'},
     'بەردەستە': {'en': 'Available', 'ar': 'متاح'},
     'نابەردەست': {'en': 'Unavailable', 'ar': 'غير متاح'},
     'تۆمارکردنی بەرهەم': {'en': 'Save Product', 'ar': 'حفظ المنتج'},
     'هیچ بەرهەمێک نەدۆزرایەوە': {'en': 'No Products Found', 'ar': 'لم يتم العثور على منتجات'},
     'دەتوانیت بە کلیک لەسەر دوگمەی (بەرهەمی نوێ) یەکەمین کاڵا زیادبکەیت.': {'en': 'You can add your first item by clicking (Add Product).', 'ar': 'يمكنك إضافة العنصر الأول بالنقر على (إضافة منتج).'},
     'پانیڵى بەڕێوەبردنى فرۆشیاران (REGA Vendor)': {'en': 'Vendor Management Panel (REGA Vendor)', 'ar': 'لوحة إدارة البائعين (REGA Vendor)'},
     'بەخێر بێیت بۆ ئەپی ڕێگا': {'en': 'Welcome to REGA App', 'ar': 'أهلاً بك في تطبيق ريجا'},
     'ژمارەی مۆبایل': {'en': 'Mobile Number', 'ar': 'رقم الموبايل'},
     'وشەی تێپەڕ': {'en': 'Password', 'ar': 'كلمة المرور'},
     'چوونە ژوورەوە': {'en': 'Log In', 'ar': 'تسجيل الدخول'},
     'هێشتا نەبوویتە فرۆشیار لە ئەپی ڕێگا': {'en': 'Not a vendor in REGA App yet?', 'ar': 'لست بائعاً في تطبيق ريجا بعد؟'},
     'خۆت تۆمار بکە': {'en': 'Register', 'ar': 'سجل الآن'},
     'کراوەیە': {'en': 'Open', 'ar': 'مفتوح'},
     'داخراوە': {'en': 'Closed', 'ar': 'مغلق'},
  };
}

String t(String key) => Trans.get(key);

void main() {
  runApp(const RegaVendorApp());
}

class RegaVendorApp extends StatelessWidget {
  const RegaVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Trans.lang,
      builder: (context, currentLang, child) {
        return MaterialApp(
          title: 'REGA Vendor',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.orange,
            fontFamily: GoogleFonts.notoKufiArabic().fontFamily,
            textTheme: GoogleFonts.notoKufiArabicTextTheme(
              ThemeData.light().textTheme,
            ),
            primaryTextTheme: GoogleFonts.notoKufiArabicTextTheme(
              ThemeData.light().textTheme,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            // پاراستنی ئەپ لە گەورەبوونی فۆنت لە ڕێکخستنی مۆبایلەکان کە دەبێتە هۆی تێکچوونی دیزاین
            final clampedTextScaler = mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedTextScaler),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Directionality(
                    textDirection: Trans.direction,
                    child: child!,
                  ),
                ),
              ),
            );
          },
          home: const LoginScreen(),
        );
      },
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
    _phoneController = TextEditingController(text: '07701112233');
    _passwordController = TextEditingController(text: 'password123');

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
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Logo Badge
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: _TopBarLogoWidget(
                            primaryPath: kAppLogoFilePath,
                            height: 64,
                            fallbackColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. Welcome Title & Subtitle
                      Text(
                        t('بەخێر بێیت بۆ ئەپی ڕێگا'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('پانیڵى بەڕێوەبردنى فرۆشیاران (REGA Vendor)'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // 3. Mobile Number Field
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_iphone_rounded, size: 18, color: Color(0xFFEA580C)),
                            const SizedBox(width: 8),
                            Text(
                              t('ژمارەی مۆبایل'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '0750 000 0000',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Password Field
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFEA580C)),
                            const SizedBox(width: 8),
                            Text(
                              t('وشەی تێپەڕ'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF334155),
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
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF94A3B8)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 19,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 5. Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => MainNavigationScreen(initialIndex: 3, loginPhone: _phoneController.text, loginPassword: _passwordController.text)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: const Color(0x40EA580C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t('چوونە ژوورەوە'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Directionality(
                                textDirection: TextDirection.ltr,
                                child: Icon(
                                  Icons.arrow_right_alt_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // 6. Register Section
                      Text(
                        t('هێشتا نەبوویتە فرۆشیار لە ئەپی ڕێگا'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 7. Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(t('تۆمارکردنی فرۆشگای نوێ'), style: const TextStyle(fontWeight: FontWeight.w900)),
                                content: Text(t('بۆ بەشداریکردن و کردنەوەی هەژماری فرۆشیار لە ڕێگا، تکایە پەیوەندی بە تیمی پشتگیرییەوە بکە یان سەردانی نووسینگەمان بکە.')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(t('باشە'), style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront_outlined, color: Color(0xFFEA580C), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                t('خۆت تۆمار بکە'),
                                style: const TextStyle(
                                  color: Color(0xFFEA580C),
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
    this.discountPrice,
    this.isAvailable = true,
    this.description,
    this.imagePath,
    this.imageUrl,
  });
}

enum OrderStatus { pending, preparing, ready, completed, rejected }

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

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.timestamp,
    this.customerName = 'محەمەد عەلی',
    this.customerPhone = '0770 123 4567',
    this.deliveryAddress = 'کەلار - گەڕەکی سیروان',
    this.handoverPin = '4821',
    this.customerNotes,
    this.dbId,
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
  bool _isOnline = true;
  bool _soundEnabled = true;
  String _language = 'ku';
  String _businessName = t('فرۆشگا');
  Timer? _simulationTimer;
  Timer? _backendPollTimer;
  final Set<int> _seenBackendOrderIds = {};
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _startOrderSimulationTimer();
    _initBackendVendorSync();
  }

  void _startOrderSimulationTimer() {
    _simulationTimer?.cancel();
    _backendPollTimer?.cancel();
    // Simulate periodic incoming orders when the store is online
    _simulationTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (_isOnline && mounted) {
        _simulateNewOrder(isAuto: true);
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _backendPollTimer?.cancel();
    super.dispose();
  }
  
  // Central State
  final List<String> _categories = ['پیتزاکان', 'بەرگرەکان', 'خواردنەوەکان', 'کریسپی', 'پاشکۆکان'];
  final List<Product> _products = [
    Product(
      id: '1',
      name: 'پیتزا پێپەرۆنی',
      category: 'پیتزاکان',
      price: 8500,
      description: 'پیتزای ئیتالی بە پێپەرۆنی گۆش...',
      imageUrl: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500&auto=format&fit=crop',
    ),
    Product(
      id: '2',
      name: 'بەرگر گۆشت',
      category: 'بەرگرەکان',
      price: 6000,
      description: 'بەرگری گۆشتی فریش لەگەڵ...',
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop',
    ),
    Product(
      id: '3',
      name: 'کۆکا کۆلا',
      category: 'خواردنەوەکان',
      price: 1000,
      description: 'خواردنەوەی گازی سارد و فرێش...',
      imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop',
    ),
    Product(
      id: '4',
      name: 'کریسپی مریشک',
      category: 'کریسپی',
      price: 7500,
      description: 'پارچە مریشکی کریسپی بە تامی تایبەت...',
      imageUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&auto=format&fit=crop',
    ),
  ];

  final List<Order> _orders = [
    Order(
      id: 'RA-9001#',
      items: ['1x پیتزا پێپەرۆنی', '2x کۆکا کۆلا'],
      total: 11150,
      status: OrderStatus.pending,
      timestamp: DateTime(2026, 10, 14, 19, 6),
      customerName: 'محەمەد عەلی',
      customerPhone: '0770 123 4567',
      deliveryAddress: 'کەلار - گەڕەکی سیروان',
      handoverPin: '4821',
      customerNotes: 'تکایە پیتزاکە بە گەرمی بگات و کەمێک برژاوتر بێت',
    ),
    Order(
      id: 'RA-9002#',
      items: ['1x بەرگر گۆشت'],
      total: 7500,
      status: OrderStatus.preparing,
      timestamp: DateTime(2026, 10, 14, 19, 6),
      customerName: 'ئاراس ئەحمەد',
      customerPhone: '0750 987 6543',
      deliveryAddress: 'کەلار - شەقامی سەرەکی',
      handoverPin: '6319',
      customerNotes: 'سۆسی زیادەی لەگەڵ بێت تکایە',
    ),
    Order(
      id: 'RA-9003#',
      items: ['2x کریسپی مریشک'],
      total: 15000,
      status: OrderStatus.ready,
      timestamp: DateTime(2026, 10, 8, 21, 30),
      customerName: 'دیار کەریم',
      customerPhone: '0771 456 7890',
      deliveryAddress: 'کەلار - بەردەم باخی گشتی',
      handoverPin: '2904',
      customerNotes: 'سۆسی زیادەی لەگەڵ بێت',
    ),
    Order(
      id: 'RA-9004#',
      items: ['1x پیتزا سەوزە', '1x ئاوی کانزایی'],
      total: 7500,
      status: OrderStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      customerName: 'ڕێبین سالار',
      customerPhone: '0770 333 2211',
      deliveryAddress: 'کەلار - گەڕەکی شەهیدان',
      handoverPin: '5178',
    ),
    Order(
      id: 'RA-9005#',
      items: ['3x کۆکا کۆلا'],
      total: 3000,
      status: OrderStatus.pending,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      customerName: 'سۆران مەحمود',
      customerPhone: '0750 111 4455',
      deliveryAddress: 'کەلار - گەڕەکی ڕزگاری',
      handoverPin: '8240',
      customerNotes: 'تکایە بە ساردی و بە پەلە بگات',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  OrderStatus _mapBackendVendorStatus(String raw) {
    switch (raw) {
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

  Future<void> _initBackendVendorSync() async {
    try {
      if (widget.loginPhone != null && widget.loginPhone!.trim().isNotEmpty) {
        await VendorApiService.instance.login(
          widget.loginPhone!,
          widget.loginPassword ?? 'password123',
        );
      } else {
        await VendorApiService.instance.ensureAuthenticated();
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
        if (cats.isNotEmpty) {
          _categories
            ..clear()
            ..addAll(cats.map((c) => (c as Map<String, dynamic>)['name_ku']?.toString() ?? '').where((s) => s.isNotEmpty));
        }
        if (prods.isNotEmpty) {
          _products
            ..clear()
            ..addAll(prods.map((raw) {
              final p = raw as Map<String, dynamic>;
              return Product(
                id: '${p['id']}',
                name: p['name_ku']?.toString() ?? '',
                category: p['store_category']?['name_ku']?.toString() ?? (_categories.isNotEmpty ? _categories.first : 'گشتی'),
                price: ((p['price'] as num?) ?? 0).toDouble(),
                discountPrice: (p['discount_price'] as num?)?.toDouble(),
                isAvailable: p['is_available'] == true,
                description: p['description_ku']?.toString(),
                imageUrl: p['image_url']?.toString(),
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
      if (!mounted || list.isEmpty) return;

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

        parsed.add(
          Order(
            id: '${m['order_number'] ?? 'RA-$dbId'}#',
            dbId: dbId,
            items: itemsList.isEmpty ? ['1x داواکاری'] : itemsList,
            total: ((m['subtotal'] ?? m['total_amount'] ?? 0) as num).toDouble(),
            status: _mapBackendVendorStatus(vStatus),
            timestamp: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
            customerName: m['customer_name']?.toString() ?? m['customer']?['name']?.toString() ?? 'کڕیار',
            customerPhone: m['customer_phone']?.toString() ?? m['customer']?['phone']?.toString() ?? '',
            deliveryAddress: m['delivery_address']?.toString() ?? 'کەلار',
            handoverPin: '0000',
            customerNotes: m['customer_notes']?.toString(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(parsed);
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
    setState(() {
      final product = _products.firstWhere((p) => p.id == id);
      product.isAvailable = !product.isAvailable;
      final pid = int.tryParse(id);
      if (pid != null) {
        VendorApiService.instance.toggleProductAvailability(pid);
      }
    });
  }

  void _deleteProduct(String id) {
    setState(() {
      _products.removeWhere((p) => p.id == id);
      final pid = int.tryParse(id);
      if (pid != null) {
        VendorApiService.instance.deleteProduct(pid);
      }
    });
  }

  void _updateOrderStatus(String id, OrderStatus newStatus) {
    setState(() {
      final order = _orders.firstWhere((o) => o.id == id);
      order.status = newStatus;
      final dbId = order.dbId;
      if (dbId != null) {
        if (newStatus == OrderStatus.preparing) {
          VendorApiService.instance.acceptOrder(dbId);
        } else if (newStatus == OrderStatus.ready) {
          VendorApiService.instance.markReady(dbId);
        } else if (newStatus == OrderStatus.rejected) {
          VendorApiService.instance.rejectOrder(dbId);
        }
      }
    });
  }

  void _addProduct(Product product) {
    setState(() {
      _products.add(product);
      VendorApiService.instance.addProduct(
        nameKu: product.name,
        categoryName: product.category,
        price: product.price.round(),
        discountPrice: product.discountPrice?.round(),
        descriptionKu: product.description,
        imageUrl: product.imageUrl,
        isAvailable: product.isAvailable,
      ).then((saved) {
        if (saved != null && mounted) _initBackendVendorSync();
      });
    });
  }

  void _addCategory(String category) {
    setState(() {
      if (!_categories.contains(category)) {
        _categories.add(category);
        VendorApiService.instance.addCategory(category);
      }
    });
  }

  void _deleteCategory(String category) {
    setState(() {
      _categories.remove(category);
      VendorApiService.instance.deleteCategoryByName(category);
    });
  }

  void _editProduct(Product product) {
    setState(() {
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        final pid = int.tryParse(product.id);
        if (pid != null) {
          VendorApiService.instance.updateProduct(
            productId: pid,
            nameKu: product.name,
            categoryName: product.category,
            price: product.price.round(),
            discountPrice: product.discountPrice?.round(),
            descriptionKu: product.description,
            imageUrl: product.imageUrl,
            isAvailable: product.isAvailable,
          );
        }
      }
    });
  }

  void _simulateNewOrder({bool isAuto = false}) {
    final randNum = Random().nextInt(9000) + 1000;
    final id = 'RA-$randNum#';

    final sampleItems = [
      ['1x پیتزا مەرگەریتا', '1x ئاوی کانزایی'],
      ['2x بەرگر گۆشت', '1x پەتاتەی فڕێندراو'],
      ['1x کریسپی مریشک', '2x کۆکا کۆلا'],
      ['1x پیتزا پێپەرۆنی', '1x سۆسی سیر'],
    ];
    final selectedMeal = sampleItems[Random().nextInt(sampleItems.length)];
    final sampleCustomers = ['ئەحمەد فەرهاد', 'شەونم عەلی', 'هێمن قادر', 'ڕێزان کامەران', 'کاروان محەمەد'];
    final customerName = sampleCustomers[Random().nextInt(sampleCustomers.length)];
    final sampleAddresses = ['کەلار - گەڕەکی سیروان', 'کەلار - گەڕەکی شەهیدان', 'کەلار - گەڕەکی ڕزگاری', 'کەلار - شەقامی سەرەکی'];
    final address = sampleAddresses[Random().nextInt(sampleAddresses.length)];
    final sampleNotes = [
      'تکایە پیتزاکە بە گەرمی بگات',
      'سۆسی زیادەی لەگەڵ بێت تکایە',
      'تکایە زەنگی دەرگا لێمەدەن، پەیوەندی بکەن',
      'تکایە کەمێک برژاوتر بێت',
      'بیبەری تیژی لەگەڵ نەبێت تکایە',
    ];
    final note = sampleNotes[Random().nextInt(sampleNotes.length)];

    setState(() {
      _orders.insert(0, Order(
        id: id,
        items: selectedMeal,
        total: ((Random().nextInt(7) + 4) * 1500).toDouble(),
        status: OrderStatus.pending,
        timestamp: DateTime.now(),
        customerName: customerName,
        customerPhone: '0770 ${Random().nextInt(899) + 100} ${Random().nextInt(8999) + 1000}',
        deliveryAddress: address,
        handoverPin: '${Random().nextInt(8999) + 1000}',
        customerNotes: note,
      ));
    });

    // 🔔 لێدانی دەنگی ئاگادارکردنەوە لە مۆبایل کاتێک داواکاری نوێ هات
    if (_soundEnabled) {
      OrderSoundService.playNewOrderAlert(soundEnabled: _soundEnabled);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${t('داواکارییەکی نوێ هات!')} ($id)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00894C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
      RevenueScreen(orders: _orders),
      ProductsScreen(
        products: _products, 
        categories: _categories,
        onToggle: _toggleProductAvailability,
        onDelete: _deleteProduct,
        onAdd: _addProduct,
        onEdit: _editProduct,
        onAddCategory: _addCategory,
        onDeleteCategory: _deleteCategory,
      ),
      OrdersScreen(
        orders: _orders,
        onUpdateStatus: _updateOrderStatus,
        onSimulate: _simulateNewOrder,
      ),
    ];

    bool isRtl = _language != 'en';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: 80,
            titleSpacing: 14,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFEA580C)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            title: SizedBox(
              width: double.infinity,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Right Side in RTL (Start): Store Logo & Store Name
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                Positioned(
                                  bottom: -1,
                                  right: -1,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFD97706), width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _businessName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Left Side in RTL (End): Sound Toggle & Operational Switch
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sound Button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _soundEnabled = !_soundEnabled;
                              });
                              if (_soundEnabled) {
                                OrderSoundService.playTestTone();
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('دەنگی ئاگادارکردنەوەی داواکاری چالاک کرا 🔔', textAlign: TextAlign.center),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('دەنگی ئاگادارکردنەوە بێدەنگ کرا 🔕', textAlign: TextAlign.center),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _soundEnabled
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _soundEnabled
                                      ? Colors.white.withOpacity(0.35)
                                      : Colors.white.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                                color: _soundEnabled ? Colors.white : Colors.white70,
                                size: 19,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Online/Offline Operational Switch
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isOnline = !_isOnline;
                                VendorApiService.instance.updateOnlineStatus(_isOnline);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40,
                                    height: 22,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: _isOnline ? const Color(0xFF10B981) : Colors.black45,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 3,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Center: App Logo (بارکردنی لۆگۆ لە فایلی پڕۆژەکە یان ئۆنلاین)
                  _buildTopLogo(),
                ],
              ),
            ),
          ),
        ),
        body: screens[_selectedIndex],
        bottomNavigationBar: Container(
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 16,
            left: 8,
            right: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED), // Warm light orange tint matching bg-orange-50/95
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFFED7AA).withOpacity(0.8), // border-orange-200/80
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFB923C).withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Far Right in RTL: داواکارییەکان (Orders) - index 3
              Expanded(child: _buildNavItem(3, Icons.shopping_basket_outlined, t('داواکارییەکان'))),
              // 2. Next in RTL: مێنۆ و بەرهەم (Menu & Products) - Chef hat - index 2
              Expanded(child: _buildNavItem(2, Icons.soup_kitchen_outlined, t('مێنۆ و بەرهەم'))),
              // 3. Next in RTL: داهاتی فرۆشیار (Seller Revenue) - Trending up line - index 1
              Expanded(child: _buildNavItem(1, Icons.trending_up_rounded, t('داهاتی فرۆشیار'))),
              // 4. Far Left in RTL: ڕێکخستن (Settings) - Sliders / Tune - index 0
              Expanded(child: _buildNavItem(0, Icons.tune_rounded, t('ڕێکخستن'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    // Notification badge on orders (index 3) when there are pending orders
    final pendingCount = _orders.where((o) => o.status == OrderStatus.pending).length;
    bool hasNotification = (index == 3 && pendingCount > 0);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF97316) : Colors.transparent, // orange-500
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF97316).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: index == 1
                      ? Transform.flip(
                          flipX: true,
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.white : const Color(0xFF6B7280), // gray-500
                            size: 22,
                          ),
                        )
                      : Icon(
                          icon,
                          color: isSelected ? Colors.white : const Color(0xFF6B7280), // gray-500
                          size: 22,
                        ),
                ),
                if (hasNotification)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E), // rose-500
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$pendingCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF6B7280), // orange-600 vs gray-500
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Tiny indicator dot underneath active tab matching screenshot
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF97316) : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
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
      ),
    );
  }
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
    final effectiveColor = fallbackColor ?? Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'REGA',
          style: TextStyle(
            color: effectiveColor,
            fontSize: height > 55 ? 18 : 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          'ڕێگا',
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
    barrierColor: Colors.black.withOpacity(0.85),
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null && title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
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
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    minScale: 0.8,
                    child: imageProvider != null
                        ? Image(
                            image: imageProvider,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 64),
                          )
                        : Image.network(
                            imageUrl ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 64),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class OrdersScreen extends StatelessWidget {
  final List<Order> orders;
  final Function(String, OrderStatus) onUpdateStatus;
  final VoidCallback onSimulate;

  const OrdersScreen({
    super.key,
    required this.orders,
    required this.onUpdateStatus,
    required this.onSimulate,
  });

  @override
  Widget build(BuildContext context) {
    final activeOrders = orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.rejected)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('داواکارییە چالاکەکان'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                ElevatedButton.icon(
                  onPressed: onSimulate,
                  icon: const Icon(Icons.notifications_active_rounded, size: 15, color: Colors.white),
                  label: const Text(
                    'تاقیکردنەوەی دەنگ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6418),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: activeOrders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    itemCount: activeOrders.length,
                    itemBuilder: (context, index) {
                      final order = activeOrders[index];
                      return _buildOrderCard(context, order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final formattedPrice = '${order.total.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    String idDisplay = order.id;
    if (!idDisplay.endsWith('#') && !idDisplay.startsWith('#')) {
      idDisplay = '$idDisplay#';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAF0), // Exact mint background from screenshot
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5), // Mint green border from screenshot
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00894C).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  idDisplay,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
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
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formattedPrice,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'وردەکاری داواکاری',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF475569),
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
            children: _buildActionButtons(context, order),
          ),
        ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
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
                        color: const Color(0xFFFFF2E8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.fastfood_rounded, size: 28, color: Color(0xFFFF6418)),
                    ),
                  ),
                ),
              ),

              SizedBox(width: gap),

              // ناوی بەرهەم (لە تەنیشت وێنە بەبێ Bold، ڕاست‌چین)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: nameFontSize,
                    color: const Color(0xFF0F172A),
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
                      const Text(
                        'د.ع',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        itemPriceAmount,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.normal,
                          fontSize: priceFontSize,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'X $qtyNumber',
                        style: TextStyle(
                          color: const Color(0xFF10B981), // ڕەنگی سەوز لە وێنەکەدا
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

  /// بۆکسی تێبینی کڕیار (Cyber Cyan ڕێک وەک وێنەکە)
  Widget _buildCustomerNotesBox(String notes) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0097CD), // Exact Cyan from screenshot
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0097CD).withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'تێبینی: $notes',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
          height: 1.3,
          letterSpacing: 0,
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 13,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            timeDisplay,
            style: const TextStyle(
              color: Color(0xFF64748B),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_bag_outlined, color: Colors.orange[800], size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                t('هیچ داواکارییەک نییە'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                t('لە کاتی هاتنی داواکاری لە ئەپی کڕیاران لێرە دەردەکەوێت'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onSimulate,
                icon: const Icon(Icons.notifications_active_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'تاقیکردنەوەی دەنگی داواکاری نوێ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6418),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    String text;
    switch (status) {
      case OrderStatus.pending:
        color = const Color(0xFFF97316); // Orange from screenshot
        text = t('چاوەڕوانکراو');
        break;
      case OrderStatus.preparing:
        color = const Color(0xFF3B82F6); // Blue from screenshot
        text = t('لە ئامادەکردندایە');
        break;
      case OrderStatus.ready:
        color = const Color(0xFF00894C); // Emerald green
        text = t('ئامادەیە بۆ شۆفێر');
        break;
      default:
        color = Colors.grey;
        text = 'نادیار';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
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
          child: _buildGreenButton(
            label: t('قبولکردن'),
            icon: Icons.check_circle_outline,
            onTap: () => onUpdateStatus(order.id, OrderStatus.preparing),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRedButton(
            label: t('ڕەتکردنەوە'),
            onTap: () => onUpdateStatus(order.id, OrderStatus.rejected),
          ),
        ),
      ];
    } else if (order.status == OrderStatus.preparing) {
      return [
        Expanded(
          child: _buildGreenButton(
            label: t('ئامادەیە بۆ شۆفێر'),
            icon: Icons.check_circle_outline,
            onTap: () => onUpdateStatus(order.id, OrderStatus.ready),
          ),
        ),
      ];
    } else if (order.status == OrderStatus.ready) {
      return [
        Expanded(
          child: _buildGreenButton(
            label: 'ڕادەستکردن بە شۆفێر',
            icon: Icons.delivery_dining_outlined,
            onTap: () => _showPinDialog(context, order),
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
          color: const Color(0xFF00894C), // Emerald green from screenshot
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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
          color: const Color(0xFFE50010), // Red from screenshot
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

  void _showPinDialog(BuildContext context, Order order) {
    final controller = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with close button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF), // light purple
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
                                    ),
                                    child: const Icon(
                                      Icons.key_rounded,
                                      color: Color(0xFF7E22CE), // purple 700
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ڕادەستکردنی داواکاری',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1B2028),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'داواکاری ${order.id}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFEA580C),
                                    size: 22,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x40EA580C),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            // Info Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF), // purple-50
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE9D5FF)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.security_rounded,
                                    size: 20,
                                    color: Color(0xFF7E22CE),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'کۆدی ٤ ژمارەیی لە شۆفێر وەربگرە',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF581C87),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'کۆدەکەی شۆفێر: ${order.handoverPin}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF9333EA),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // PIN input box
                            Text(
                              'کۆدی PIN ی شۆفێر بنووسە:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 10),

                            TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 4,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 16,
                                color: Color(0xFF581C87),
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '••••',
                                hintStyle: TextStyle(
                                  letterSpacing: 12,
                                  color: Colors.grey[400],
                                  fontSize: 22,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFDF4FF), // light purple tint
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: errorMessage != null ? const Color(0xFFE11D48) : const Color(0xFFD8B4FE),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: errorMessage != null ? const Color(0xFFE11D48) : const Color(0xFF7E22CE),
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                if (errorMessage != null) {
                                  setDialogState(() {
                                    errorMessage = null;
                                  });
                                }
                              },
                            ),

                            if (errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFE11D48),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 22),

                            // Actions
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00894C), // Emerald green
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {
                                      final enteredPin = controller.text.trim();
                                      if (enteredPin.isEmpty) {
                                        setDialogState(() {
                                          errorMessage = 'تکایە سەرەتا کۆدی PIN لە شۆفێر وەربگرە';
                                        });
                                        return;
                                      }
                                      if (order.dbId != null) {
                                        VendorApiService.instance.verifyHandoverPin(order.dbId!, enteredPin).then((res) {
                                          if (!res.$1) {
                                            setDialogState(() => errorMessage = res.$2);
                                            return;
                                          }
                                          Navigator.pop(dialogCtx);
                                          onUpdateStatus(order.id, OrderStatus.completed);
                                        });
                                        return;
                                      }
                                      if (enteredPin != order.handoverPin) {
                                        setDialogState(() {
                                          errorMessage = 'کۆدی PIN هەڵەیە! تکایە کۆدی دروست وەربگرە';
                                        });
                                        return;
                                      }

                                      // Success
                                      Navigator.pop(dialogCtx);
                                      onUpdateStatus(order.id, OrderStatus.completed);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: const Color(0xFF00894C),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          content: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'داواکاری ${order.id} بە سەرکەوتوویی ڕادەستی شۆفێر کرا',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 20),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'تەواو و ڕادەستکردن',
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50010), // Red background
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'پاشگەزبوونەوە',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0,
                                        ),
                                        maxLines: 1,
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
        );
      },
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
    Color statusBg = const Color(0xFFF3F4F6);
    Color statusTextColor = const Color(0xFF374151);

    switch (order.status) {
      case OrderStatus.pending:
        statusLabel = 'چاوەڕوانی قبوڵکردن';
        statusBg = const Color(0xFFFFEDD5);
        statusTextColor = const Color(0xFF9A3412);
        break;
      case OrderStatus.preparing:
        statusLabel = 'لە ئامادەکردندایە';
        statusBg = const Color(0xFFDBEAFE);
        statusTextColor = const Color(0xFF1E40AF);
        break;
      case OrderStatus.ready:
        statusLabel = 'ئامادەیە بۆ شۆفێر';
        statusBg = const Color(0xFFD1FAE5);
        statusTextColor = const Color(0xFF065F46);
        break;
      case OrderStatus.completed:
        statusLabel = 'گەیەندرا و تەواوبوو';
        statusBg = const Color(0xFFD1FAE5);
        statusTextColor = const Color(0xFF047857);
        break;
      case OrderStatus.rejected:
        statusLabel = 'ڕەتکراوەتەوە';
        statusBg = const Color(0xFFFFE4E6);
        statusTextColor = const Color(0xFFBE123C);
        break;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            backgroundColor: Colors.white,
            elevation: 16,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
                                color: const Color(0xFFFF6418),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6418).withOpacity(0.35),
                                    blurRadius: 5,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                idDisplay,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B2028),
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: statusTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'تۆمارکراوە: $timeFormatted',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 10),

                      // Delivery PIN & Quick Info Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFFB45309)),
                                SizedBox(width: 5),
                                Text(
                                  'کۆدی PIN ی گەیاندن:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: const Color(0xFFFCD34D)),
                              ),
                              child: Text(
                                order.handoverPin,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 9),

                      // Customer & Delivery Information
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 15, color: Color(0xFF00894C)),
                                const SizedBox(width: 5),
                                const Text('کڕیار: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                                Text(order.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1B2028))),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded, size: 15, color: Color(0xFF00894C)),
                                const SizedBox(width: 5),
                                const Text('مۆبایل: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(order.customerPhone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B2028))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF00894C)),
                                const SizedBox(width: 5),
                                const Text('ناونیشان: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    order.deliveryAddress,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1B2028)),
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
                          const Text(
                            'لیستی کڕین',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B2028),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${order.items.length} بەرهەم',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4B5563),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Large Product Image
                              GestureDetector(
                                onTap: () => showFullScreenImageDialog(dialogCtx, imageUrl: imgUrl, title: name),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    imgUrl,
                                    width: 78,
                                    height: 78,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 78,
                                      height: 78,
                                      color: const Color(0xFFF3F4F6),
                                      child: const Icon(Icons.fastfood_rounded, size: 30, color: Color(0xFF9CA3AF)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Product Name (بەبێ Bold)
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                    color: Color(0xFF1E2024),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // نرخ و بڕی داواکاری (د.ع لە لای چەپ / پشتی نرخ، و فۆنت گەورەکراو)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                textDirection: TextDirection.ltr,
                                children: [
                                  // نرخەکە: د.ع لە لای چەپ (پشتی نرخ) بەبێ bold و گەورە
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    textDirection: TextDirection.ltr,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      const Text(
                                        'د.ع',
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        itemPriceAmount,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          color: Color(0xFF1E2024),
                                          fontWeight: FontWeight.normal,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // بڕی داواکاری (X 1, X 2) بە قەبارەی گەورە، بەبێ bold و بە ڕەنگی سەوز
                                  Text(
                                    'X $qtyNumber',
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.normal,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // Simplified Financials (Dark Card)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2028),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
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
                                const Text('کۆی نرخ', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('داشکان', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('٠ د.ع', style: TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Divider(height: 1, color: Color(0xFF374151)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'کۆی گشتی حساب',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  formattedPrice,
                                  style: const TextStyle(
                                    color: Colors.white,
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
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00894C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  onUpdateStatus(order.id, OrderStatus.preparing);
                                },
                                child: const Text('قبوڵ کردن', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50010),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  onUpdateStatus(order.id, OrderStatus.rejected);
                                },
                                child: const Text('ڕەتکردنەوە', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.preparing) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00894C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            onUpdateStatus(order.id, OrderStatus.ready);
                          },
                          child: const Text('ئامادەیە بۆ شۆفێر', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ] else if (order.status == OrderStatus.ready) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00894C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _showPinDialog(context, order);
                          },
                          child: const Text('ڕادەستکردن بە شۆفێر (PIN)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B2028),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text(
                            'داخستن',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
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
  final Function(String) onAddCategory;
  final Function(String)? onDeleteCategory;

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
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE50010), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'سڕینەوەی بەش',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1B2028)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ئایا دڵنیایت لە سڕینەوەی بەشی "$category"؟',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151), height: 1.4),
              ),
              if (count > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ئەم بەشە $count بەرهەمی تێدایە.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50010),
                foregroundColor: Colors.white,
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
                    content: Text('بەشی "$category" بە سەرکەوتوویی سڕایەوە', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFFE50010),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('سڕینەوە', style: TextStyle(fontWeight: FontWeight.w900)),
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
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE50010), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'سڕینەوەی بەرهەم',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1B2028)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ئایا دڵنیایت لە سڕینەوەی بەرهەمی "${product.name}"؟',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151), height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'ئەم بەرهەمە لە مێنۆکەت دەسڕدرێتەوە.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50010),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.onDelete(product.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('بەرهەمی "${product.name}" بە سەرکەوتوویی سڕایەوە', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFFE50010),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('سڕینەوە', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter products
    List<Product> filteredProducts = widget.products.where((p) {
      final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF4A4A4A), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: t('مێنۆ و بەرهەم'),
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF262626),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Action & Categories Box (Header Card)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Two Action Buttons Row
                Row(
                  children: [
                    // Action 1: Add New Category (Right in RTL)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAddCategoryDialog(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FAF0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF5CD895), width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_rounded, color: Color(0xFF00894C), size: 19),
                                  SizedBox(width: 5),
                                  Text(
                                    'زیادکردنی بەشی نوێ',
                                    style: TextStyle(
                                      color: Color(0xFF00894C),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action 2: Add Product (Left in RTL)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAddProductDialog(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00894C),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00894C).withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 5),
                                  Text(
                                    'زیادکردنی بەرهەم',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Categories Filter Chips
                if (widget.categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.categories.length + 1,
                      itemBuilder: (context, index) {
                        // First Chip is "All" (هەمووی)
                        if (index == 0) {
                          final isAllSelected = _selectedCategory == null;
                          final totalCount = widget.products.length;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = null),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAllSelected ? const Color(0xFFE8FAF0) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAllSelected ? const Color(0xFF00894C) : const Color(0xFFE2E8F0),
                                  width: isAllSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'هەمووی',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isAllSelected ? const Color(0xFF00894C) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAllSelected ? const Color(0xFF00894C) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$totalCount',
                                      style: TextStyle(
                                        color: isAllSelected ? Colors.white : const Color(0xFF475569),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final catIndex = index - 1;
                        final cat = widget.categories[catIndex];
                        final count = widget.products.where((p) => p.category.trim() == cat.trim()).length;
                        final isSelected = _selectedCategory == cat;
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE8FAF0) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00894C) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    if (_selectedCategory == cat) {
                                      _selectedCategory = null;
                                    } else {
                                      _selectedCategory = cat;
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 7, 12, 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: isSelected ? const Color(0xFF00894C) : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF00894C) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : const Color(0xFF475569),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _confirmDeleteCategory(context, cat),
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFD1F2DF) : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: isSelected ? const Color(0xFF00894C) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Products Grid (2 columns)
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(context, filteredProducts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu_outlined, color: Color(0xFF00894C), size: 48),
          const SizedBox(height: 24),
          Text(t('هیچ بەرهەمێک نەدۆزرایەوە'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(t('دەتوانیت بە کلیک لەسەر دوگمەی (بەرهەمی نوێ) یەکەمین کاڵا زیادبکەیت.'), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    ImageProvider imageProvider;
    if (!kIsWeb && product.imagePath != null && product.imagePath!.isNotEmpty) {
      try {
        final f = File(product.imagePath!);
        if (f.existsSync()) {
          imageProvider = FileImage(f);
        } else if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          imageProvider = NetworkImage(product.imageUrl!);
        } else {
          imageProvider = const NetworkImage('https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop');
        }
      } catch (_) {
        imageProvider = (product.imageUrl != null && product.imageUrl!.isNotEmpty)
            ? NetworkImage(product.imageUrl!)
            : const NetworkImage('https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop');
      }
    } else if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(product.imageUrl!);
    } else {
      imageProvider = const NetworkImage('https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&auto=format&fit=crop');
    }

    final hasDiscount = product.discountPrice != null && product.discountPrice! > 0 && product.discountPrice! < product.price;
    final priceFormatted = '${product.price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع';
    final discountPriceFormatted = hasDiscount ? '${product.discountPrice!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع' : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          GestureDetector(
            onTap: () => showFullScreenImageDialog(context, imageProvider: imageProvider, title: product.name),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 115,
                    width: double.infinity,
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.fastfood, color: Colors.grey, size: 36),
                      ),
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'داشکاندن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              color: Color(0xFF1E2024),
            ),
          ),
          const SizedBox(height: 2),

          // Description
          Text(
            product.description ?? 'بەرهەمی فرێش...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),

          // Price
          hasDiscount
              ? Row(
                  children: [
                    Text(
                      discountPriceFormatted,
                      style: const TextStyle(
                        color: Color(0xFF00894C),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      priceFormatted,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFFDC2626),
                        decorationThickness: 1.6,
                      ),
                    ),
                  ],
                )
              : Text(
                  priceFormatted,
                  style: const TextStyle(
                    color: Color(0xFF00894C),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),

          const Spacer(),

          // Bottom Bar Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Availability Badge (Right in RTL)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: product.isAvailable ? const Color(0xFFE8FAF0) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.isAvailable ? t('بەردەستە') : t('نابەردەست'),
                      style: TextStyle(
                        color: product.isAvailable ? const Color(0xFF00894C) : const Color(0xFFD32F2F),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: product.isAvailable ? const Color(0xFF00894C) : const Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit & Delete Icons (Left in RTL)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showEditProductDialog(context, product),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, color: Color(0xFF9E9E9E), size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDeleteProduct(context, product),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, color: Color(0xFF9E9E9E), size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final categoryController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(18),
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('زیادکردنی بەشی نوێ'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(t('تکایە ناوی ئەو بەشە بنووسە کە دەتەوێت زیادی بکەیت'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                          child: Text(t('پاشگەزبونەوە'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (categoryController.text.isNotEmpty) {
                              widget.onAddCategory(categoryController.text);
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(t('زیادکردن'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
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
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toInt().toString());
    final discountPriceController = TextEditingController(text: product.discountPrice?.toInt().toString() ?? '');
    final descKuController = TextEditingController(text: product.id == '3' ? 'بەرگری گۆشتی فرێش لەگەڵ پەنیر و سەوزە' : '');
    final descArController = TextEditingController();
    String selectedCategory = product.category;
    String? localImagePath = product.imagePath;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
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
                                  color: const Color(0xFFFFF7ED),
                                  border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFEA580C),
                                    size: 20,
                                    shadows: [Shadow(color: Color(0xFFEA580C), blurRadius: 1)],
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
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
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
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(t('نرخی ئاسایی *')),
                                        _buildTextField(priceController, '7500'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(t('نرخی دوای داشکان')),
                                        _buildTextField(discountPriceController, 'ئارەزوومەندانە', hintColor: Colors.teal[200]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وێنەی بەرهەم')),
                              _buildImagePicker(
                                thumbnail: product.id == '3' ? 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=100' : null,
                                localImagePath: localImagePath,
                                onTap: () => _pickImage(setDialogState, (path) => localImagePath = path),
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
                                  onPressed: () {
                                    if (nameController.text.isNotEmpty) {
                                      widget.onEdit(Product(
                                        id: product.id,
                                        name: nameController.text,
                                        category: selectedCategory,
                                        price: double.tryParse(priceController.text) ?? 0,
                                        discountPrice: double.tryParse(discountPriceController.text),
                                        isAvailable: product.isAvailable,
                                        imagePath: localImagePath,
                                      ));
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C853),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(t('تۆمارکردنی بەرهەم'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
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

  Future<void> _pickImage(StateSetter setDialogState, Function(String) onImagePicked) async {
    final ImagePicker picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: Trans.direction,
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
                      color: Colors.grey[300],
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
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B)),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9800).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('کامێرا'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەی نوێ وەبگرە'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: const Color(0xFFFF9800),
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9800).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('گالەری'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەیەک لە موبایلەکەت هەڵبژێرە'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: const Color(0xFFFF9800),
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
                      backgroundColor: const Color(0xFFE50010),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t('پاشگەزبوونەوە'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setDialogState(() {
          onImagePicked(image.path);
        });
      }
    }
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final discountPriceController = TextEditingController();
    final descKuController = TextEditingController();
    final descArController = TextEditingController();
    String selectedCategory = widget.categories.isNotEmpty ? widget.categories.first : 'پیتزا';
    String? localImagePath;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
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
                                  color: const Color(0xFFFFF7ED),
                                  border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFEA580C),
                                    size: 20,
                                    shadows: [Shadow(color: Color(0xFFEA580C), blurRadius: 1)],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'زیادکردنی بەرهەمی نوێ',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32), // Balance the close button
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
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
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(t('نرخی ئاسایی *')),
                                        _buildTextField(priceController, '7500'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(t('نرخی دوای داشکان')),
                                        _buildTextField(discountPriceController, 'ئارەزوومەندانە', hintColor: Colors.teal[200]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              
                              _buildLabel(t('وێنەی بەرهەم')),
                              _buildImagePicker(
                                localImagePath: localImagePath,
                                onTap: () => _pickImage(setDialogState, (path) => localImagePath = path),
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
                                  onPressed: () {
                                    if (nameController.text.isNotEmpty) {
                                      widget.onAdd(Product(
                                        id: DateTime.now().toString(),
                                        name: nameController.text,
                                        category: selectedCategory,
                                        price: double.tryParse(priceController.text) ?? 0,
                                        discountPrice: double.tryParse(discountPriceController.text),
                                        imagePath: localImagePath,
                                      ));
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C853),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(t('تۆمارکردنی بەرهەم'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
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
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black)),
  );
  
  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, Color? hintColor}) => TextField(
    controller: controller,
    maxLines: maxLines,
    textAlign: TextAlign.left,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor ?? Colors.grey[400], fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00C853)),
      ),
    ),
  );

  Widget _buildDropdown({String? value, Function(String?)? onChanged}) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
        items: widget.categories.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
        onChanged: onChanged,
        hint: Text(widget.categories.isNotEmpty ? widget.categories.first : t('بەشێک هەڵبژێرە'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    ),
  );

  Widget _buildImagePicker({String? thumbnail, String? localImagePath, VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: localImagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(localImagePath),
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, color: Colors.grey, size: 20),
                  ),
                )
              : (thumbnail != null 
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      thumbnail,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, color: Colors.grey, size: 20),
                    ),
                  )
                : const Icon(Icons.image_outlined, color: Colors.grey, size: 20)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localImagePath != null ? localImagePath.split('/').last : (thumbnail != null ? 'Product_image.png' : t('هیچ فایلێک دیاری نەکراوە')), 
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(t('هەڵبژاردنی فایل'),
              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

class RevenueScreen extends StatefulWidget {
  final List<Order> orders;
  const RevenueScreen({super.key, required this.orders});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  int _selectedTabIndex = 0; // 0: ئەمڕۆ, 1: ئەم هەفتەیە, 2: ئەم مانگە
  int? _selectedBarIndex;

  String _formatAmount(num value) {
    final intVal = value.round();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tab metrics data
    double baseSales = 98500;
    double commissionRate = 0.12;
    int baseOrders = 8;
    String growthText = '+ ٪١٤.٢';
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
    List<double> chartValues = [12000, 18500, 8000, 16000, 24000, 15000, 5000];

    List<Map<String, dynamic>> topProducts = [
      {
        'rank': '١',
        'name': 'پیتزا پێپەرۆنی',
        'category': 'پیتزاکان',
        'sold': 5,
        'revenue': 42500,
        'image': 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500&auto=format&fit=crop',
        'percent': 1.0,
      },
      {
        'rank': '٢',
        'name': 'بەرگر گۆشت',
        'category': 'بەرگرەکان',
        'sold': 4,
        'revenue': 24000,
        'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop',
        'percent': 0.56,
      },
      {
        'rank': '٣',
        'name': 'کریسپی مریشک',
        'category': 'کریسپی',
        'sold': 3,
        'revenue': 22500,
        'image': 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&auto=format&fit=crop',
        'percent': 0.53,
      },
      {
        'rank': '٤',
        'name': 'کۆکا کۆلا',
        'category': 'خواردنەوەکان',
        'sold': 9,
        'revenue': 9000,
        'image': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop',
        'percent': 0.21,
      },
    ];

    if (_selectedTabIndex == 1) {
      baseSales = 645000;
      baseOrders = 54;
      growthText = '+ ٪١٨.٥';
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
        'هەینی (ئەمڕۆ)',
      ];
      chartValues = [75000, 82000, 94000, 68000, 110000, 117500, 98500];
      topProducts = [
        {
          'rank': '١',
          'name': 'پیتزا پێپەرۆنی',
          'category': 'پیتزاکان',
          'sold': 28,
          'revenue': 238000,
          'image': 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500&auto=format&fit=crop',
          'percent': 1.0,
        },
        {
          'rank': '٢',
          'name': 'بەرگر گۆشت',
          'category': 'بەرگرەکان',
          'sold': 26,
          'revenue': 156000,
          'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop',
          'percent': 0.65,
        },
        {
          'rank': '٣',
          'name': 'کریسپی مریشک',
          'category': 'کریسپی',
          'sold': 20,
          'revenue': 150000,
          'image': 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&auto=format&fit=crop',
          'percent': 0.63,
        },
        {
          'rank': '٤',
          'name': 'کۆکا کۆلا',
          'category': 'خواردنەوەکان',
          'sold': 58,
          'revenue': 58000,
          'image': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop',
          'percent': 0.24,
        },
      ];
    } else if (_selectedTabIndex == 2) {
      baseSales = 2780000;
      baseOrders = 232;
      growthText = '+ ٪٢٢.٤';
      periodTitle = t('ئەم مانگە');
      chartTitle = t('شیکاری فرۆشی هەفتەکانی ئەم مانگە');
      chartLabels = ['هەفتەی ١', 'هەفتەی ٢', 'هەفتەی ٣', 'هەفتەی ٤'];
      chartFullLabels = [
        'هەفتەی یەکەم',
        'هەفتەی دووەم',
        'هەفتەی سێیەم',
        'هەفتەی چوارەم',
      ];
      chartValues = [620000, 710000, 805000, 645000];
      topProducts = [
        {
          'rank': '١',
          'name': 'پیتزا پێپەرۆنی',
          'category': 'پیتزاکان',
          'sold': 120,
          'revenue': 1020000,
          'image': 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500&auto=format&fit=crop',
          'percent': 1.0,
        },
        {
          'rank': '٢',
          'name': 'بەرگر گۆشت',
          'category': 'بەرگرەکان',
          'sold': 110,
          'revenue': 660000,
          'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop',
          'percent': 0.65,
        },
        {
          'rank': '٣',
          'name': 'کریسپی مریشک',
          'category': 'کریسپی',
          'sold': 88,
          'revenue': 660000,
          'image': 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500&auto=format&fit=crop',
          'percent': 0.65,
        },
        {
          'rank': '٤',
          'name': 'کۆکا کۆلا',
          'category': 'خواردنەوەکان',
          'sold': 240,
          'revenue': 240000,
          'image': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop',
          'percent': 0.23,
        },
      ];
    }

    final totalSales = baseSales;
    final commission = totalSales * commissionRate;
    final netProfit = totalSales - commission;
    final avgTicket = totalSales / baseOrders;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // 1. Header with title & refresh button
            _buildHeader(context),
            const SizedBox(height: 14),

            // 2. Period Filter Tabs
            _buildTabs(),
            const SizedBox(height: 14),

            // 3. Main Profit Summary Card (Mint Green Card)
            _buildSummaryCard(
              netProfit: netProfit,
              totalSales: totalSales,
              commission: commission,
              ordersCount: baseOrders,
              avgTicket: avgTicket,
              growthText: growthText,
              periodTitle: periodTitle,
            ),
            const SizedBox(height: 14),

            // 4. Interactive Chart Card
            _buildChartCard(
              title: chartTitle,
              labels: chartLabels,
              fullLabels: chartFullLabels,
              values: chartValues,
            ),
            const SizedBox(height: 14),

            // 5. Top Products Card
            _buildTopProductsCard(topProducts),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('داهاتی فرۆشیار'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E2024),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t('شیکاری وردی فرۆش و قازانجەکانت'),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t('داهاتی فرۆشیار نوێکرایەوە'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF00894C),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh, size: 18, color: Color(0xFF00894C)),
                const SizedBox(width: 6),
                Text(
                  t('نوێکردنەوە'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00894C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(0, t('ئەمڕۆ')),
          _buildTabItem(1, t('ئەم هەفتەیە')),
          _buildTabItem(2, t('ئەم مانگە')),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _selectedBarIndex = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00894C) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00894C).withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: 13,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5CD895), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00894C).withOpacity(0.04),
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
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF81C784)),
                          ),
                          child: Text(
                            periodTitle,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
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
                            _formatAmount(netProfit),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00894C),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00894C),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'د.ع',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5CD895)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
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
                      child: const Icon(Icons.trending_up, color: Color(0xFF00894C), size: 13),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      growthText,
                      style: const TextStyle(
                        color: Color(0xFF00894C),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1E7DD)),
            ),
            child: Row(
              children: [
                _buildMetricCol(t('کۆی فرۆش'), '${_formatAmount(totalSales)} د.ع', const Color(0xFF1E2024)),
                Container(width: 1, height: 22, color: const Color(0xFFE5E7EB)),
                _buildMetricCol(t('کۆمیسیۆن (١٢٪)'), '${_formatAmount(commission)}- د.ع', const Color(0xFFD84315)),
                Container(width: 1, height: 22, color: const Color(0xFFE5E7EB)),
                _buildMetricCol(t('داواکارییەکان'), '$ordersCount دانە', const Color(0xFF1E2024)),
                Container(width: 1, height: 22, color: const Color(0xFFE5E7EB)),
                _buildMetricCol(t('تێکڕای فرۆش'), '${_formatAmount(avgTicket)} د.ع', const Color(0xFF00894C)),
              ],
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
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
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
                value,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                        color: const Color(0xFFE8FAF0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bar_chart, color: Color(0xFF00894C), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF1E2024),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Value Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FAF0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5CD895)),
                ),
                child: Text(
                  highlightText,
                  style: const TextStyle(
                    color: Color(0xFF00894C),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
                            color: isActive ? const Color(0xFF00894C) : const Color(0xFFD1E7DD),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00894C).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: isActive ? const Color(0xFF00894C) : const Color(0xFF6B7280),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Color(0xFFF06400), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t('پڕداهاتترین بەرهەمەکان'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: Color(0xFF1E2024),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                t('بەپێی کۆی فرۆش'),
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // List of top products
          ...topProducts.map((p) => _buildTopProductItem(p)),
        ],
      ),
    );
  }

  Widget _buildTopProductItem(Map<String, dynamic> item) {
    Color rankBg = const Color(0xFFF1F3F5);
    Color rankColor = const Color(0xFF495057);

    if (item['rank'] == '١') {
      rankBg = const Color(0xFFFFF8E1);
      rankColor = const Color(0xFFFF8F00);
    } else if (item['rank'] == '٢') {
      rankBg = const Color(0xFFECEFF1);
      rankColor = const Color(0xFF546E7A);
    } else if (item['rank'] == '٣') {
      rankBg = const Color(0xFFEFEBE9);
      rankColor = const Color(0xFF6D4C41);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  item['rank'],
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
                    color: Colors.grey[200],
                    child: const Icon(Icons.fastfood, color: Colors.grey, size: 22),
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
                      item['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: Color(0xFF1E2024),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['category']} • ${item['sold']} دانە فرۆشراوە',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Revenue
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${_formatAmount(item['revenue'])} د.ع',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF00894C),
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
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5CD895)),
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
  
  final ImagePicker _picker = ImagePicker();
  XFile? _coverImage;
  XFile? _logoImage;

  Future<void> _pickImage(bool isCover) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Directionality(
        textDirection: Trans.direction,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('هەڵبژاردنی وێنە'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B)),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9800).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('کامێرا'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەی نوێ وەبگرە'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: const Color(0xFFFF9800),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9800).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('گالەری'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t('وێنەیەک لە موبایلەکەت هەڵبژێرە'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Trans.direction == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            color: const Color(0xFFFF9800),
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: const Color(0xFFE50010),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      t('پاشگەزبوونەوە'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isCover) {
            _coverImage = pickedFile;
          } else {
            _logoImage = pickedFile;
          }
        });
      }
    }
  }

  Widget _buildImagePreview(XFile? file, IconData defaultIcon, {bool isWide = false}) {
    final double width = isWide ? 64 : 48;
    const double height = 48;
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: kIsWeb 
            ? Image.network(
                file.path,
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, color: Colors.grey[400], size: isWide ? 26 : 22),
              )
            : Image.file(
                File(file.path),
                fit: BoxFit.cover,
                width: width,
                height: height,
                errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, color: Colors.grey[400], size: isWide ? 26 : 22),
              ),
      );
    }
    return Icon(defaultIcon, color: Colors.grey[400], size: isWide ? 26 : 22);
  }

  Widget _buildImageSubCard({
    required String title,
    required String buttonText,
    required XFile? imageFile,
    required IconData defaultIcon,
    required VoidCallback onPick,
    bool isWide = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: onPick,
                child: Container(
                  width: isWide ? 64 : 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _buildImagePreview(imageFile, defaultIcon, isWide: isWide),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_outlined, size: 16, color: Color(0xFF00897B)),
                  label: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey[300]!),
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
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  String formatTime(TimeOfDay time) {
    final int hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final String period = time.hour >= 12 ? "PM" : "AM";
    final String min = time.minute.toString().padLeft(2, '0');
    final String hr = hour.toString().padLeft(2, '0');
    return '$hr:$min $period';
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('ڕێکخستنی دوکان'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(t('زانیاری بنەڕەتی، زمان و کاتژمێری کارکردن'), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 1. Working Hours Card (کاتی کارکردن)
            _buildSectionCard(
              title: t('کاتی کارکردن'),
              icon: Icons.access_time,
              iconColor: const Color(0xFF00897B),
              children: [
                Row(
                  children: [
                    // Opening Time (right in RTL)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(t('کاتی کردنەوە')),
                          GestureDetector(
                            onTap: () => _selectTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatTime(_openTime),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Closing Time (left in RTL)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(t('کاتی داخستن')),
                          GestureDetector(
                            onTap: () => _selectTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatTime(_closeTime),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 20),
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

            // 2. App Language Card (زمانی بەرنامە)
            _buildSectionCard(
              title: t('زمانی بەرنامە'),
              icon: Icons.translate,
              iconColor: const Color(0xFFF06400),
              badge: widget.language == 'ku' ? t('کوردی') : widget.language == 'ar' ? 'عربي' : 'English',
              children: [
                Row(
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
            
            // 4. Save Button
            ElevatedButton.icon(
              onPressed: () {
                widget.onNameChange(nameController.text);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('گۆڕانکارییەکان پاشەکەوت کران'))));
              }, 
              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 20),
              label: Text(
                t('پاشەکەوتکردنی گۆڕانکارییەکان'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B), 
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ), 
            ),
            const SizedBox(height: 12),
            
            // 5. Logout Button
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen())), 
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              label: Text(
                t('چوونە دەرەوە لە هەژمار'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
              ),
            ),
            const SizedBox(height: 32),
          ],
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
            color: isSelected ? const Color(0xFFF06400) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFF06400) : Colors.grey[200]!,
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: const Color(0xFFF06400).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // In RTL, first child is on the RIGHT
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor ?? const Color(0xFF00897B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                  ),
                ],
              ),
              // In RTL, second child is on the LEFT
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
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
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1F2937)),
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return TextField(
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
      ),
    );
  }
}
