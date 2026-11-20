<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminInboxRead;
use App\Models\DriverProfile;
use App\Models\Order;
use App\Models\Store;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Admin work inbox: live alerts derived from pending DB work
 * (orders / unapproved stores / unverified drivers / open tickets),
 * with per-admin read state via admin_inbox_reads.
 */
class AdminInboxController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $adminId = (int) $request->user()->id;
        $items = $this->buildItems($adminId);

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $items,
                'unread_count' => $this->sumUnreadCounts($items),
                'unread_items' => collect($items)->where('is_read', false)->count(),
            ],
        ]);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $adminId = (int) $request->user()->id;
        $items = $this->buildItems($adminId);

        return response()->json([
            'success' => true,
            'data' => [
                'unread_count' => $this->sumUnreadCounts($items),
                'unread_items' => collect($items)->where('is_read', false)->count(),
            ],
        ]);
    }

    public function markRead(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'item_key' => ['required', 'string', 'max:80'],
        ]);

        $adminId = (int) $request->user()->id;
        $items = collect($this->buildItems($adminId));
        $item = $items->firstWhere('id', $validated['item_key']);

        if (!$item) {
            return response()->json([
                'success' => false,
                'message' => 'ئاگاداری نەدۆزرایەوە یان چیتر لە چاوەڕوانیدا نییە.',
            ], 404);
        }

        $this->upsertRead($adminId, $item['id'], $item['fingerprint']);

        $fresh = $this->buildItems($adminId);

        return response()->json([
            'success' => true,
            'message' => 'ئاگاداری بە خوێندراو دانرا.',
            'data' => [
                'items' => $fresh,
                'unread_count' => $this->sumUnreadCounts($fresh),
            ],
        ]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        $adminId = (int) $request->user()->id;
        $items = $this->buildItems($adminId);

        foreach ($items as $item) {
            $this->upsertRead($adminId, $item['id'], $item['fingerprint']);
        }

        $fresh = $this->buildItems($adminId);

        return response()->json([
            'success' => true,
            'message' => 'هەموو ئاگادارییەکان بە خوێندراو دانران.',
            'data' => [
                'items' => $fresh,
                'unread_count' => $this->sumUnreadCounts($fresh),
            ],
        ]);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function buildItems(int $adminId): array
    {
        $reads = AdminInboxRead::query()
            ->where('admin_user_id', $adminId)
            ->get()
            ->keyBy('item_key');

        $items = [];

        // 1) Pending orders (status = pending)
        $pendingOrders = Order::query()
            ->where('status', 'pending')
            ->orderByDesc('created_at')
            ->get(['id', 'order_number', 'created_at', 'updated_at']);
        if ($pendingOrders->isNotEmpty()) {
            $ids = $pendingOrders->pluck('id')->sort()->values()->all();
            $latest = $pendingOrders->first();
            $count = $pendingOrders->count();
            $items[] = $this->makeItem(
                id: 'pending_orders',
                type: 'pending_orders',
                titleKu: 'داواکاری لە چاوەڕوانیدایە',
                bodyKu: $count === 1
                    ? '1 داواکاری نوێ چاوەڕوانی وەڵامە'
                    : "{$count} داواکاری نوێ چاوەڕوانی وەڵامن",
                count: $count,
                fingerprint: $this->fingerprint($ids, $latest?->updated_at),
                createdAt: $latest?->created_at,
                route: '/order-intake',
                tabIndex: 1,
                icon: 'receipt',
                color: '#EA580C',
                reads: $reads,
            );
        }

        // 2) Sellers / stores awaiting admin approval
        $pendingStores = Store::query()
            ->where('is_approved', false)
            ->orderByDesc('created_at')
            ->get(['id', 'name_ku', 'created_at', 'updated_at']);
        if ($pendingStores->isNotEmpty()) {
            $ids = $pendingStores->pluck('id')->sort()->values()->all();
            $latest = $pendingStores->first();
            $count = $pendingStores->count();
            $items[] = $this->makeItem(
                id: 'pending_stores',
                type: 'pending_stores',
                titleKu: 'فرۆشیاری نوێ لە چاوەڕوانیدایە',
                bodyKu: $count === 1
                    ? '1 فرۆشگا چاوەڕوانی پەسەندکردنی کارگێڕییە'
                    : "{$count} فرۆشگا چاوەڕوانی پەسەندکردنی کارگێڕین",
                count: $count,
                fingerprint: $this->fingerprint($ids, $latest?->updated_at),
                createdAt: $latest?->created_at,
                route: '/stores',
                tabIndex: 5,
                icon: 'storefront',
                color: '#D97706',
                reads: $reads,
            );
        }

        // 3) Captains / riders awaiting document (KYC) verification
        $pendingDrivers = DriverProfile::query()
            ->with('user:id,name')
            ->where('is_verified', false)
            ->orderByDesc('created_at')
            ->get(['id', 'user_id', 'driver_code', 'created_at', 'updated_at']);
        if ($pendingDrivers->isNotEmpty()) {
            $ids = $pendingDrivers->pluck('id')->sort()->values()->all();
            $latest = $pendingDrivers->first();
            $count = $pendingDrivers->count();
            $items[] = $this->makeItem(
                id: 'pending_drivers',
                type: 'pending_drivers',
                titleKu: 'ماتۆڕسوار لە چاوەڕوانیدایە',
                bodyKu: $count === 1
                    ? '1 ماتۆڕسوار چاوەڕوانی پەسەندکردنی بەڵگەنامەن'
                    : "{$count} ماتۆڕسوار چاوەڕوانی پەسەندکردنی بەڵگەنامەن",
                count: $count,
                fingerprint: $this->fingerprint($ids, $latest?->updated_at),
                createdAt: $latest?->created_at,
                route: '/drivers',
                tabIndex: 3,
                icon: 'motorcycle',
                color: '#16A34A',
                reads: $reads,
            );
        }

        // 4) Customer داواکاری ڕاستەوخۆ (direct requests)
        $directRequests = SupportTicket::query()
            ->where('category', 'direct_request')
            ->whereIn('status', ['open', 'in_progress'])
            ->orderByDesc('updated_at')
            ->get(['id', 'ticket_number', 'subject', 'created_at', 'updated_at']);
        if ($directRequests->isNotEmpty()) {
            $ids = $directRequests->pluck('id')->sort()->values()->all();
            $latest = $directRequests->first();
            $count = $directRequests->count();
            $items[] = $this->makeItem(
                id: 'direct_requests',
                type: 'direct_requests',
                titleKu: 'داواکاری ڕاستەوخۆ',
                bodyKu: $count === 1
                    ? '1 داواکاری ڕاستەوخۆ چاوەڕوانی قبوڵکردنە'
                    : "{$count} داواکاری ڕاستەوخۆ چاوەڕوانی قبوڵکردنن",
                count: $count,
                fingerprint: $this->fingerprint($ids, $latest?->updated_at),
                createdAt: $latest?->updated_at ?? $latest?->created_at,
                route: '/customers',
                tabIndex: 4,
                icon: 'direct_request',
                color: '#D97706',
                reads: $reads,
            );
        }

        // 5) Other open / in-progress support tickets (non direct_request)
        $openTickets = SupportTicket::query()
            ->whereIn('status', ['open', 'in_progress'])
            ->where(function ($q) {
                $q->whereNull('category')->orWhere('category', '!=', 'direct_request');
            })
            ->orderByDesc('updated_at')
            ->get(['id', 'ticket_number', 'subject', 'created_at', 'updated_at']);
        if ($openTickets->isNotEmpty()) {
            $ids = $openTickets->pluck('id')->sort()->values()->all();
            $latest = $openTickets->first();
            $count = $openTickets->count();
            $items[] = $this->makeItem(
                id: 'open_tickets',
                type: 'open_tickets',
                titleKu: 'تیکێتی پشتگیری کراوە',
                bodyKu: $count === 1
                    ? '1 تیکێت چاوەڕوانی وەڵامی کارگێڕییە'
                    : "{$count} تیکێت چاوەڕوانی وەڵامی کارگێڕین",
                count: $count,
                fingerprint: $this->fingerprint($ids, $latest?->updated_at),
                createdAt: $latest?->updated_at ?? $latest?->created_at,
                route: '/support',
                tabIndex: 9,
                icon: 'support',
                color: '#2563EB',
                reads: $reads,
            );
        }

        return $items;
    }

    /**
     * @param  \Illuminate\Support\Collection<string, AdminInboxRead>  $reads
     * @return array<string, mixed>
     */
    private function makeItem(
        string $id,
        string $type,
        string $titleKu,
        string $bodyKu,
        int $count,
        string $fingerprint,
        mixed $createdAt,
        string $route,
        int $tabIndex,
        string $icon,
        string $color,
        $reads,
    ): array {
        $read = $reads->get($id);
        $isRead = $read !== null && (string) $read->fingerprint === $fingerprint;

        $at = $createdAt instanceof Carbon
            ? $createdAt
            : ($createdAt ? Carbon::parse($createdAt) : null);

        return [
            'id' => $id,
            'type' => $type,
            'title_ku' => $titleKu,
            'body_ku' => $bodyKu,
            'count' => $count,
            'fingerprint' => $fingerprint,
            'is_read' => $isRead,
            'created_at' => $at?->toIso8601String(),
            'time_label' => $at ? $this->relativeKu($at) : null,
            'route' => $route,
            'tab_index' => $tabIndex,
            'icon' => $icon,
            'color' => $color,
        ];
    }

    /**
     * @param  list<int|string>  $ids
     */
    private function fingerprint(array $ids, mixed $updatedAt): string
    {
        $stamp = $updatedAt instanceof Carbon
            ? $updatedAt->timestamp
            : ($updatedAt ? Carbon::parse($updatedAt)->timestamp : 0);

        return substr(hash('sha256', implode(',', $ids) . '|' . $stamp), 0, 40);
    }

    private function upsertRead(int $adminId, string $itemKey, string $fingerprint): void
    {
        AdminInboxRead::query()->updateOrCreate(
            [
                'admin_user_id' => $adminId,
                'item_key' => $itemKey,
            ],
            [
                'fingerprint' => $fingerprint,
                'read_at' => now(),
            ]
        );
    }

    /**
     * Badge uses sum of entity counts for unread categories
     * (matches previous dashboard KPI badge behaviour).
     *
     * @param  list<array<string, mixed>>  $items
     */
    private function sumUnreadCounts(array $items): int
    {
        return (int) collect($items)
            ->where('is_read', false)
            ->sum('count');
    }

    private function relativeKu(Carbon $at): string
    {
        $diff = $at->diffInSeconds(now());

        if ($diff < 60) {
            return 'ئێستا';
        }
        if ($diff < 3600) {
            $m = max(1, (int) floor($diff / 60));

            return "{$m} خولەک پێش ئێستا";
        }
        if ($diff < 86400) {
            $h = max(1, (int) floor($diff / 3600));

            return "{$h} کاتژمێر پێش ئێستا";
        }
        $d = max(1, (int) floor($diff / 86400));

        return "{$d} ڕۆژ پێش ئێستا";
    }
}
