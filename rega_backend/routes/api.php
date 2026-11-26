<?php

use App\Http\Controllers\Api\Admin\AdminInboxController;
use App\Http\Controllers\Api\Admin\AdminStaffController;
use App\Http\Controllers\Api\Admin\BackupController;
use App\Http\Controllers\Api\Admin\CatalogAndZonesController;
use App\Http\Controllers\Api\Admin\CustomerManagementController;
use App\Http\Controllers\Api\Admin\DashboardController;
use App\Http\Controllers\Api\Admin\DriverManagementController;
use App\Http\Controllers\Api\Admin\EcosystemHubController;
use App\Http\Controllers\Api\Admin\AccountingController;
use App\Http\Controllers\Api\Admin\FinanceAndSupportController;
use App\Http\Controllers\Api\Admin\MarketingController;
use App\Http\Controllers\Api\Admin\OrderManagementController;
use App\Http\Controllers\Api\Admin\ProductManagementController;
use App\Http\Controllers\Api\Admin\StoreManagementController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DriverAppController;
use App\Http\Controllers\Api\LiveTelemetryController;
use App\Http\Controllers\Api\PublicAndCustomerController;
use App\Http\Controllers\Api\MediaController;
use App\Http\Controllers\Api\VendorAppController;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    $dbOk = false;
    try {
        DB::connection()->getPdo();
        $dbOk = true;
    } catch (\Throwable) {
        $dbOk = false;
    }

    return response()->json([
        'success' => true,
        'service' => 'REGA Unified API',
        'database' => 'PostgreSQL',
        'db_connected' => $dbOk,
        'timestamp' => now()->toIso8601String(),
    ]);
});

Route::prefix('v1')->group(function () {
    // Public media (CORS-safe for Flutter web CanvasKit)
    Route::get('/media/{path}', [MediaController::class, 'show'])
        ->where('path', '.*');

    // --- Public Catalog & Bootstrap (Customer App `rega`) ---
    Route::prefix('public')->group(function () {
        Route::get('/bootstrap', [PublicAndCustomerController::class, 'bootstrap']);
        Route::get('/categories', [PublicAndCustomerController::class, 'categories']);
        Route::get('/support-contacts', [PublicAndCustomerController::class, 'supportContacts']);
        Route::get('/stores', [PublicAndCustomerController::class, 'stores']);
        Route::get('/stores/{store}', [PublicAndCustomerController::class, 'storeDetails']);
        Route::get('/search', [PublicAndCustomerController::class, 'search']);
        Route::get('/notifications', [PublicAndCustomerController::class, 'notifications']);
        Route::post('/coupons/validate', [PublicAndCustomerController::class, 'validateCoupon']);
        Route::post('/orders', [PublicAndCustomerController::class, 'publicPlaceOrder']);
        Route::get('/customer-orders', [PublicAndCustomerController::class, 'publicCustomerOrders']);
        Route::delete('/customer-orders/{id}', [PublicAndCustomerController::class, 'publicDeleteCustomerOrder']);
    });

    // --- Real-Time 1-Second Live GPS Telemetry & Route Sync (`rega`, `rega_delivery`, `rega_admin`) ---
    Route::prefix('live-telemetry')->group(function () {
        Route::post('/register', [LiveTelemetryController::class, 'registerOrder']);
        Route::get('/latest-active', [LiveTelemetryController::class, 'latestActive']);
        Route::get('/{orderRef}', [LiveTelemetryController::class, 'show']);
        Route::post('/{orderRef}', [LiveTelemetryController::class, 'pushTick']);
        Route::post('/{orderRef}/verify-pin', [LiveTelemetryController::class, 'verifyPin']);
    });

    // --- Authentication (All Apps) ---
    Route::prefix('auth')->group(function () {
        Route::post('/login', [AuthController::class, 'login']);
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/password-reset/request-otp', [AuthController::class, 'requestPasswordResetOtp']);
        Route::post('/password-reset/confirm', [AuthController::class, 'resetPasswordWithOtp']);

        Route::middleware(['auth:sanctum', 'active'])->group(function () {
            Route::get('/me', [AuthController::class, 'me']);
            Route::put('/profile', [AuthController::class, 'updateProfile']);
            Route::post('/change-password', [AuthController::class, 'changePassword']);
            Route::post('/logout', [AuthController::class, 'logout']);
        });
    });

    // --- Authenticated Customer App (`rega`) ---
    Route::middleware(['auth:sanctum', 'active'])->prefix('customer')->group(function () {
        Route::post('/coupons/validate', [PublicAndCustomerController::class, 'validateCoupon']);
        Route::post('/orders', [PublicAndCustomerController::class, 'placeOrder']);
        Route::get('/orders', [PublicAndCustomerController::class, 'customerOrders']);
        Route::delete('/orders/{id}', [PublicAndCustomerController::class, 'deleteCustomerOrder']);
        Route::get('/orders/{order}/tracking', [PublicAndCustomerController::class, 'trackOrder']);
        Route::get('/addresses', [PublicAndCustomerController::class, 'addresses']);
        Route::post('/addresses', [PublicAndCustomerController::class, 'storeAddress']);
        Route::delete('/addresses/{address}', [PublicAndCustomerController::class, 'deleteAddress']);
        Route::post('/favorites/{store}', [PublicAndCustomerController::class, 'toggleFavorite']);
        Route::get('/notifications', [PublicAndCustomerController::class, 'notifications']);
        Route::post('/notifications/mark-read', [PublicAndCustomerController::class, 'markNotificationsRead']);
        Route::post('/direct-requests', [PublicAndCustomerController::class, 'submitDirectRequest']);
        Route::post('/direct-requests/upload', [PublicAndCustomerController::class, 'uploadDirectRequestMedia']);
    });

    // --- Vendor / Seller App (`rega_froshyar`) ---
    Route::middleware(['auth:sanctum', 'role:vendor,super_admin,admin'])->prefix('vendor')->group(function () {
        Route::get('/store', [VendorAppController::class, 'storeProfile']);
        Route::patch('/store', [VendorAppController::class, 'updateStore']);
        Route::patch('/store/status', [VendorAppController::class, 'updateOnlineStatus']);
        Route::post('/store/discount', [VendorAppController::class, 'applyStoreDiscount']);

        Route::get('/categories', [VendorAppController::class, 'categories']);
        Route::post('/categories', [VendorAppController::class, 'addCategory']);
        Route::put('/categories/{storeCategory}', [VendorAppController::class, 'updateCategory']);
        Route::delete('/categories/{storeCategory}', [VendorAppController::class, 'deleteCategory']);

        Route::get('/products', [VendorAppController::class, 'products']);
        Route::post('/products', [VendorAppController::class, 'addProduct']);
        Route::put('/products/{product}', [VendorAppController::class, 'updateProduct']);
        Route::patch('/products/{product}/availability', [VendorAppController::class, 'toggleProductAvailability']);
        Route::delete('/products/{product}', [VendorAppController::class, 'deleteProduct']);
        Route::post('/upload', [VendorAppController::class, 'uploadMedia']);

        Route::get('/orders', [VendorAppController::class, 'orders']);
        Route::delete('/orders/completed', [VendorAppController::class, 'clearCompletedOrders']);
        Route::delete('/orders/{order}', [VendorAppController::class, 'deleteOrder']);
        Route::post('/orders/{order}/accept', [VendorAppController::class, 'acceptOrder']);
        Route::post('/orders/{order}/reject', [VendorAppController::class, 'rejectOrder']);
        Route::post('/orders/{order}/ready', [VendorAppController::class, 'markReady']);
        Route::post('/orders/{order}/dispatch-driver', [VendorAppController::class, 'dispatchNearestDriver']);
        Route::post('/orders/{order}/assign-driver', [VendorAppController::class, 'assignDriver']);
        Route::post('/orders/{order}/handover', [VendorAppController::class, 'handoverToDriver']);
        Route::get('/nearby-drivers', [VendorAppController::class, 'nearbyDrivers']);

        Route::get('/analytics/revenue', [VendorAppController::class, 'revenueAnalytics']);
    });

    // --- Delivery Driver App (`rega_delivery`) ---
    Route::middleware(['auth:sanctum', 'role:driver,super_admin,admin'])->prefix('driver')->group(function () {
        Route::get('/profile', [DriverAppController::class, 'profile']);
        Route::patch('/status', [DriverAppController::class, 'updateStatus']);
        Route::patch('/location', [DriverAppController::class, 'updateLocation']);

        Route::get('/orders/active', [DriverAppController::class, 'activeOrder']);
        Route::get('/orders', [DriverAppController::class, 'ordersHistory']);
        Route::patch('/orders/{order}/status', [DriverAppController::class, 'advanceOrderStatus']);
        Route::post('/orders/{order}/verify-delivery', [DriverAppController::class, 'verifyDeliveryPin']);
        Route::post('/orders/{order}/waiting-bonus', [DriverAppController::class, 'claimWaitingBonus']);
        Route::post('/orders/{order}/cancel-request', [DriverAppController::class, 'requestCancellation']);

        Route::get('/earnings', [DriverAppController::class, 'earnings']);
    });

    // --- Admin Control Center (`rega_admin`) ---
    Route::middleware(['auth:sanctum', 'role:super_admin,admin,dispatcher'])->prefix('admin')->group(function () {
        // Dashboard & Analytics + 3 Core Ecosystem Parts (Vendor / Customer / Delivery)
        Route::get('/dashboard', [DashboardController::class, 'overview']);
        Route::get('/ecosystem-hubs', [EcosystemHubController::class, 'overview']);
        Route::get('/live-radar', [LiveTelemetryController::class, 'adminRadar']);

        // Admin work inbox (live pending orders / stores / drivers / tickets)
        Route::get('/inbox', [AdminInboxController::class, 'index']);
        Route::get('/inbox/unread-count', [AdminInboxController::class, 'unreadCount']);
        Route::post('/inbox/mark-read', [AdminInboxController::class, 'markRead']);
        Route::post('/inbox/mark-all-read', [AdminInboxController::class, 'markAllRead']);

        // Orders & Dispatch
        Route::get('/orders', [OrderManagementController::class, 'index']);
        Route::post('/orders', [EcosystemHubController::class, 'createOrder']);
        Route::get('/orders/{order}', [OrderManagementController::class, 'show']);
        Route::put('/orders/{order}', [OrderManagementController::class, 'update']);
        Route::delete('/orders/{order}', [OrderManagementController::class, 'destroy']);
        Route::post('/orders/{order}/assign-driver', [OrderManagementController::class, 'assignDriver']);
        Route::patch('/orders/{order}/status', [OrderManagementController::class, 'updateStatus']);
        Route::post('/orders/{order}/waiting-bonus', [OrderManagementController::class, 'addWaitingBonus']);
        Route::post('/orders/{order}/verify-handover', [EcosystemHubController::class, 'verifyHandoverPin']);
        Route::post('/orders/{order}/verify-delivery', [EcosystemHubController::class, 'verifyDeliveryPin']);

        // Stores / Vendors
        Route::get('/stores', [StoreManagementController::class, 'index']);
        Route::post('/stores', [StoreManagementController::class, 'store']);
        Route::get('/stores/{store}', [StoreManagementController::class, 'show']);
        Route::put('/stores/{store}', [StoreManagementController::class, 'update']);
        Route::patch('/stores/{store}/toggle', [StoreManagementController::class, 'toggleStatus']);
        Route::delete('/stores/{store}', [StoreManagementController::class, 'destroy']);
        Route::get('/store-categories', [StoreManagementController::class, 'storeCategoriesIndex']);
        Route::post('/stores/{store}/categories', [StoreManagementController::class, 'addStoreCategory']);
        Route::put('/store-categories/reorder', [StoreManagementController::class, 'reorderStoreCategories']);
        Route::put('/store-categories/{storeCategory}', [StoreManagementController::class, 'updateStoreCategory']);
        Route::delete('/store-categories/{storeCategory}', [StoreManagementController::class, 'deleteStoreCategory']);

        // Products
        Route::get('/products', [ProductManagementController::class, 'index']);
        Route::post('/products', [ProductManagementController::class, 'store']);
        Route::put('/products/{product}', [ProductManagementController::class, 'update']);
        Route::patch('/products/{product}/toggle-availability', [ProductManagementController::class, 'toggleAvailability']);
        Route::delete('/products/{product}', [ProductManagementController::class, 'destroy']);

        // Drivers & KYC
        Route::get('/drivers', [DriverManagementController::class, 'index']);
        Route::post('/drivers', [DriverManagementController::class, 'store']);
        Route::get('/drivers/{driverProfile}', [DriverManagementController::class, 'show']);
        Route::put('/drivers/{driverProfile}', [DriverManagementController::class, 'update']);
        Route::patch('/drivers/{driverProfile}/toggle', [DriverManagementController::class, 'toggleStatus']);
        Route::patch('/drivers/{driverProfile}/toggle-active', [DriverManagementController::class, 'toggleActive']);
        Route::get('/drivers/{driverProfile}/documents', [DriverManagementController::class, 'documents']);
        Route::patch('/driver-documents/{document}/verify', [DriverManagementController::class, 'verifyDocument']);
        Route::post('/driver-documents/{document}/upload', [DriverManagementController::class, 'uploadDocument']);
        Route::match(['put', 'patch', 'post'], '/driver-documents/{document}', [DriverManagementController::class, 'updateDocument']);

        // Customers
        Route::get('/customers', [CustomerManagementController::class, 'index']);
        Route::post('/customers', [CustomerManagementController::class, 'store']);
        Route::get('/customers/{customer}', [CustomerManagementController::class, 'show']);
        Route::put('/customers/{customer}', [CustomerManagementController::class, 'update']);
        Route::patch('/customers/{customer}/toggle-active', [CustomerManagementController::class, 'toggleActive']);
        Route::delete('/customers/{customer}', [CustomerManagementController::class, 'destroy']);

        // Categories & Kalar Neighborhoods
        Route::get('/categories', [CatalogAndZonesController::class, 'categoriesIndex']);
        Route::post('/categories', [CatalogAndZonesController::class, 'categoriesStore']);
        Route::put('/categories/reorder', [CatalogAndZonesController::class, 'categoriesReorder']);
        Route::put('/categories/{category}', [CatalogAndZonesController::class, 'categoriesUpdate']);
        Route::delete('/categories/{category}', [CatalogAndZonesController::class, 'categoriesDestroy']);

        Route::get('/service-cities', [CatalogAndZonesController::class, 'serviceCitiesIndex']);
        Route::post('/service-cities', [CatalogAndZonesController::class, 'serviceCitiesStore']);
        Route::put('/service-cities/{serviceCity}', [CatalogAndZonesController::class, 'serviceCitiesUpdate']);
        Route::delete('/service-cities/{serviceCity}', [CatalogAndZonesController::class, 'serviceCitiesDestroy']);

        Route::get('/neighborhoods', [CatalogAndZonesController::class, 'neighborhoodsIndex']);
        Route::post('/neighborhoods', [CatalogAndZonesController::class, 'neighborhoodsStore']);
        Route::put('/neighborhoods/{neighborhood}', [CatalogAndZonesController::class, 'neighborhoodsUpdate']);
        Route::delete('/neighborhoods/{neighborhood}', [CatalogAndZonesController::class, 'neighborhoodsDestroy']);

        // Marketing: Coupons, Banners & Notifications
        Route::get('/coupons', [MarketingController::class, 'couponsIndex']);
        Route::post('/coupons', [MarketingController::class, 'couponsStore']);
        Route::put('/coupons/{coupon}', [MarketingController::class, 'couponsUpdate']);
        Route::delete('/coupons/{coupon}', [MarketingController::class, 'couponsDestroy']);

        Route::get('/banners', [MarketingController::class, 'bannersIndex']);
        Route::post('/banners', [MarketingController::class, 'bannersStore']);
        Route::put('/banners/{banner}', [MarketingController::class, 'bannersUpdate']);
        Route::delete('/banners/{banner}', [MarketingController::class, 'bannersDestroy']);

        Route::get('/notifications', [MarketingController::class, 'notificationsIndex']);
        Route::post('/notifications', [MarketingController::class, 'notificationsSend']);
        Route::delete('/notifications/{notification}', [MarketingController::class, 'notificationsDestroy']);

        // Finance, Payouts, Support Tickets & Settings
        Route::get('/finance/summary', [FinanceAndSupportController::class, 'financeSummary']);
        Route::get('/payouts', [FinanceAndSupportController::class, 'payoutsIndex']);
        Route::post('/payouts', [FinanceAndSupportController::class, 'payoutsStore']);
        Route::patch('/payouts/{payout}/status', [FinanceAndSupportController::class, 'payoutsUpdateStatus']);

        // Accounting & Profit Management
        Route::get('/accounting/dashboard', [AccountingController::class, 'dashboard']);
        Route::get('/accounting/shops', [AccountingController::class, 'shopIndex']);
        Route::get('/accounting/shops/{store}', [AccountingController::class, 'shopShow']);
        Route::get('/accounting/orders', [AccountingController::class, 'ordersIndex']);
        Route::get('/accounting/orders/{order}', [AccountingController::class, 'orderShow']);
        Route::post('/accounting/orders/{order}/refund', [AccountingController::class, 'refundOrder']);
        Route::get('/accounting/profit-settings', [AccountingController::class, 'profitSettings']);
        Route::put('/accounting/profit-settings', [AccountingController::class, 'updateProfitSettings']);
        Route::get('/accounting/reports', [AccountingController::class, 'reports']);
        Route::get('/accounting/reports/export', [AccountingController::class, 'exportReport']);
        Route::get('/accounting/transactions', [AccountingController::class, 'transactions']);

        Route::get('/tickets', [FinanceAndSupportController::class, 'ticketsIndex']);
        Route::post('/tickets', [FinanceAndSupportController::class, 'ticketsStore']);
        Route::patch('/tickets/{ticket}', [FinanceAndSupportController::class, 'ticketsUpdate']);

        Route::get('/settings', [FinanceAndSupportController::class, 'settingsIndex']);
        Route::put('/settings', [FinanceAndSupportController::class, 'settingsUpdate']);

        Route::post('/upload', [FinanceAndSupportController::class, 'uploadMedia']);

        // Excel backups (manual download + scheduled weekly/monthly files)
        Route::get('/backup/export', [BackupController::class, 'export']);
        Route::post('/backup/export', [BackupController::class, 'export']);
        Route::get('/backups', [BackupController::class, 'index']);
        Route::get('/backups/{file}', [BackupController::class, 'download']);

        // Admin staff accounts (create / edit / deactivate)
        Route::get('/staff', [AdminStaffController::class, 'index']);
        Route::post('/staff', [AdminStaffController::class, 'store']);
        Route::put('/staff/{adminUser}', [AdminStaffController::class, 'update']);
        Route::patch('/staff/{adminUser}/toggle-active', [AdminStaffController::class, 'toggleActive']);
        Route::delete('/staff/{adminUser}', [AdminStaffController::class, 'destroy']);
    });
});
