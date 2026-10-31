<?php

use App\Http\Controllers\Api\Admin\CatalogAndZonesController;
use App\Http\Controllers\Api\Admin\CustomerManagementController;
use App\Http\Controllers\Api\Admin\DashboardController;
use App\Http\Controllers\Api\Admin\DriverManagementController;
use App\Http\Controllers\Api\Admin\FinanceAndSupportController;
use App\Http\Controllers\Api\Admin\MarketingController;
use App\Http\Controllers\Api\Admin\OrderManagementController;
use App\Http\Controllers\Api\Admin\ProductManagementController;
use App\Http\Controllers\Api\Admin\StoreManagementController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DriverAppController;
use App\Http\Controllers\Api\PublicAndCustomerController;
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
    // --- Public Catalog & Bootstrap (Customer App `rega`) ---
    Route::prefix('public')->group(function () {
        Route::get('/bootstrap', [PublicAndCustomerController::class, 'bootstrap']);
        Route::get('/stores', [PublicAndCustomerController::class, 'stores']);
        Route::get('/stores/{store}', [PublicAndCustomerController::class, 'storeDetails']);
        Route::get('/search', [PublicAndCustomerController::class, 'search']);
        Route::get('/notifications', [PublicAndCustomerController::class, 'notifications']);
    });

    // --- Authentication (All Apps) ---
    Route::prefix('auth')->group(function () {
        Route::post('/login', [AuthController::class, 'login']);
        Route::post('/register', [AuthController::class, 'register']);

        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/me', [AuthController::class, 'me']);
            Route::put('/profile', [AuthController::class, 'updateProfile']);
            Route::post('/change-password', [AuthController::class, 'changePassword']);
            Route::post('/logout', [AuthController::class, 'logout']);
        });
    });

    // --- Authenticated Customer App (`rega`) ---
    Route::middleware('auth:sanctum')->prefix('customer')->group(function () {
        Route::post('/coupons/validate', [PublicAndCustomerController::class, 'validateCoupon']);
        Route::post('/orders', [PublicAndCustomerController::class, 'placeOrder']);
        Route::get('/orders', [PublicAndCustomerController::class, 'customerOrders']);
        Route::get('/orders/{order}/tracking', [PublicAndCustomerController::class, 'trackOrder']);
        Route::get('/addresses', [PublicAndCustomerController::class, 'addresses']);
        Route::post('/addresses', [PublicAndCustomerController::class, 'storeAddress']);
        Route::delete('/addresses/{address}', [PublicAndCustomerController::class, 'deleteAddress']);
        Route::post('/favorites/{store}', [PublicAndCustomerController::class, 'toggleFavorite']);
        Route::get('/notifications', [PublicAndCustomerController::class, 'notifications']);
    });

    // --- Vendor / Seller App (`rega_froshyar`) ---
    Route::middleware(['auth:sanctum', 'role:vendor,super_admin,admin'])->prefix('vendor')->group(function () {
        Route::get('/store', [VendorAppController::class, 'storeProfile']);
        Route::patch('/store', [VendorAppController::class, 'updateStore']);
        Route::patch('/store/status', [VendorAppController::class, 'updateOnlineStatus']);

        Route::get('/categories', [VendorAppController::class, 'categories']);
        Route::post('/categories', [VendorAppController::class, 'addCategory']);
        Route::delete('/categories/{storeCategory}', [VendorAppController::class, 'deleteCategory']);

        Route::get('/products', [VendorAppController::class, 'products']);
        Route::post('/products', [VendorAppController::class, 'addProduct']);
        Route::put('/products/{product}', [VendorAppController::class, 'updateProduct']);
        Route::patch('/products/{product}/availability', [VendorAppController::class, 'toggleProductAvailability']);
        Route::delete('/products/{product}', [VendorAppController::class, 'deleteProduct']);

        Route::get('/orders', [VendorAppController::class, 'orders']);
        Route::post('/orders/{order}/accept', [VendorAppController::class, 'acceptOrder']);
        Route::post('/orders/{order}/reject', [VendorAppController::class, 'rejectOrder']);
        Route::post('/orders/{order}/ready', [VendorAppController::class, 'markReady']);
        Route::post('/orders/{order}/handover', [VendorAppController::class, 'handoverToDriver']);

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
        // Dashboard & Analytics
        Route::get('/dashboard', [DashboardController::class, 'overview']);

        // Orders & Dispatch
        Route::get('/orders', [OrderManagementController::class, 'index']);
        Route::get('/orders/{order}', [OrderManagementController::class, 'show']);
        Route::post('/orders/{order}/assign-driver', [OrderManagementController::class, 'assignDriver']);
        Route::patch('/orders/{order}/status', [OrderManagementController::class, 'updateStatus']);
        Route::post('/orders/{order}/waiting-bonus', [OrderManagementController::class, 'addWaitingBonus']);

        // Stores / Vendors
        Route::get('/stores', [StoreManagementController::class, 'index']);
        Route::post('/stores', [StoreManagementController::class, 'store']);
        Route::get('/stores/{store}', [StoreManagementController::class, 'show']);
        Route::put('/stores/{store}', [StoreManagementController::class, 'update']);
        Route::patch('/stores/{store}/toggle', [StoreManagementController::class, 'toggleStatus']);
        Route::delete('/stores/{store}', [StoreManagementController::class, 'destroy']);
        Route::post('/stores/{store}/categories', [StoreManagementController::class, 'addStoreCategory']);
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
        Route::patch('/driver-documents/{document}/verify', [DriverManagementController::class, 'verifyDocument']);

        // Customers
        Route::get('/customers', [CustomerManagementController::class, 'index']);
        Route::post('/customers', [CustomerManagementController::class, 'store']);
        Route::get('/customers/{customer}', [CustomerManagementController::class, 'show']);
        Route::put('/customers/{customer}', [CustomerManagementController::class, 'update']);
        Route::patch('/customers/{customer}/toggle-active', [CustomerManagementController::class, 'toggleActive']);

        // Categories & Kalar Neighborhoods
        Route::get('/categories', [CatalogAndZonesController::class, 'categoriesIndex']);
        Route::post('/categories', [CatalogAndZonesController::class, 'categoriesStore']);
        Route::put('/categories/{category}', [CatalogAndZonesController::class, 'categoriesUpdate']);
        Route::delete('/categories/{category}', [CatalogAndZonesController::class, 'categoriesDestroy']);

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

        Route::get('/tickets', [FinanceAndSupportController::class, 'ticketsIndex']);
        Route::patch('/tickets/{ticket}', [FinanceAndSupportController::class, 'ticketsUpdate']);

        Route::get('/settings', [FinanceAndSupportController::class, 'settingsIndex']);
        Route::put('/settings', [FinanceAndSupportController::class, 'settingsUpdate']);

        Route::post('/upload', [FinanceAndSupportController::class, 'uploadMedia']);
    });
});
