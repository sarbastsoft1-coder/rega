<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Payout;
use App\Models\PlatformSetting;
use App\Models\Store;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class FinanceAndSupportController extends Controller
{
    public function financeSummary(): JsonResponse
    {
        $delivered = Order::query()->where('status', 'delivered');

        $totalGmv = (int) (clone $delivered)->sum('total_amount');
        $totalSubtotal = (int) (clone $delivered)->sum('subtotal');
        $totalCommission = (int) (clone $delivered)->sum('commission_amount');
        $totalVendorNet = (int) (clone $delivered)->sum('vendor_net_amount');
        $totalDriverEarnings = (int) (clone $delivered)->sum('driver_total_earning');
        $totalDiscounts = (int) (clone $delivered)->sum('discount_amount');

        $vendorWalletsTotal = (int) Store::sum('wallet_balance');
        $driverWalletsTotal = (int) DriverProfile::sum('wallet_balance');
        $driverCodCashHeld = (int) DriverProfile::sum('cash_collected_hand');

        $completedPayouts = (int) Payout::where('status', 'completed')
            ->where('direction', 'payout_to_partner')
            ->sum('amount');

        $completedCodCollections = (int) Payout::where('status', 'completed')
            ->where('direction', 'cod_collection_from_driver')
            ->sum('amount');

        $pendingPayoutsCount = Payout::where('status', 'pending')->count();

        $storesLedger = Store::query()
            ->with('owner:id,name,phone')
            ->withSum(['orders as gross_sales' => fn ($q) => $q->where('status', 'delivered')], 'total_amount')
            ->withSum(['orders as commission_paid' => fn ($q) => $q->where('status', 'delivered')], 'commission_amount')
            ->withSum(['orders as net_earned' => fn ($q) => $q->where('status', 'delivered')], 'vendor_net_amount')
            ->orderByDesc('wallet_balance')
            ->get();

        $driversLedger = DriverProfile::query()
            ->with('user:id,name,phone')
            ->orderByDesc('cash_collected_hand')
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'summary' => [
                    'total_gmv' => $totalGmv,
                    'total_subtotal' => $totalSubtotal,
                    'total_platform_commission' => $totalCommission,
                    'total_vendor_net_earned' => $totalVendorNet,
                    'total_driver_earnings' => $totalDriverEarnings,
                    'total_discounts' => $totalDiscounts,
                    'unsettled_vendor_wallets' => $vendorWalletsTotal,
                    'unsettled_driver_wallets' => $driverWalletsTotal,
                    'driver_cod_cash_held' => $driverCodCashHeld,
                    'completed_partner_payouts' => $completedPayouts,
                    'completed_cod_collections' => $completedCodCollections,
                    'pending_payouts_count' => $pendingPayoutsCount,
                ],
                'stores_ledger' => $storesLedger,
                'drivers_ledger' => $driversLedger,
            ],
        ]);
    }

    public function payoutsIndex(Request $request): JsonResponse
    {
        $query = Payout::query()
            ->with([
                'user:id,name,phone,role',
                'store:id,name_ku,name_en',
                'processor:id,name',
            ]);

        if ($request->filled('recipient_type')) {
            $query->where('recipient_type', $request->string('recipient_type'));
        }

        if ($request->filled('direction')) {
            $query->where('direction', $request->string('direction'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json([
            'success' => true,
            'data' => $query->latest()->get(),
        ]);
    }

    public function payoutsStore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'recipient_type' => ['required', 'string', 'in:vendor,driver'],
            'direction' => ['required', 'string', 'in:payout_to_partner,cod_collection_from_driver'],
            'store_id' => ['nullable', 'exists:stores,id'],
            'user_id' => ['nullable', 'exists:users,id'],
            'amount' => ['required', 'integer', 'min:250'],
            'payment_method' => ['nullable', 'string', 'in:cash,fib,fastpay,bank_transfer'],
            'status' => ['nullable', 'string', 'in:pending,completed'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $payout = DB::transaction(function () use ($validated, $request) {
            $userId = $validated['user_id'] ?? null;
            $store = null;

            if ($validated['recipient_type'] === 'vendor') {
                $store = Store::findOrFail($validated['store_id']);
                $userId = $userId ?? $store->owner_id ?? $request->user()->id;
            } elseif (! $userId) {
                abort(422, 'شۆفێر دیاری نەکراوە (user_id required).');
            }

            $status = $validated['status'] ?? 'completed';
            $ref = 'PAY-' . now()->format('Ymd') . '-' . strtoupper(Str::random(4));

            $record = Payout::create([
                'reference_code' => $ref,
                'user_id' => $userId,
                'store_id' => $store?->id,
                'recipient_type' => $validated['recipient_type'],
                'direction' => $validated['direction'],
                'amount' => (int) $validated['amount'],
                'payment_method' => $validated['payment_method'] ?? 'cash',
                'status' => $status,
                'notes' => $validated['notes'] ?? null,
                'processed_by' => $status === 'completed' ? $request->user()->id : null,
                'processed_at' => $status === 'completed' ? now() : null,
            ]);

            if ($status === 'completed') {
                $this->applyPayoutBalanceAdjustment($record);
            }

            return $record->load(['user:id,name,phone,role', 'store:id,name_ku,name_en', 'processor:id,name']);
        });

        return response()->json([
            'success' => true,
            'message' => 'مامەڵەی دارایی بە سەرکەوتوویی تۆمارکرا.',
            'data' => $payout,
        ], 201);
    }

    public function payoutsUpdateStatus(Request $request, Payout $payout): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:approved,completed,rejected'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        if ($payout->status === 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'ئەم مامەڵەیە پێشتر تەواوکراوە.',
            ], 422);
        }

        DB::transaction(function () use ($payout, $validated, $request) {
            $newStatus = $validated['status'];

            $payout->update([
                'status' => $newStatus,
                'notes' => $validated['notes'] ?? $payout->notes,
                'processed_by' => $request->user()->id,
                'processed_at' => in_array($newStatus, ['completed', 'rejected'], true) ? now() : null,
            ]);

            if ($newStatus === 'completed') {
                $this->applyPayoutBalanceAdjustment($payout);
            }
        });

        return response()->json([
            'success' => true,
            'message' => 'بارودۆخی مامەڵەی دارایی نوێکرایەوە.',
            'data' => $payout->fresh(['user:id,name,phone,role', 'store:id,name_ku,name_en', 'processor:id,name']),
        ]);
    }

    private function applyPayoutBalanceAdjustment(Payout $payout): void
    {
        $amount = (int) $payout->amount;

        if ($payout->recipient_type === 'vendor' && $payout->store) {
            $newBal = max(0, (int) $payout->store->wallet_balance - $amount);
            $payout->store->update(['wallet_balance' => $newBal]);
        } elseif ($payout->recipient_type === 'driver') {
            $profile = DriverProfile::where('user_id', $payout->user_id)->first();
            if ($profile) {
                if ($payout->direction === 'cod_collection_from_driver') {
                    $newCash = max(0, (int) $profile->cash_collected_hand - $amount);
                    $profile->update(['cash_collected_hand' => $newCash]);
                } else {
                    $newWallet = max(0, (int) $profile->wallet_balance - $amount);
                    $profile->update(['wallet_balance' => $newWallet]);
                }
            }
        }
    }

    // --- Support Tickets ---
    public function ticketsIndex(Request $request): JsonResponse
    {
        $query = SupportTicket::query()
            ->with([
                'user:id,name,phone,role',
                'order:id,order_number,status,total_amount',
                'resolver:id,name',
            ]);

        if ($request->filled('status') && $request->string('status') !== 'all') {
            $query->where('status', $request->string('status'));
        }

        if ($request->filled('priority')) {
            $query->where('priority', $request->string('priority'));
        }

        if ($request->filled('category')) {
            $query->where('category', $request->string('category'));
        }

        return response()->json([
            'success' => true,
            'data' => $query->latest()->get(),
        ]);
    }

    public function ticketsUpdate(Request $request, SupportTicket $ticket): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:open,in_progress,resolved,closed'],
            'admin_reply' => ['nullable', 'string'],
            'priority' => ['nullable', 'string', 'in:low,medium,high,urgent'],
        ]);

        $ticket->update([
            'status' => $validated['status'],
            'admin_reply' => $validated['admin_reply'] ?? $ticket->admin_reply,
            'priority' => $validated['priority'] ?? $ticket->priority,
            'resolved_by' => in_array($validated['status'], ['resolved', 'closed'], true) ? $request->user()->id : $ticket->resolved_by,
            'resolved_at' => in_array($validated['status'], ['resolved', 'closed'], true) ? now() : $ticket->resolved_at,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'سکاڵا / تیکت بە سەرکەوتوویی نوێکرایەوە.',
            'data' => $ticket->fresh(['user:id,name,phone,role', 'order:id,order_number,status', 'resolver:id,name']),
        ]);
    }

    // --- Platform Settings ---
    public function settingsIndex(): JsonResponse
    {
        $rows = PlatformSetting::query()->orderBy('group')->orderBy('key')->get();

        $flat = [];
        foreach ($rows as $row) {
            $val = $row->value;
            $flat[$row->key] = (is_array($val) && array_key_exists('val', $val) && count($val) === 1)
                ? $val['val']
                : $val;
        }

        return response()->json([
            'success' => true,
            'data' => $flat,
            'items' => $rows,
        ]);
    }

    public function settingsUpdate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'settings' => ['required', 'array'],
        ]);

        foreach ($validated['settings'] as $key => $value) {
            PlatformSetting::setValue((string) $key, $value);
        }

        return $this->settingsIndex();
    }

    public function uploadMedia(Request $request): JsonResponse
    {
        $request->validate([
            'file' => ['required', 'file', 'max:10240'],
        ]);

        $path = $request->file('file')->store('uploads', 'public');

        return response()->json([
            'success' => true,
            'message' => 'فایل بە سەرکەوتوویی بارکرا.',
            'data' => [
                'path' => $path,
                'url' => asset('storage/' . $path),
            ],
        ], 201);
    }
}

