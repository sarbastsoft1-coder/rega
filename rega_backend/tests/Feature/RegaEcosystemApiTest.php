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
}
