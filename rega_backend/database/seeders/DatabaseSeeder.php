<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Neighborhood;
use App\Models\PlatformSetting;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Production / clean seed — infrastructure only.
 * No fake vendors, products, customers, drivers, or orders.
 *
 * Optional demo data: php artisan db:seed --class=DemoDataSeeder
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Admins (real login accounts — not marketplace demo data)
        User::query()->updateOrCreate(
            ['email' => 'admin@rega.iq'],
            [
                'name' => 'سەربەست کەریم',
                'phone' => '07700000001',
                'password' => 'password123',
                'role' => 'super_admin',
                'language' => 'ku',
                'is_active' => true,
                'last_login_at' => now(),
            ]
        );

        // 2. Kalar delivery zones
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

        foreach ($zonesData as $idx => $z) {
            Neighborhood::query()->updateOrCreate(
                ['code' => $z['code']],
                [
                    'name_ku' => $z['name_ku'],
                    'name_ar' => $z['name_ar'],
                    'name_en' => $z['name_en'],
                    'delivery_fee' => $z['fee'],
                    'center_lat' => $z['lat'],
                    'center_lng' => $z['lng'],
                    'estimated_minutes' => $z['min'],
                    'is_active' => true,
                    'sort_order' => $idx + 1,
                ]
            );
        }

        // 3. Marketplace home categories (empty shelves — no fake products)
        $catsData = [
            ['slug' => 'restaurants', 'ku' => 'خواردنگە', 'ar' => 'مطاعم', 'en' => 'Restaurants', 'icon' => 'restaurant', 'img' => 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80', 'home' => true],
            ['slug' => 'supermarket', 'ku' => 'سوپەرمارکێت', 'ar' => 'سوبرماركت', 'en' => 'Supermarkets', 'icon' => 'shopping_basket', 'img' => 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600&q=80', 'home' => true],
            ['slug' => 'fast-food', 'ku' => 'فست فوود', 'ar' => 'وجبات سريعة', 'en' => 'Fast Food', 'icon' => 'lunch_dining', 'img' => 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&q=80', 'home' => true],
            ['slug' => 'fruits-veggies', 'ku' => 'سەوزە و میوە', 'ar' => 'خضروات وفواكه', 'en' => 'Fruits & Veggies', 'icon' => 'eco', 'img' => 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600&q=80', 'home' => true],
            ['slug' => 'cafe', 'ku' => 'کافێ', 'ar' => 'كافيه', 'en' => 'Cafes', 'icon' => 'local_cafe', 'img' => 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&q=80', 'home' => true],
            ['slug' => 'sweets-dairy', 'ku' => 'شیرەمەنی و شیرینی', 'ar' => 'حلويات وألبان', 'en' => 'Sweets & Dairy', 'icon' => 'cake', 'img' => 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&q=80', 'home' => true],
            ['slug' => 'bakery', 'ku' => 'نانەواخانە', 'ar' => 'مخبز وأفران', 'en' => 'Bakery', 'icon' => 'bakery_dining', 'img' => 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80', 'home' => true],
            ['slug' => 'meat-butcher', 'ku' => 'گۆشت و قەسابخانە', 'ar' => 'لحوم وقصابة', 'en' => 'Meat & Butcher', 'icon' => 'kebab_dining', 'img' => 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=600&q=80', 'home' => true],
            ['slug' => 'cosmetics', 'ku' => 'کۆسمەتیک', 'ar' => 'كوزمتك وعناية', 'en' => 'Cosmetics', 'icon' => 'spa', 'img' => 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=600&q=80', 'home' => false],
        ];

        foreach ($catsData as $idx => $c) {
            Category::query()->updateOrCreate(
                ['slug' => $c['slug']],
                [
                    'name_ku' => $c['ku'],
                    'name_ar' => $c['ar'],
                    'name_en' => $c['en'],
                    'icon_name' => $c['icon'],
                    'image_url' => $c['img'],
                    'is_active' => true,
                    'is_featured_home' => $c['home'],
                    'sort_order' => $idx + 1,
                ]
            );
        }

        // 4. Platform settings
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
            ['key' => 'telegram_number', 'group' => 'support', 'val' => '+9647700001122'],
            ['key' => 'telegram_username', 'group' => 'support', 'val' => 'rega_support'],
            ['key' => 'working_hours', 'group' => 'public', 'val' => '09:00 AM - 01:00 AM'],
            ['key' => 'enforce_anti_vpn', 'group' => 'security', 'val' => true],
            ['key' => 'maintenance_mode', 'group' => 'general', 'val' => false],
        ];

        foreach ($settings as $st) {
            PlatformSetting::setValue($st['key'], $st['val'], $st['group']);
        }
    }
}
