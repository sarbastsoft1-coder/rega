<?php

namespace Tests\Feature;

use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Store;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegaEcosystemApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    private function asBearer(string $token): self
    {
        $this->app['auth']->forgetGuards();
        return $this->withToken($token);
    }

    public function test_health_and_public_bootstrap_work_on_postgresql(): void
    {
        $this->getJson('/api/health')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('database', 'PostgreSQL')
            ->assertJsonPath('db_connected', true);

        $boot = $this->getJson('/api/v1/public/bootstrap')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertCount(9, $boot->json('data.neighborhoods'));
        $this->assertCount(9, $boot->json('data.categories'));
        $this->assertNotEmpty($boot->json('data.stores'));
        $this->assertEquals('0750 000 9372', $boot->json('data.settings.driver_hotline'));
    }

    public function test_admin_auth_dashboard_and_rbac_protection(): void
    {
        // Admin login via phone
        $login = $this->postJson('/api/v1/auth/login', [
            'identifier' => '07700000001',
            'password' => 'password123',
            'role_filter' => 'admin',
        ])->assertOk();

        $adminToken = $login->json('data.token');
        $this->assertNotEmpty($adminToken);

        // Dashboard overview
        $dash = $this->asBearer($adminToken)
            ->getJson('/api/v1/admin/dashboard?days=7')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertGreaterThan(0, $dash->json('data.kpis.total_gmv'));
        $this->assertGreaterThan(0, $dash->json('data.kpis.platform_commission_earned'));
        $this->assertCount(7, $dash->json('data.revenue_chart'));
        $this->assertNotEmpty($dash->json('data.fleet_radar.stores'));
        $this->assertNotEmpty($dash->json('data.fleet_radar.drivers'));

        // Customer cannot access admin routes
        $custReg = $this->postJson('/api/v1/auth/register', [
            'name' => 'کڕیاری تاقیکردنەوە',
            'phone' => '07709998877',
            'password' => 'secret123',
        ])->assertCreated();

        $custToken = $custReg->json('data.token');

        $this->asBearer($custToken)
            ->getJson('/api/v1/admin/dashboard')
            ->assertForbidden();
    }

    public function test_admin_onboards_vendor_store_and_driver_kyc_workflow(): void
    {
        $adminToken = $this->postJson('/api/v1/auth/login', [
            'email' => 'admin@rega.iq',
            'password' => 'password123',
        ])->json('data.token');

        $catId = $this->withToken($adminToken)->getJson('/api/v1/admin/categories')->json('data.0.id');
        $zoneId = $this->withToken($adminToken)->getJson('/api/v1/admin/neighborhoods')->json('data.0.id');

        // Provision new vendor store
        $storeRes = $this->withToken($adminToken)->postJson('/api/v1/admin/stores', [
            'name_ku' => 'چێشتخانەی گەرمیانی نوێ',
            'name_en' => 'New Garmian Grill',
            'category_id' => $catId,
            'neighborhood_id' => $zoneId,
            'phone' => '07508887766',
            'address_ku' => 'کەلار - گەڕەکی زانکۆ',
            'commission_rate' => 15.0,
            'owner_name' => 'هێمن عەزیز',
            'owner_phone' => '07508887766',
            'owner_password' => 'vendorpass',
        ])->assertCreated();

        $newStoreId = $storeRes->json('data.id');
        $this->assertEquals(15.0, $storeRes->json('data.commission_rate'));

        // Newly provisioned vendor can immediately log in to Vendor App API
        $vendorLogin = $this->postJson('/api/v1/auth/login', [
            'phone' => '07508887766',
            'password' => 'vendorpass',
            'role_filter' => 'vendor',
        ])->assertOk();

        $this->assertEquals($newStoreId, $vendorLogin->json('data.user.owned_store.id'));

        // Onboard unverified driver and approve all 3 KYC docs
        $driverRes = $this->withToken($adminToken)->postJson('/api/v1/admin/drivers', [
            'name' => 'دانا کەمال',
            'phone' => '07712223344',
            'password' => 'driverpass',
            'motor_type' => 'Honda Wave 110',
            'plate_number' => 'S-99881-24',
            'is_verified' => false,
        ])->assertCreated();

        $driverProfileId = $driverRes->json('data.id');
        $docs = $driverRes->json('data.documents');
        $this->assertCount(3, $docs);
        $this->assertFalse($driverRes->json('data.is_verified'));

        foreach ($docs as $doc) {
            $this->withToken($adminToken)
                ->patchJson("/api/v1/admin/driver-documents/{$doc['id']}/verify", [
                    'status' => 'verified',
                ])->assertOk();
        }

        $this->assertTrue(DriverProfile::findOrFail($driverProfileId)->is_verified);
    }

    public function test_complete_end_to_end_order_lifecycle_with_dual_pins_and_financial_settlement(): void
    {
        $adminToken = $this->postJson('/api/v1/auth/login', [
            'email' => 'admin@rega.iq',
            'password' => 'password123',
        ])->json('data.token');

        $vendorToken = $this->postJson('/api/v1/auth/login', [
            'phone' => '07701112233', // Mam Rashid store owner
            'password' => 'password123',
        ])->json('data.token');

        $driverLogin = $this->postJson('/api/v1/auth/login', [
            'phone' => '07501234567', // Rawand Karim (RA-884)
            'password' => 'password123',
        ])->assertOk();
        $driverToken = $driverLogin->json('data.token');
        $driverUserId = $driverLogin->json('data.user.id');

        $custLogin = $this->postJson('/api/v1/auth/login', [
            'phone' => '07703331122',
            'password' => 'password123',
        ])->assertOk();
        $custToken = $custLogin->json('data.token');

        $store = Store::where('slug', 'mam-rashid')->with('products')->firstOrFail();
        $storeWalletBefore = (int) $store->wallet_balance;
        $driverProfileBefore = DriverProfile::where('user_id', $driverUserId)->firstOrFail();
        $driverWalletBefore = (int) $driverProfileBefore->wallet_balance;
        $driverCodBefore = (int) $driverProfileBefore->cash_collected_hand;

        $product = $store->products->first();

        // 1. Customer places order with REGA5 coupon (2,000 IQD off >= 10,000 IQD)
        $orderRes = $this->asBearer($custToken)->postJson('/api/v1/customer/orders', [
            'store_id' => $store->id,
            'delivery_address' => 'گەڕەکی شەهیدان - نزیک قوتابخانە',
            'coupon_code' => 'REGA5',
            'driver_tip' => 500,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
        ])->assertCreated();

        $orderId = $orderRes->json('data.id');
        $orderModel = Order::findOrFail($orderId);
        $this->assertEquals(2000, $orderModel->discount_amount);

        // 2. Admin assigns driver
        $this->asBearer($adminToken)
            ->postJson("/api/v1/admin/orders/{$orderId}/assign-driver", [
                'driver_id' => $driverUserId,
            ])->assertOk();

        // 3. Vendor accepts & marks ready
        $this->asBearer($vendorToken)->postJson("/api/v1/vendor/orders/{$orderId}/accept")->assertOk();
        $this->asBearer($vendorToken)->postJson("/api/v1/vendor/orders/{$orderId}/ready")->assertOk();

        // 4. Vendor handover fails with wrong PIN, succeeds with real driver handover_pin
        $this->asBearer($vendorToken)
            ->postJson("/api/v1/vendor/orders/{$orderId}/handover", ['pin' => '0000'])
            ->assertStatus(422);

        $this->asBearer($vendorToken)
            ->postJson("/api/v1/vendor/orders/{$orderId}/handover", ['pin' => $orderModel->handover_pin])
            ->assertOk()
            ->assertJsonPath('data.status', 'picked_up');

        // 5. Driver advances to on_the_way -> arrived_customer -> verifies customer's delivery_pin
        $this->asBearer($driverToken)
            ->patchJson("/api/v1/driver/orders/{$orderId}/status", ['driver_status' => 'on_the_way'])
            ->assertOk();

        $this->asBearer($driverToken)
            ->patchJson("/api/v1/driver/orders/{$orderId}/status", ['driver_status' => 'arrived_customer'])
            ->assertOk();

        $this->asBearer($driverToken)
            ->postJson("/api/v1/driver/orders/{$orderId}/verify-delivery", ['pin' => '0000'])
            ->assertStatus(422);

        $this->asBearer($driverToken)
            ->postJson("/api/v1/driver/orders/{$orderId}/verify-delivery", ['pin' => $orderModel->delivery_pin])
            ->assertOk()
            ->assertJsonPath('data.status', 'delivered');

        // 6. Verify atomic PostgreSQL financial ledger updates
        $store->refresh();
        $driverProfileAfter = DriverProfile::where('user_id', $driverUserId)->firstOrFail();

        $this->assertEquals($storeWalletBefore + $orderModel->vendor_net_amount, (int) $store->wallet_balance);
        $this->assertEquals($driverWalletBefore + $orderModel->driver_total_earning, (int) $driverProfileAfter->wallet_balance);
        $this->assertEquals($driverCodBefore + $orderModel->total_amount, (int) $driverProfileAfter->cash_collected_hand);

        // 7. Admin collects COD cash from driver & updates platform settings
        $this->asBearer($adminToken)->postJson('/api/v1/admin/payouts', [
            'recipient_type' => 'driver',
            'direction' => 'cod_collection_from_driver',
            'user_id' => $driverUserId,
            'amount' => $orderModel->total_amount,
            'payment_method' => 'cash',
            'status' => 'completed',
        ])->assertCreated();

        $driverProfileAfter->refresh();
        $this->assertEquals($driverCodBefore, (int) $driverProfileAfter->cash_collected_hand);

        $this->asBearer($adminToken)->putJson('/api/v1/admin/settings', [
            'settings' => [
                'default_commission_rate' => 14,
            ],
        ])->assertOk()->assertJsonPath('data.default_commission_rate', 14);
    }

    public function test_second_by_second_live_telemetry_sync_and_pin_delivery(): void
    {
        // 1. Customer registers live order tracking session in Kalar
        $reg = $this->postJson('/api/v1/live-telemetry/register', [
            'order_ref' => 'RA-99001',
            'store_name' => 'چێشتخانەی دیوان',
            'store_lat' => 34.6836,
            'store_lng' => 45.3189,
            'customer_name' => 'ئاراس ڕەحمان',
            'customer_address' => 'گەڕەکی زانکۆ - کۆڵانی ١٢',
            'customer_lat' => 34.6918,
            'customer_lng' => 45.3270,
            'delivery_pin' => '7392',
            'total_amount' => 21000,
        ])->assertCreated();

        $this->assertEquals('RA-99001', $reg->json('data.order_ref'));
        $this->assertEquals('7392', $reg->json('data.delivery_pin'));

        // 2. Driver app discovers latest active order and pushes 1-second telemetry ticks
        $this->getJson('/api/v1/live-telemetry/latest-active')
            ->assertOk()
            ->assertJsonPath('data.order_ref', 'RA-99001');

        $this->postJson('/api/v1/live-telemetry/RA-99001', [
            'driver_lat' => 34.6875,
            'driver_lng' => 45.3228,
            'driver_heading' => 48.5,
            'driver_speed_kmh' => 36.2,
            'eta_seconds' => 64,
            'distance_remaining_meters' => 540,
            'progress_permille' => 680,
            'status' => 'on_the_way',
            'driver_status' => 'on_the_way',
        ])->assertOk();

        // 3. Customer app polls 1s later and receives exact driver GPS, speed, heading, and countdown
        $poll = $this->getJson('/api/v1/live-telemetry/RA-99001')
            ->assertOk()
            ->assertJsonPath('data.status', 'on_the_way')
            ->assertJsonPath('data.eta_seconds', 64)
            ->assertJsonPath('data.distance_remaining_meters', 540)
            ->assertJsonPath('data.driver.is_live_captain', true);

        $this->assertEqualsWithDelta(34.6875, $poll->json('data.driver.lat'), 0.0001);

        // 4. Verify 4-digit PIN completes delivery
        $this->postJson('/api/v1/live-telemetry/RA-99001/verify-pin', ['pin' => '0000'])->assertStatus(422);
        $this->postJson('/api/v1/live-telemetry/RA-99001/verify-pin', ['pin' => '7392'])
            ->assertOk()
            ->assertJsonPath('data.status', 'delivered')
            ->assertJsonPath('data.eta_seconds', 0);
    }

    public function test_three_admin_ecosystem_parts_and_public_customer_order_sync(): void
    {
        $adminToken = $this->postJson('/api/v1/auth/login', [
            'email' => 'admin@rega.iq',
            'password' => 'password123',
        ])->assertOk()->json('data.token');

        // 1. Verify Admin 3 Core Ecosystem Parts (Vendor / Customer / Delivery)
        $hubs = $this->asBearer($adminToken)
            ->getJson('/api/v1/admin/ecosystem-hubs')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertNotEmpty($hubs->json('data.vendor_part.stores'));
        $this->assertGreaterThan(0, $hubs->json('data.vendor_part.kpis.total_stores'));
        $this->assertNotEmpty($hubs->json('data.customer_part.vip_customers'));
        $this->assertGreaterThan(0, $hubs->json('data.customer_part.kpis.total_customers'));
        $this->assertNotEmpty($hubs->json('data.delivery_part.drivers'));
        $this->assertGreaterThan(0, $hubs->json('data.delivery_part.kpis.total_drivers'));

        // 2. Admin creates a live order from Customer Hub -> verify PIN handover & delivery
        $store = Store::with('products')->firstOrFail();
        $product = $store->products->firstOrFail();

        $adminCreated = $this->asBearer($adminToken)->postJson('/api/v1/admin/orders', [
            'store_id' => $store->id,
            'customer_name' => 'هێرش مەحموود',
            'customer_phone' => '07705554433',
            'delivery_address' => 'گەڕەکی زانکۆ - کەلار',
            'delivery_lat' => 34.6950,
            'delivery_lng' => 45.3280,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
        ])->assertCreated();

        $orderId = $adminCreated->json('data.id');
        $handoverPin = $adminCreated->json('data.handover_pin');
        $deliveryPin = $adminCreated->json('data.delivery_pin');

        $this->asBearer($adminToken)
            ->postJson("/api/v1/admin/orders/{$orderId}/verify-handover", ['pin' => $handoverPin])
            ->assertOk()
            ->assertJsonPath('data.status', 'picked_up');

        $this->asBearer($adminToken)
            ->postJson("/api/v1/admin/orders/{$orderId}/verify-delivery", ['pin' => $deliveryPin])
            ->assertOk()
            ->assertJsonPath('data.status', 'delivered');

        // 3. Public Customer App (`rega`) places order & syncs customer order history
        $pubOrder = $this->postJson('/api/v1/public/orders', [
            'store_id' => $store->id,
            'store_name' => $store->name_ku,
            'neighborhood_name' => 'گەڕەکی زانکۆ',
            'customer_name' => 'سەربەست عەلی',
            'customer_phone' => '07703331122',
            'delivery_address' => 'گەڕەکی زانکۆ - شاری کەلار',
            'delivery_lat' => 34.7010,
            'delivery_lng' => 45.3315,
            'delivery_fee' => 1000,
            'items' => [
                [
                    'product_id' => $product->id,
                    'name' => $product->name_ku,
                    'quantity' => 1,
                    'price' => $product->effectivePrice(),
                ],
            ],
        ])->assertCreated();

        $pubOrderNumber = $pubOrder->json('data.order_number');
        $this->assertNotEmpty($pubOrderNumber);

        $custOrders = $this->getJson('/api/v1/public/customer-orders?phone=07703331122')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertNotEmpty($custOrders->json('data'));
    }

    public function test_vendor_mark_ready_auto_finds_nearest_driver_and_sends_order(): void
    {
        $vendorLogin = $this->postJson('/api/v1/auth/login', [
            'phone' => '07701112233', // Mam Rashid store owner
            'password' => 'password123',
        ])->assertOk();
        $vendorToken = $vendorLogin->json('data.token');

        // Ensure driver RA-884 is online with location
        $driverLogin = $this->postJson('/api/v1/auth/login', [
            'phone' => '07501234567', // Rawand Karim
            'password' => 'password123',
        ])->assertOk();
        $driverToken = $driverLogin->json('data.token');

        $this->withToken($driverToken)->patchJson('/api/v1/driver/status', ['is_online' => true])->assertOk();
        $this->withToken($driverToken)->patchJson('/api/v1/driver/location', [
            'lat' => 34.6840,
            'lng' => 45.3195,
        ])->assertOk();

        // Customer places order without pre-assigned driver
        $custLogin = $this->postJson('/api/v1/auth/login', [
            'phone' => '07703331122',
            'password' => 'password123',
        ])->assertOk();
        $custToken = $custLogin->json('data.token');

        $store = Store::where('slug', 'mam-rashid')->with('products')->firstOrFail();
        $product = $store->products->firstOrFail();

        $orderRes = $this->asBearer($custToken)->postJson('/api/v1/customer/orders', [
            'store_id' => $store->id,
            'delivery_address' => 'گەڕەکی زانکۆ - کەلار',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1],
            ],
        ])->assertCreated();

        $orderId = $orderRes->json('data.id');

        // Unset driver if any to test automatic nearest driver matching
        Order::where('id', $orderId)->update(['driver_id' => null, 'driver_status' => 'unassigned']);

        // Vendor accepts order
        $this->asBearer($vendorToken)->postJson("/api/v1/vendor/orders/{$orderId}/accept")->assertOk();

        // Vendor marks order ready / clicks ready for driver -> auto finds nearest driver & sends order
        $readyRes = $this->asBearer($vendorToken)
            ->postJson("/api/v1/vendor/orders/{$orderId}/ready")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertNotNull($readyRes->json('data.driver_id'));
        $this->assertEquals('ready', $readyRes->json('data.status'));
        $this->assertEquals('driver_assigned', $readyRes->json('data.driver_status'));

        // Verify driver now sees this order in driver active-order endpoint
        $driverActiveRes = $this->asBearer($driverToken)
            ->getJson('/api/v1/driver/orders/active')
            ->assertOk();

        $this->assertEquals($orderId, $driverActiveRes->json('data.id'));

        // Test explicit vendor dispatch endpoint as well
        $dispatchRes = $this->asBearer($vendorToken)
            ->postJson("/api/v1/vendor/orders/{$orderId}/dispatch-driver")
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertNotNull($dispatchRes->json('data.driver.id'));
    }
}
