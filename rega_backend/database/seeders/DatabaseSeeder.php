<?php

namespace Database\Seeders;

use App\Models\AppNotification;
use App\Models\Banner;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\CustomerAddress;
use App\Models\DriverDocument;
use App\Models\DriverProfile;
use App\Models\Neighborhood;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\Payout;
use App\Models\PlatformSetting;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreCategory;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Admins & Dispatchers
        $superAdmin = User::create([
            'name' => 'سەربەست کەریم',
            'phone' => '07700000001',
            'email' => 'admin@rega.iq',
            'password' => 'password123',
            'role' => 'super_admin',
            'language' => 'ku',
            'is_active' => true,
            'last_login_at' => now(),
        ]);

        User::create([
            'name' => 'دیار حەسەن',
            'phone' => '07700000002',
            'email' => 'ops@rega.iq',
            'password' => 'password123',
            'role' => 'dispatcher',
            'language' => 'ku',
            'is_active' => true,
        ]);

        // 2. Kalar Neighborhoods (9 exact zones from `rega`)
        $zonesData = [
            ['code' => 'n1', 'name_ku' => 'شارۆچکەی رزگاری', 'name_ar' => 'ناحية رزكاري', 'name_en' => 'Rzgari', 'fee' => 1500, 'lat' => 34.6710, 'lng' => 45.2950, 'min' => 30],
            ['code' => 'n2', 'name_ku' => 'گەڕەکی زانکۆ', 'name_ar' => 'حي الجامعة', 'name_en' => 'Zanko', 'fee' => 1000, 'lat' => 34.6920, 'lng' => 45.3240, 'min' => 20],
            ['code' => 'n3', 'name_ku' => 'گەڕەکی شەهیدان', 'name_ar' => 'حي الشهداء', 'name_en' => 'Shahidan', 'fee' => 1000, 'lat' => 34.6855, 'lng' => 45.3195, 'min' => 20],
            ['code' => 'n4', 'name_ku' => 'گەڕەکی سیروان', 'name_ar' => 'حي سيروان', 'name_en' => 'Sirwan', 'fee' => 1500, 'lat' => 34.6790, 'lng' => 45.3310, 'min' => 25],
            ['code' => 'n5', 'name_ku' => 'گەڕەکی شۆڕش', 'name_ar' => 'حي شورش', 'name_en' => 'Shorish', 'fee' => 1500, 'lat' => 34.6880, 'lng' => 45.3110, 'min' => 25],
            ['code' => 'n6', 'name_ku' => 'گەڕەکی بێساری', 'name_ar' => 'حي بيساري', 'name_en' => 'Besari', 'fee' => 2000, 'lat' => 34.7010, 'lng' => 45.3360, 'min' => 35],
            ['code' => 'n7', 'name_ku' => 'گەڕەکی کاکەییان', 'name_ar' => 'حي كاكائيان', 'name_en' => 'Kakeyan', 'fee' => 1500, 'lat' => 34.6760, 'lng' => 45.3150, 'min' => 25],
            ['code' => 'n8', 'name_ku' => 'گەڕەکی فەرمانبەران', 'name_ar' => 'حي الموظفين', 'name_en' => 'Farmanbaran', 'fee' => 1000, 'lat' => 34.6895, 'lng' => 45.3210, 'min' => 20],
            ['code' => 'n9', 'name_ku' => 'ناو بازاڕی کەلار', 'name_ar' => 'سوق كلار المركزي', 'name_en' => 'Downtown Market', 'fee' => 1000, 'lat' => 34.6836, 'lng' => 45.3189, 'min' => 18],
        ];

        $neighborhoods = [];
        foreach ($zonesData as $idx => $z) {
            $neighborhoods[$z['code']] = Neighborhood::create([
                'code' => $z['code'],
                'name_ku' => $z['name_ku'],
                'name_ar' => $z['name_ar'],
                'name_en' => $z['name_en'],
                'delivery_fee' => $z['fee'],
                'center_lat' => $z['lat'],
                'center_lng' => $z['lng'],
                'estimated_minutes' => $z['min'],
                'is_active' => true,
                'sort_order' => $idx + 1,
            ]);
        }

        // 3. Marketplace Categories (9 exact categories from `rega`)
        $catsData = [
            ['slug' => 'restaurants', 'ku' => 'خواردنگە', 'ar' => 'مطاعم', 'en' => 'Restaurants', 'icon' => 'restaurant', 'img' => 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80', 'home' => true],
            ['slug' => 'supermarket', 'ku' => 'سوپەرمارکێت', 'ar' => 'سوبرماركت', 'en' => 'Supermarkets', 'icon' => 'shopping_basket', 'img' => 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600&q=80', 'home' => true],
            ['slug' => 'fast-food', 'ku' => 'فاست فوود', 'ar' => 'وجبات سريعة', 'en' => 'Fast Food', 'icon' => 'lunch_dining', 'img' => 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&q=80', 'home' => true],
            ['slug' => 'fruits-veggies', 'ku' => 'سەوزە و میوە', 'ar' => 'خضروات وفواكه', 'en' => 'Fruits & Veggies', 'icon' => 'eco', 'img' => 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600&q=80', 'home' => true],
            ['slug' => 'cafe', 'ku' => 'کافێ', 'ar' => 'كافيه', 'en' => 'Cafes', 'icon' => 'local_cafe', 'img' => 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&q=80', 'home' => true],
            ['slug' => 'sweets-dairy', 'ku' => 'شیرەمەنی و شیرینی', 'ar' => 'حلويات وألبان', 'en' => 'Sweets & Dairy', 'icon' => 'cake', 'img' => 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&q=80', 'home' => true],
            ['slug' => 'bakery', 'ku' => 'نانەواخانە', 'ar' => 'مخبز وأفران', 'en' => 'Bakery', 'icon' => 'bakery_dining', 'img' => 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80', 'home' => true],
            ['slug' => 'meat-butcher', 'ku' => 'گۆشت و قەسابخانە', 'ar' => 'لحوم وقصابة', 'en' => 'Meat & Butcher', 'icon' => 'kebab_dining', 'img' => 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=600&q=80', 'home' => true],
            ['slug' => 'cosmetics', 'ku' => 'کۆسمەتیک', 'ar' => 'كوزمتك وعناية', 'en' => 'Cosmetics', 'icon' => 'spa', 'img' => 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=600&q=80', 'home' => false],
        ];

        $categories = [];
        foreach ($catsData as $idx => $c) {
            $categories[$c['slug']] = Category::create([
                'slug' => $c['slug'],
                'name_ku' => $c['ku'],
                'name_ar' => $c['ar'],
                'name_en' => $c['en'],
                'icon_name' => $c['icon'],
                'image_url' => $c['img'],
                'is_active' => true,
                'is_featured_home' => $c['home'],
                'sort_order' => $idx + 1,
            ]);
        }

        // 4. Stores & Vendors + Menu Categories + Products
        $storesConfig = [
            [
                'slug' => 'mam-rashid',
                'cat' => 'restaurants',
                'zone' => 'n9',
                'name_ku' => 'چێشتخانەی مام ڕەشید',
                'name_en' => 'Mam Rashid Restaurant',
                'owner_name' => 'حاجی ڕەشید ئەحمەد',
                'phone' => '07701112233',
                'address_ku' => 'ناو بازاڕی کەلار - تەنیشت قەڵای شێروانە',
                'lat' => 34.6841,
                'lng' => 45.3182,
                'rating' => 4.90,
                'reviews' => 418,
                'fee' => 1000,
                'comm' => 12.00,
                'badge' => '%20 OFF',
                'online' => true,
                'approved' => true,
                'featured' => true,
                'cover' => 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
                'sections' => [
                    'کەباب و برژاوەکان' => [
                        ['name_ku' => 'کەبابی کوردی تایبەت (٢ شیش)', 'name_en' => 'Kurdish Kebab (2 Skewers)', 'price' => 7000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&q=80', 'sold' => 185],
                        ['name_ku' => 'تکەی گۆشتی بەرخ', 'name_en' => 'Lamb Tikka', 'price' => 8500, 'discount' => 7500, 'img' => 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=600&q=80', 'sold' => 124],
                        ['name_ku' => 'مریشکی برژاو لەسەر خەڵوز', 'name_en' => 'Charcoal Grilled Chicken', 'price' => 12000, 'discount' => 10000, 'img' => 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=600&q=80', 'sold' => 98],
                    ],
                    'قوزی و برنج' => [
                        ['name_ku' => 'قوزی شامی بە گۆشتی بەرخ', 'name_en' => 'Lamb Quzi Platter', 'price' => 11000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=600&q=80', 'sold' => 160],
                        ['name_ku' => 'دۆی خۆماڵی سارد', 'name_en' => 'Fresh Kurdish Doogh', 'price' => 1000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&q=80', 'sold' => 310],
                    ],
                ],
            ],
            [
                'slug' => 'diwan-pizza-burger',
                'cat' => 'fast-food',
                'zone' => 'n2',
                'name_ku' => 'فاست فوودی دیوان',
                'name_en' => 'Diwan Fast Food',
                'owner_name' => 'کارزان سەعید',
                'phone' => '07504448899',
                'address_ku' => 'گەڕەکی زانکۆ - شەقامی سەرەکی بەرامبەر زانکۆی گەرمیان',
                'lat' => 34.6915,
                'lng' => 45.3235,
                'rating' => 4.80,
                'reviews' => 342,
                'fee' => 1000,
                'comm' => 12.00,
                'badge' => '1+1 FREE',
                'online' => true,
                'approved' => true,
                'featured' => true,
                'cover' => 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80',
                'sections' => [
                    'پیتزاکان' => [
                        ['name_ku' => 'پیتزا پێپەرۆنی گەورە', 'name_en' => 'Large Pepperoni Pizza', 'price' => 9500, 'discount' => 8000, 'img' => 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=600&q=80', 'sold' => 210],
                        ['name_ku' => 'پیتزای تێکەڵی تایبەت', 'name_en' => 'Supreme Mixed Pizza', 'price' => 10500, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&q=80', 'sold' => 145],
                    ],
                    'بەرگرەکان' => [
                        ['name_ku' => 'دەبڵ چیز بەرگر', 'name_en' => 'Double Cheeseburger', 'price' => 6000, 'discount' => 5000, 'img' => 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80', 'sold' => 190],
                        ['name_ku' => 'کریسپی باڵی مریشک (٨ دانە)', 'name_en' => 'Crispy Chicken Wings (8 pcs)', 'price' => 6500, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&q=80', 'sold' => 112],
                    ],
                    'خواردنەوەکان' => [
                        ['name_ku' => 'کۆکا کۆلا قتوو', 'name_en' => 'Coca-Cola Can', 'price' => 750, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&q=80', 'sold' => 420],
                    ],
                ],
            ],
            [
                'slug' => 'kalar-hypermarket',
                'cat' => 'supermarket',
                'zone' => 'n3',
                'name_ku' => 'سوپەرمارکێتی کەلار مۆڵ',
                'name_en' => 'Kalar Mall Supermarket',
                'owner_name' => 'ئاکۆ مستەفا',
                'phone' => '07702223344',
                'address_ku' => 'گەڕەکی شەهیدان - جووت سایدی سەرەکی',
                'lat' => 34.6860,
                'lng' => 45.3202,
                'rating' => 4.75,
                'reviews' => 289,
                'fee' => 1500,
                'comm' => 10.00,
                'badge' => 'FREE DELIVERY',
                'online' => true,
                'approved' => true,
                'featured' => true,
                'cover' => 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800&q=80',
                'sections' => [
                    'خۆراکی سەرەکی' => [
                        ['name_ku' => 'برنجی مەحموود (٥ کیلۆ)', 'name_en' => 'Mahmood Rice 5kg', 'price' => 11500, 'discount' => 10500, 'img' => 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&q=80', 'sold' => 132],
                        ['name_ku' => 'زەیتی گوڵەبەڕۆژە (١ لیتر)', 'name_en' => 'Sunflower Oil 1L', 'price' => 2750, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&q=80', 'sold' => 176],
                        ['name_ku' => 'چای جیهان (٥٠٠ گرام)', 'name_en' => 'Cihan Ceylon Tea 500g', 'price' => 5500, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1594631252845-29fc4cc8cde9?w=600&q=80', 'sold' => 94],
                    ],
                ],
            ],
            [
                'slug' => 'shawarma-rebaz',
                'cat' => 'fast-food',
                'zone' => 'n8',
                'name_ku' => 'شاوڕمەی ڕێباز',
                'name_en' => 'Rebaz Shawarma',
                'owner_name' => 'ڕێباز قادر',
                'phone' => '07713334455',
                'address_ku' => 'گەڕەکی فەرمانبەران - نزیک باخی گشتی',
                'lat' => 34.6890,
                'lng' => 45.3218,
                'rating' => 4.85,
                'reviews' => 265,
                'fee' => 1000,
                'comm' => 12.00,
                'badge' => '%15 OFF',
                'online' => true,
                'approved' => true,
                'featured' => false,
                'cover' => 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=800&q=80',
                'sections' => [
                    'شاوڕمە و ساندویچ' => [
                        ['name_ku' => 'شاوڕمەی عەرەبی مریشک (دەبڵ)', 'name_en' => 'Double Arabic Chicken Shawarma', 'price' => 5000, 'discount' => 4250, 'img' => 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=600&q=80', 'sold' => 270],
                        ['name_ku' => 'شاوڕمەی گۆشت بە ساج', 'name_en' => 'Beef Saj Shawarma', 'price' => 4000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&q=80', 'sold' => 198],
                    ],
                ],
            ],
            [
                'slug' => 'garmian-fruits',
                'cat' => 'fruits-veggies',
                'zone' => 'n4',
                'name_ku' => 'بازاڕی میوە و سەوزەی گەرمیان',
                'name_en' => 'Garmian Fresh Produce',
                'owner_name' => 'سەردار نەجم',
                'phone' => '07705556677',
                'address_ku' => 'گەڕەکی سیروان - شەقامی بازنەیی',
                'lat' => 34.6795,
                'lng' => 45.3302,
                'rating' => 4.70,
                'reviews' => 144,
                'fee' => 1500,
                'comm' => 10.00,
                'badge' => '%25 OFF',
                'online' => true,
                'approved' => true,
                'featured' => false,
                'cover' => 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=80',
                'sections' => [
                    'میوەکان' => [
                        ['name_ku' => 'سێوی سووری شارەزوور (١ کیلۆ)', 'name_en' => 'Red Apples 1kg', 'price' => 2000, 'discount' => 1500, 'img' => 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=600&q=80', 'sold' => 150],
                        ['name_ku' => 'مۆزی تازە (١ کیلۆ)', 'name_en' => 'Fresh Bananas 1kg', 'price' => 2250, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=600&q=80', 'sold' => 180],
                    ],
                ],
            ],
            [
                'slug' => 'safin-sweets',
                'cat' => 'sweets-dairy',
                'zone' => 'n9',
                'name_ku' => 'شیرینییەکانی سەفین',
                'name_en' => 'Safin Sweets & Pastry',
                'owner_name' => 'کامەران جەمال',
                'phone' => '07506667788',
                'address_ku' => 'ناو بازاڕی کەلار - شەقامی پزیشکان',
                'lat' => 34.6832,
                'lng' => 45.3175,
                'rating' => 4.92,
                'reviews' => 312,
                'fee' => 1000,
                'comm' => 12.00,
                'badge' => null,
                'online' => true,
                'approved' => true,
                'featured' => true,
                'cover' => 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800&q=80',
                'sections' => [
                    'پاقلاوە و کنافە' => [
                        ['name_ku' => 'پاقلاوەی گوێز و فستق (١ کیلۆ)', 'name_en' => 'Pistachio Baklava 1kg', 'price' => 14000, 'discount' => 12500, 'img' => 'https://images.unsplash.com/photo-1519676867240-f03562e64548?w=600&q=80', 'sold' => 115],
                        ['name_ku' => 'کنافەی گەرم بە پەنیر', 'name_en' => 'Hot Cheese Kunafa', 'price' => 6000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1576618148400-f54bed99fcfd?w=600&q=80', 'sold' => 165],
                    ],
                ],
            ],
            [
                'slug' => 'sirwan-cafe',
                'cat' => 'cafe',
                'zone' => 'n2',
                'name_ku' => 'کافێ سیروان',
                'name_en' => 'Sirwan Specialty Cafe',
                'owner_name' => 'ژیار عومەر',
                'phone' => '07707778899',
                'address_ku' => 'گەڕەکی زانکۆ - تەنیشت پارکی زانکۆ',
                'lat' => 34.6930,
                'lng' => 45.3252,
                'rating' => 4.78,
                'reviews' => 120,
                'fee' => 1000,
                'comm' => 14.00,
                'badge' => null,
                'online' => false,
                'approved' => true,
                'featured' => false,
                'cover' => 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800&q=80',
                'sections' => [
                    'قاوە و خواردنەوە ساردەکان' => [
                        ['name_ku' => 'ئایس سپانیش لاتێ', 'name_en' => 'Iced Spanish Latte', 'price' => 4000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=600&q=80', 'sold' => 88],
                        ['name_ku' => 'مۆهیتۆی شلیک و نەعنا', 'name_en' => 'Strawberry Mint Mojito', 'price' => 3500, 'discount' => 3000, 'img' => 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&q=80', 'sold' => 75],
                    ],
                ],
            ],
            [
                'slug' => 'rzgari-butcher',
                'cat' => 'meat-butcher',
                'zone' => 'n1',
                'name_ku' => 'قەسابخانەی بەرەکەت (رزگاری)',
                'name_en' => 'Barakat Butcher Shop',
                'owner_name' => 'هیوا کەریم',
                'phone' => '07708889900',
                'address_ku' => 'شارۆچکەی رزگاری - بازاڕی ناوەندی',
                'lat' => 34.6718,
                'lng' => 45.2960,
                'rating' => 4.80,
                'reviews' => 64,
                'fee' => 1500,
                'comm' => 8.00,
                'badge' => null,
                'online' => false,
                'approved' => false, // Pending admin approval!
                'featured' => false,
                'cover' => 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800&q=80',
                'sections' => [
                    'گۆشتی تازە' => [
                        ['name_ku' => 'گۆشتی بەرخی خۆماڵی (١ کیلۆ)', 'name_en' => 'Fresh Local Lamb 1kg', 'price' => 18000, 'discount' => null, 'img' => 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=600&q=80', 'sold' => 12],
                    ],
                ],
            ],
        ];

        $stores = [];
        $allProductsByStore = [];

        foreach ($storesConfig as $sConf) {
            $owner = User::create([
                'name' => $sConf['owner_name'],
                'phone' => $sConf['phone'],
                'email' => $sConf['slug'] . '@vendor.rega.iq',
                'password' => 'password123',
                'role' => 'vendor',
                'language' => 'ku',
                'is_active' => true,
            ]);

            $store = Store::create([
                'owner_id' => $owner->id,
                'category_id' => $categories[$sConf['cat']]->id,
                'neighborhood_id' => $neighborhoods[$sConf['zone']]->id,
                'slug' => $sConf['slug'],
                'name_ku' => $sConf['name_ku'],
                'name_ar' => $sConf['name_ku'],
                'name_en' => $sConf['name_en'],
                'phone' => $sConf['phone'],
                'address_ku' => $sConf['address_ku'],
                'lat' => $sConf['lat'],
                'lng' => $sConf['lng'],
                'cover_url' => $sConf['cover'],
                'logo_url' => $sConf['cover'],
                'rating' => $sConf['rating'],
                'review_count' => $sConf['reviews'],
                'delivery_time' => '20-30 خولەک',
                'base_delivery_fee' => $sConf['fee'],
                'commission_rate' => $sConf['comm'],
                'discount_badge' => $sConf['badge'],
                'open_time' => '09:00 AM',
                'close_time' => '11:30 PM',
                'is_online' => $sConf['online'],
                'is_approved' => $sConf['approved'],
                'is_featured' => $sConf['featured'],
                'wallet_balance' => 0,
            ]);

            $stores[$sConf['slug']] = $store;
            $allProductsByStore[$store->id] = [];

            $secOrder = 1;
            foreach ($sConf['sections'] as $secName => $prods) {
                $sc = StoreCategory::create([
                    'store_id' => $store->id,
                    'name_ku' => $secName,
                    'name_ar' => $secName,
                    'sort_order' => $secOrder++,
                ]);

                foreach ($prods as $p) {
                    $prod = Product::create([
                        'store_id' => $store->id,
                        'store_category_id' => $sc->id,
                        'name_ku' => $p['name_ku'],
                        'name_ar' => $p['name_ku'],
                        'name_en' => $p['name_en'],
                        'description_ku' => 'ئامادەکراوە بە کەرەستەی تازە و کوالێتی بەرز لە شاری کەلار.',
                        'price' => $p['price'],
                        'discount_price' => $p['discount'],
                        'image_url' => $p['img'],
                        'is_available' => true,
                        'is_featured' => $p['sold'] > 150,
                        'sold_count' => $p['sold'],
                    ]);
                    $allProductsByStore[$store->id][] = $prod;
                }
            }
        }

        // 5. Delivery Drivers + Motorcycles + 3 KYC Documents
        $driversData = [
            ['name' => 'ڕەوەند کەریم', 'phone' => '07501234567', 'code' => 'RA-884', 'motor' => 'هۆندا CBR 150R', 'plate' => 'B-84729-21', 'year' => '2023', 'color' => 'ڕەش و سەوز', 'verified' => true, 'online' => true, 'lat' => 34.6852, 'lng' => 45.3198, 'deliv' => 348, 'rating' => 4.94, 'hours' => 168.5],
            ['name' => 'ئاراس ئەحمەد', 'phone' => '07709876543', 'code' => 'RA-512', 'motor' => 'یاماها FZ-S', 'plate' => 'S-31094-22', 'year' => '2024', 'color' => 'شین و ڕەش', 'verified' => true, 'online' => true, 'lat' => 34.6910, 'lng' => 45.3230, 'deliv' => 275, 'rating' => 4.89, 'hours' => 142.0],
            ['name' => 'هەڵۆ مەحموود', 'phone' => '07704561230', 'code' => 'RA-609', 'motor' => 'بەجاج پۆڵسەر 180', 'plate' => 'S-55210-21', 'year' => '2022', 'color' => 'سوور', 'verified' => true, 'online' => true, 'lat' => 34.6805, 'lng' => 45.3290, 'deliv' => 192, 'rating' => 4.85, 'hours' => 98.5],
            ['name' => 'کاروان عەلی', 'phone' => '07503217890', 'code' => 'RA-731', 'motor' => 'هۆندا دیۆ 110', 'plate' => 'S-19402-23', 'year' => '2023', 'color' => 'سپی', 'verified' => true, 'online' => false, 'lat' => 34.6730, 'lng' => 45.2990, 'deliv' => 134, 'rating' => 4.78, 'hours' => 76.0],
            ['name' => 'بڕیار عوسمان', 'phone' => '07716549870', 'code' => 'RA-915', 'motor' => 'تی ڤی ئێس ئەپاچی', 'plate' => 'S-77120-24', 'year' => '2024', 'color' => 'زەرد و ڕەش', 'verified' => false, 'online' => false, 'lat' => 34.6865, 'lng' => 45.3160, 'deliv' => 0, 'rating' => 5.00, 'hours' => 0],
        ];

        $driverUsers = [];
        foreach ($driversData as $d) {
            $du = User::create([
                'name' => $d['name'],
                'phone' => $d['phone'],
                'email' => strtolower($d['code']) . '@driver.rega.iq',
                'password' => 'password123',
                'role' => 'driver',
                'language' => 'ku',
                'is_active' => true,
            ]);

            $dp = DriverProfile::create([
                'user_id' => $du->id,
                'driver_code' => $d['code'],
                'is_verified' => $d['verified'],
                'is_online' => $d['online'],
                'current_lat' => $d['lat'],
                'current_lng' => $d['lng'],
                'motor_type' => $d['motor'],
                'plate_number' => $d['plate'],
                'model_year' => $d['year'],
                'motor_color' => $d['color'],
                'is_vehicle_verified' => $d['verified'],
                'completion_rate' => 99.2,
                'total_deliveries' => $d['deliv'],
                'rating' => $d['rating'],
                'online_hours_total' => $d['hours'],
                'wallet_balance' => 0,
                'cash_collected_hand' => 0,
                'online_since' => $d['online'] ? now()->subHours(3) : null,
            ]);

            $docStatus = $d['verified'] ? 'verified' : 'pending';
            foreach (['national_id', 'driver_license', 'vehicle_registration'] as $docType) {
                DriverDocument::create([
                    'driver_profile_id' => $dp->id,
                    'doc_type' => $docType,
                    'document_number' => strtoupper(substr($docType, 0, 3)) . '-' . random_int(100000, 999999),
                    'status' => $docStatus,
                    'verified_by' => $d['verified'] ? $superAdmin->id : null,
                    'verified_at' => $d['verified'] ? now()->subDays(10) : null,
                ]);
            }

            if ($d['verified']) {
                $driverUsers[] = $du;
            }
        }

        // 6. Customers + Addresses
        $customersData = [
            ['name' => 'ئاراس ڕەحمان', 'phone' => '07703331122', 'zone' => 'n3', 'addr' => 'گەڕەکی شەهیدان، کۆڵانی ١٤، خانوو ٨'],
            ['name' => 'شاجوان محەمەد', 'phone' => '07502229988', 'zone' => 'n2', 'addr' => 'گەڕەکی زانکۆ، نزیک بەشە ناوخۆییەکان'],
            ['name' => 'میران جەلال', 'phone' => '07708881144', 'zone' => 'n4', 'addr' => 'گەڕەکی سیروان، تەنیشت قوتابخانەی سیروان'],
            ['name' => 'لانە سەردار', 'phone' => '07719992255', 'zone' => 'n8', 'addr' => 'گەڕەکی فەرمانبەران، کۆڵانی ٦'],
            ['name' => 'ڕێبین فەرهاد', 'phone' => '07507773366', 'zone' => 'n1', 'addr' => 'شارۆچکەی رزگاری، جووت سایدی ناوەند'],
            ['name' => 'سۆزیار عەبدولڵا', 'phone' => '07706664477', 'zone' => 'n9', 'addr' => 'ناو بازاڕی کەلار، تەلاری گەرمیان'],
        ];

        $customers = [];
        foreach ($customersData as $c) {
            $cu = User::create([
                'name' => $c['name'],
                'phone' => $c['phone'],
                'password' => 'password123',
                'role' => 'customer',
                'language' => 'ku',
                'is_active' => true,
            ]);

            CustomerAddress::create([
                'user_id' => $cu->id,
                'neighborhood_id' => $neighborhoods[$c['zone']]->id,
                'label' => 'ماڵەوە',
                'address_line' => $c['addr'],
                'lat' => $neighborhoods[$c['zone']]->center_lat,
                'lng' => $neighborhoods[$c['zone']]->center_lng,
                'is_default' => true,
            ]);

            $customers[] = ['user' => $cu, 'zone' => $neighborhoods[$c['zone']], 'addr' => $c['addr']];
        }

        // 7. Coupons & Banners
        $couponRega5 = Coupon::create([
            'code' => 'REGA5',
            'title_ku' => 'داشکاندنی ٢,٠٠٠ دینار بۆ هەموو داواکارییەک',
            'title_en' => '2,000 IQD Off Any Order',
            'discount_type' => 'fixed',
            'discount_value' => 2000,
            'min_order_amount' => 10000,
            'usage_limit' => 500,
            'used_count' => 34,
            'expires_at' => now()->addMonths(3),
            'is_active' => true,
        ]);

        Coupon::create([
            'code' => 'KALAR20',
            'title_ku' => 'داشکاندنی ٢٠٪ لە خواردنگەکان',
            'title_en' => '20% Off Restaurants',
            'discount_type' => 'percentage',
            'discount_value' => 20,
            'min_order_amount' => 12000,
            'max_discount_amount' => 5000,
            'usage_limit' => 200,
            'used_count' => 19,
            'expires_at' => now()->addMonths(2),
            'is_active' => true,
        ]);

        Coupon::create([
            'code' => 'FREEDEL',
            'title_ku' => 'گەیاندنی بێبەرامبەر لە کەلار',
            'title_en' => 'Free Delivery in Kalar',
            'discount_type' => 'free_delivery',
            'discount_value' => 0,
            'min_order_amount' => 8000,
            'usage_limit' => 300,
            'used_count' => 52,
            'expires_at' => now()->addMonth(),
            'is_active' => true,
        ]);

        Banner::create([
            'title_ku' => 'بازاڕی میوە و سەوزەی ڕۆژانە',
            'title_en' => 'Fresh Daily Fruits & Vegetables',
            'subtitle_ku' => 'گەیاندنی خێرا بۆ هەموو گەڕەکەکانی کەلار بە کەمترین نرخ',
            'badge_text' => '%25 داشکاندن',
            'image_url' => 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=1000&q=80',
            'target_type' => 'category',
            'category_id' => $categories['fruits-veggies']->id,
            'is_active' => true,
            'sort_order' => 1,
        ]);

        Banner::create([
            'title_ku' => 'چێشتخانەی مام ڕەشید — تامی ڕەسەنی کوردی',
            'title_en' => 'Mam Rashid Authentic Kurdish Grill',
            'subtitle_ku' => 'کەباب و قوزی گەرم لە ماوەی ٢٠ خولەک لە بەردەرگاکەتە',
            'badge_text' => 'تایبەت',
            'image_url' => 'https://images.unsplash.com/photo-1544025162-d76694265947?w=1000&q=80',
            'target_type' => 'store',
            'store_id' => $stores['mam-rashid']->id,
            'is_active' => true,
            'sort_order' => 2,
        ]);

        // 8. Seed 22 Realistic Orders across past 7 days + Today (Active & Delivered)
        $approvedStores = array_values(array_filter($stores, fn (Store $s) => $s->is_approved && $s->is_online));
        $orderCounter = 10230;

        // 15 Delivered orders across last 7 days (including today!)
        for ($i = 0; $i < 15; $i++) {
            $daysAgo = $i < 4 ? 0 : ($i % 7);
            $createdAt = Carbon::now()->subDays($daysAgo)->subHours(random_int(1, 6));
            $store = $approvedStores[$i % count($approvedStores)];
            $cust = $customers[$i % count($customers)];
            $driver = $driverUsers[$i % count($driverUsers)];
            $storeProds = $allProductsByStore[$store->id];

            $p1 = $storeProds[0];
            $qty1 = ($i % 3) + 1;
            $sub = $p1->effectivePrice() * $qty1;

            $itemsToInsert = [[
                'product_id' => $p1->id,
                'product_name' => $p1->name_ku,
                'product_image' => $p1->image_url,
                'unit_price' => $p1->effectivePrice(),
                'quantity' => $qty1,
                'line_total' => $sub,
            ]];

            if (count($storeProds) > 1 && $i % 2 === 0) {
                $p2 = $storeProds[1];
                $line2 = $p2->effectivePrice() * 2;
                $sub += $line2;
                $itemsToInsert[] = [
                    'product_id' => $p2->id,
                    'product_name' => $p2->name_ku,
                    'product_image' => $p2->image_url,
                    'unit_price' => $p2->effectivePrice(),
                    'quantity' => 2,
                    'line_total' => $line2,
                ];
            }

            $delFee = (int) $cust['zone']->delivery_fee;
            $tip = ($i % 4 === 0) ? 1000 : 0;
            $discount = ($i % 5 === 0) ? 2000 : 0;
            $total = max(0, $sub + $delFee + $tip - $discount);
            $commRate = (float) $store->commission_rate;
            $commAmt = (int) round($sub * ($commRate / 100));
            $vendorNet = $sub - $commAmt;
            $driverEarn = $delFee + $tip;

            $order = Order::create([
                'order_number' => 'RA-' . (++$orderCounter),
                'customer_id' => $cust['user']->id,
                'store_id' => $store->id,
                'driver_id' => $driver->id,
                'neighborhood_id' => $cust['zone']->id,
                'coupon_id' => $discount > 0 ? $couponRega5->id : null,
                'status' => 'delivered',
                'vendor_status' => 'completed',
                'driver_status' => 'delivered',
                'handover_pin' => (string) random_int(1000, 9999),
                'delivery_pin' => (string) random_int(1000, 9999),
                'subtotal' => $sub,
                'discount_amount' => $discount,
                'delivery_fee' => $delFee,
                'driver_tip' => $tip,
                'waiting_bonus' => 0,
                'total_amount' => $total,
                'commission_rate' => $commRate,
                'commission_amount' => $commAmt,
                'vendor_net_amount' => $vendorNet,
                'driver_total_earning' => $driverEarn,
                'payment_method' => 'cash',
                'payment_status' => 'paid',
                'customer_name' => $cust['user']->name,
                'customer_phone' => $cust['user']->phone,
                'delivery_address' => $cust['addr'],
                'delivery_lat' => $cust['zone']->center_lat,
                'delivery_lng' => $cust['zone']->center_lng,
                'accepted_at' => $createdAt->copy()->addMinutes(3),
                'ready_at' => $createdAt->copy()->addMinutes(16),
                'driver_assigned_at' => $createdAt->copy()->addMinutes(5),
                'picked_up_at' => $createdAt->copy()->addMinutes(19),
                'delivered_at' => $createdAt->copy()->addMinutes(31),
                'created_at' => $createdAt,
                'updated_at' => $createdAt->copy()->addMinutes(31),
            ]);

            foreach ($itemsToInsert as $it) {
                OrderItem::create(['order_id' => $order->id, ...$it]);
            }

            OrderStatusLog::create([
                'order_id' => $order->id,
                'from_status' => null,
                'to_status' => 'delivered',
                'actor_id' => $driver->id,
                'actor_role' => 'driver',
                'note' => 'گەیەندرا بە کۆدی پاراستن',
                'created_at' => $createdAt->copy()->addMinutes(31),
            ]);

            // Update store & driver balances
            $store->increment('wallet_balance', $vendorNet);
            $dp = $driver->driverProfile;
            if ($dp) {
                $dp->increment('wallet_balance', $driverEarn);
                $dp->increment('cash_collected_hand', $total);
            }
        }

        // 5 Live Active Orders right now (pending, preparing, ready, on_the_way) + 1 Cancelled
        $liveConfigs = [
            ['status' => 'pending', 'v_status' => 'pending', 'd_status' => 'unassigned', 'driver' => null, 'mins_ago' => 4, 'notes' => 'تکایە نانی گەرم و سەوزەی زیاتری لەگەڵ بێت'],
            ['status' => 'pending', 'v_status' => 'pending', 'd_status' => 'unassigned', 'driver' => null, 'mins_ago' => 7, 'notes' => 'بەبێ تیژی تکایە'],
            ['status' => 'preparing', 'v_status' => 'preparing', 'd_status' => 'driver_assigned', 'driver' => $driverUsers[1], 'mins_ago' => 14, 'notes' => null],
            ['status' => 'ready', 'v_status' => 'ready', 'd_status' => 'arrived_pickup', 'driver' => $driverUsers[2], 'mins_ago' => 21, 'notes' => 'پەیوەندی بکەن پێش گەیشتن'],
            ['status' => 'on_the_way', 'v_status' => 'completed', 'd_status' => 'on_the_way', 'driver' => $driverUsers[0], 'mins_ago' => 26, 'notes' => 'نهۆمی دووەم'],
            ['status' => 'cancelled', 'v_status' => 'rejected', 'd_status' => 'unassigned', 'driver' => null, 'mins_ago' => 95, 'notes' => null],
        ];

        $liveOrders = [];
        foreach ($liveConfigs as $idx => $lc) {
            $store = $approvedStores[$idx % count($approvedStores)];
            $cust = $customers[($idx + 1) % count($customers)];
            $prod = $allProductsByStore[$store->id][0];
            $sub = $prod->effectivePrice() * 2;
            $delFee = (int) $cust['zone']->delivery_fee;
            $commRate = (float) $store->commission_rate;
            $commAmt = (int) round($sub * ($commRate / 100));

            $lo = Order::create([
                'order_number' => 'RA-' . (++$orderCounter),
                'customer_id' => $cust['user']->id,
                'store_id' => $store->id,
                'driver_id' => $lc['driver']?->id,
                'neighborhood_id' => $cust['zone']->id,
                'status' => $lc['status'],
                'vendor_status' => $lc['v_status'],
                'driver_status' => $lc['d_status'],
                'handover_pin' => '4821',
                'delivery_pin' => '7392',
                'subtotal' => $sub,
                'discount_amount' => 0,
                'delivery_fee' => $delFee,
                'driver_tip' => 500,
                'waiting_bonus' => 0,
                'total_amount' => $sub + $delFee + 500,
                'commission_rate' => $commRate,
                'commission_amount' => $commAmt,
                'vendor_net_amount' => $sub - $commAmt,
                'driver_total_earning' => $delFee + 500,
                'payment_method' => 'cash',
                'payment_status' => 'pending',
                'customer_name' => $cust['user']->name,
                'customer_phone' => $cust['user']->phone,
                'delivery_address' => $cust['addr'],
                'delivery_lat' => $cust['zone']->center_lat,
                'delivery_lng' => $cust['zone']->center_lng,
                'customer_notes' => $lc['notes'],
                'cancellation_reason' => $lc['status'] === 'cancelled' ? 'کڕیار خۆی داوای هەڵوەشاندنەوەی کرد' : null,
                'cancelled_by' => $lc['status'] === 'cancelled' ? 'customer' : null,
                'created_at' => now()->subMinutes($lc['mins_ago']),
            ]);

            OrderItem::create([
                'order_id' => $lo->id,
                'product_id' => $prod->id,
                'product_name' => $prod->name_ku,
                'product_image' => $prod->image_url,
                'unit_price' => $prod->effectivePrice(),
                'quantity' => 2,
                'line_total' => $sub,
            ]);

            OrderStatusLog::create([
                'order_id' => $lo->id,
                'from_status' => null,
                'to_status' => $lc['status'],
                'actor_id' => $cust['user']->id,
                'actor_role' => 'customer',
                'note' => 'داواکاری تۆمارکرا',
            ]);

            $liveOrders[] = $lo;
        }

        // 9. Payouts & COD Collections
        Payout::create([
            'reference_code' => 'PAY-20261030-A101',
            'user_id' => $stores['mam-rashid']->owner_id,
            'store_id' => $stores['mam-rashid']->id,
            'recipient_type' => 'vendor',
            'direction' => 'payout_to_partner',
            'amount' => 25000,
            'payment_method' => 'cash',
            'status' => 'completed',
            'notes' => 'پاکتاوکردنی هەفتانەی چێشتخانەی مام ڕەشید',
            'processed_by' => $superAdmin->id,
            'processed_at' => now()->subDay(),
        ]);

        Payout::create([
            'reference_code' => 'PAY-20261031-B204',
            'user_id' => $driverUsers[0]->id,
            'recipient_type' => 'driver',
            'direction' => 'cod_collection_from_driver',
            'amount' => 35000,
            'payment_method' => 'cash',
            'status' => 'completed',
            'notes' => 'وەرگرتنەوەی پارەی کاشی کۆکراوە (COD) لە شۆفێر ڕەوەند',
            'processed_by' => $superAdmin->id,
            'processed_at' => now()->subHours(4),
        ]);

        Payout::create([
            'reference_code' => 'PAY-20261031-C309',
            'user_id' => $stores['diwan-pizza-burger']->owner_id,
            'store_id' => $stores['diwan-pizza-burger']->id,
            'recipient_type' => 'vendor',
            'direction' => 'payout_to_partner',
            'amount' => 18000,
            'payment_method' => 'fib',
            'status' => 'pending',
            'notes' => 'داواکاری ڕاکێشانی باڵانس لە ڕێگەی FIB',
        ]);

        // 10. Support Tickets
        SupportTicket::create([
            'ticket_number' => 'TKT-9012',
            'user_id' => $driverUsers[0]->id,
            'order_id' => $liveOrders[4]->id,
            'category' => 'unreachable_customer',
            'priority' => 'urgent',
            'subject' => 'کڕیار وەڵامی پەیوەندی ناداتەوە (٣ جار پەیوەندی کراوە)',
            'description' => 'لە بەردەم ناونیشانی دیاریکراوم لە گەڕەکی شەهیدان، ٣ جار پەیوەندیم کردووە و مۆبایلەکەی داخراوە.',
            'status' => 'open',
        ]);

        SupportTicket::create([
            'ticket_number' => 'TKT-9015',
            'user_id' => $driverUsers[2]->id,
            'order_id' => $liveOrders[3]->id,
            'category' => 'waiting_bonus',
            'priority' => 'medium',
            'subject' => 'داواکاری پاداشتی چاوەڕوانی لە فرۆشگا (١٨ خولەک)',
            'description' => 'زیاتر لە ١٨ خولەک لە بەردەم فرۆشگا چاوەڕێی ئامادەبوونی خواردنەکەم کردووە.',
            'status' => 'in_progress',
        ]);

        // 11. Notifications
        AppNotification::create([
            'target_audience' => 'customers',
            'title_ku' => 'کۆدی داشکاندنی REGA5 چالاکە! 🎉',
            'title_en' => 'Promo Code REGA5 is Live!',
            'body_ku' => 'ئێستا داواکاری بنێرە و ٢,٠٠٠ دینار داشکاندنی ڕاستەوخۆ وەربگرە لە هەموو فرۆشگاکانی کەلار.',
            'tag' => 'کۆدی داشکاندن',
            'type' => 'general',
            'discount_badge' => '2,000 د.ع',
        ]);

        AppNotification::create([
            'target_audience' => 'drivers',
            'title_ku' => 'پاداشتی تایبەتی کاتژمێرە قەرەباڵغەکان 🏍️',
            'title_en' => 'Peak Hour Driver Bonus Active',
            'body_ku' => 'لە کاتژمێر ٧ی ئێوارە تا ١١ی شەو بۆ هەر ١٠ گەیاندنێک ٥,٠٠٠ دینار پاداشتی زیادە وەربگرە.',
            'tag' => 'ئۆفەر',
            'type' => 'general',
        ]);

        // 12. Platform Settings (PostgreSQL JSONB)
        $settings = [
            ['key' => 'platform_name', 'group' => 'general', 'val' => 'REGA - ڕێگا (کەلار)'],
            ['key' => 'default_commission_rate', 'group' => 'finance', 'val' => 12],
            ['key' => 'default_delivery_fee', 'group' => 'finance', 'val' => 1500],
            ['key' => 'waiting_bonus_threshold_minutes', 'group' => 'finance', 'val' => 15],
            ['key' => 'waiting_bonus_amount', 'group' => 'finance', 'val' => 1000],
            ['key' => 'support_phone', 'group' => 'support', 'val' => '0770 000 1122'],
            ['key' => 'driver_hotline', 'group' => 'support', 'val' => '0750 000 9372'],
            ['key' => 'emergency_phone', 'group' => 'support', 'val' => '0750 911 0000'],
            ['key' => 'whatsapp_number', 'group' => 'support', 'val' => '+9647700001122'],
            ['key' => 'working_hours', 'group' => 'public', 'val' => '09:00 AM - 01:00 AM'],
            ['key' => 'enforce_anti_vpn', 'group' => 'security', 'val' => true],
            ['key' => 'maintenance_mode', 'group' => 'general', 'val' => false],
        ];

        foreach ($settings as $st) {
            PlatformSetting::setValue($st['key'], $st['val'], $st['group']);
        }
    }
}
