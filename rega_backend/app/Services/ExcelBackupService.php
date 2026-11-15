<?php

namespace App\Services;

use App\Models\Banner;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\CustomerAddress;
use App\Models\DriverProfile;
use App\Models\Neighborhood;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payout;
use App\Models\PlatformSetting;
use App\Models\Product;
use App\Models\Store;
use App\Models\StoreCategory;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Support\Facades\Storage;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ExcelBackupService
{
    public const DISK = 'local';

    public const TYPE_MANUAL = 'manual';

    public const TYPE_WEEKLY = 'weekly';

    public const TYPE_MONTHLY = 'monthly';

    /**
     * Build a full multi-sheet workbook and return binary content + meta.
     *
     * @return array{binary: string, file_name: string, sheet_counts: array<string, int>}
     */
    public function buildWorkbook(?string $type = self::TYPE_MANUAL): array
    {
        $type = $this->normalizeType($type);
        $stamp = now()->format('Ymd_His');
        $fileName = "REGA_Backup_{$type}_{$stamp}.xlsx";

        $spreadsheet = new Spreadsheet();
        $spreadsheet->removeSheetByIndex(0);

        $sheetCounts = [];

        $customers = User::query()->where('role', 'customer')->orderBy('id')->get();
        $drivers = DriverProfile::query()->with('user')->orderBy('id')->get();
        $vendors = User::query()->where('role', 'vendor')->orderBy('id')->get();
        $staff = User::query()->whereIn('role', ['super_admin', 'admin', 'dispatcher'])->orderBy('id')->get();
        $stores = Store::query()->with('owner')->orderBy('id')->get();
        $products = Product::query()->orderBy('id')->get();
        $storeCategories = StoreCategory::query()->orderBy('id')->get();
        $orders = Order::query()->orderBy('id')->get();
        $orderItems = OrderItem::query()->orderBy('id')->get();
        $categories = Category::query()->orderBy('id')->get();
        $neighborhoods = Neighborhood::query()->orderBy('id')->get();
        $addresses = CustomerAddress::query()->orderBy('id')->get();
        $coupons = Coupon::query()->orderBy('id')->get();
        $banners = Banner::query()->orderBy('id')->get();
        $payouts = Payout::query()->orderBy('id')->get();
        $tickets = SupportTicket::query()->orderBy('id')->get();
        $settings = PlatformSetting::query()->orderBy('id')->get();

        $sheetCounts['Summary'] = $this->writeSummarySheet($spreadsheet, [
            'type' => $type,
            'customers' => $customers->count(),
            'drivers' => $drivers->count(),
            'vendors' => $vendors->count(),
            'staff' => $staff->count(),
            'stores' => $stores->count(),
            'products' => $products->count(),
            'store_categories' => $storeCategories->count(),
            'orders' => $orders->count(),
            'order_items' => $orderItems->count(),
            'categories' => $categories->count(),
            'neighborhoods' => $neighborhoods->count(),
            'customer_addresses' => $addresses->count(),
            'coupons' => $coupons->count(),
            'banners' => $banners->count(),
            'payouts' => $payouts->count(),
            'support_tickets' => $tickets->count(),
            'platform_settings' => $settings->count(),
        ]);

        $sheetCounts['Customers'] = $this->writeSheet($spreadsheet, 'Customers', [
            'ID', 'Name', 'Phone', 'Email', 'Active', 'Language', 'Last Login', 'Created At',
        ], $customers->map(fn (User $u) => [
            $u->id, $u->name, $u->phone, $u->email, $this->yn($u->is_active), $u->language,
            optional($u->last_login_at)?->toDateTimeString(), optional($u->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Drivers'] = $this->writeSheet($spreadsheet, 'Drivers', [
            'Profile ID', 'User ID', 'Name', 'Phone', 'Driver Code', 'Online', 'Verified', 'Active',
            'Motor Type', 'Plate', 'Model Year', 'Motor Color', 'Wallet', 'COD Cash', 'Deliveries',
            'Rating', 'Completion %', 'Language', 'Created At',
        ], $drivers->map(function (DriverProfile $d) {
            $user = $d->user;

            return [
                $d->id, $d->user_id, $user?->name, $user?->phone, $d->driver_code,
                $this->yn($d->is_online), $this->yn($d->is_verified), $this->yn($user?->is_active),
                $d->motor_type, $d->plate_number, $d->model_year, $d->motor_color,
                $d->wallet_balance, $d->cash_collected_hand, $d->total_deliveries,
                $d->rating, $d->completion_rate, $user?->language,
                optional($d->created_at)?->toDateTimeString(),
            ];
        })->all());

        $sheetCounts['Vendors'] = $this->writeSheet($spreadsheet, 'Vendors', [
            'ID', 'Name', 'Phone', 'Email', 'Active', 'Language', 'Created At',
        ], $vendors->map(fn (User $u) => [
            $u->id, $u->name, $u->phone, $u->email, $this->yn($u->is_active), $u->language,
            optional($u->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Staff'] = $this->writeSheet($spreadsheet, 'Staff', [
            'ID', 'Name', 'Phone', 'Email', 'Role', 'Active', 'Language', 'Last Login', 'Created At',
        ], $staff->map(fn (User $u) => [
            $u->id, $u->name, $u->phone, $u->email, $u->role, $this->yn($u->is_active), $u->language,
            optional($u->last_login_at)?->toDateTimeString(), optional($u->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Stores'] = $this->writeSheet($spreadsheet, 'Stores', [
            'ID', 'Owner ID', 'Owner Name', 'Category ID', 'Neighborhood ID', 'Slug',
            'Name KU', 'Name AR', 'Name EN', 'Phone', 'Address KU', 'Lat', 'Lng',
            'Online', 'Approved', 'Featured', 'Commission %', 'Base Delivery Fee',
            'Wallet', 'Open', 'Close', 'Rating', 'Created At',
        ], $stores->map(fn (Store $s) => [
            $s->id, $s->owner_id, $s->owner?->name, $s->category_id, $s->neighborhood_id, $s->slug,
            $s->name_ku, $s->name_ar, $s->name_en, $s->phone, $s->address_ku, $s->lat, $s->lng,
            $this->yn($s->is_online), $this->yn($s->is_approved), $this->yn($s->is_featured),
            $s->commission_rate, $s->base_delivery_fee, $s->wallet_balance,
            $s->open_time, $s->close_time, $s->rating,
            optional($s->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Products'] = $this->writeSheet($spreadsheet, 'Products', [
            'ID', 'Store ID', 'Store Category ID', 'Name KU', 'Name AR', 'Name EN',
            'Price', 'Discount Price', 'Available', 'Featured', 'Sold Count', 'Created At',
        ], $products->map(fn (Product $p) => [
            $p->id, $p->store_id, $p->store_category_id, $p->name_ku, $p->name_ar, $p->name_en,
            $p->price, $p->discount_price, $this->yn($p->is_available), $this->yn($p->is_featured),
            $p->sold_count, optional($p->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['StoreCategories'] = $this->writeSheet($spreadsheet, 'StoreCategories', [
            'ID', 'Store ID', 'Name KU', 'Name AR', 'Name EN', 'Image URL', 'Secondary Image URL', 'Sort Order', 'Created At',
        ], $storeCategories->map(fn (StoreCategory $c) => [
            $c->id, $c->store_id, $c->name_ku, $c->name_ar, $c->name_en,
            $c->image_url, $c->secondary_image_url, $c->sort_order,
            optional($c->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Orders'] = $this->writeSheet($spreadsheet, 'Orders', [
            'ID', 'Order Number', 'Status', 'Vendor Status', 'Driver Status',
            'Customer ID', 'Customer Name', 'Customer Phone', 'Store ID', 'Driver ID',
            'Neighborhood ID', 'Coupon ID', 'Subtotal', 'Discount', 'Delivery Fee',
            'Tip', 'Waiting Bonus', 'Total', 'Commission Rate', 'Commission Amount',
            'Vendor Net', 'Driver Earning', 'Payment Method', 'Payment Status',
            'Delivery Address', 'Customer Notes', 'Accepted At', 'Delivered At',
            'Cancelled At', 'Created At',
        ], $orders->map(fn (Order $o) => [
            $o->id, $o->order_number, $o->status, $o->vendor_status, $o->driver_status,
            $o->customer_id, $o->customer_name, $o->customer_phone, $o->store_id, $o->driver_id,
            $o->neighborhood_id, $o->coupon_id, $o->subtotal, $o->discount_amount, $o->delivery_fee,
            $o->driver_tip, $o->waiting_bonus, $o->total_amount, $o->commission_rate, $o->commission_amount,
            $o->vendor_net_amount, $o->driver_total_earning, $o->payment_method, $o->payment_status,
            $o->delivery_address, $o->customer_notes,
            optional($o->accepted_at)?->toDateTimeString(),
            optional($o->delivered_at)?->toDateTimeString(),
            optional($o->cancelled_at)?->toDateTimeString(),
            optional($o->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['OrderItems'] = $this->writeSheet($spreadsheet, 'OrderItems', [
            'ID', 'Order ID', 'Product ID', 'Product Name', 'Unit Price', 'Quantity', 'Line Total', 'Notes', 'Created At',
        ], $orderItems->map(fn (OrderItem $i) => [
            $i->id, $i->order_id, $i->product_id, $i->product_name, $i->unit_price, $i->quantity,
            $i->line_total, $i->special_notes, optional($i->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Categories'] = $this->writeSheet($spreadsheet, 'Categories', [
            'ID', 'Slug', 'Name KU', 'Name AR', 'Name EN', 'Active', 'Featured Home', 'Sort', 'Created At',
        ], $categories->map(fn (Category $c) => [
            $c->id, $c->slug, $c->name_ku, $c->name_ar, $c->name_en,
            $this->yn($c->is_active), $this->yn($c->is_featured_home), $c->sort_order,
            optional($c->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Neighborhoods'] = $this->writeSheet($spreadsheet, 'Neighborhoods', [
            'ID', 'Code', 'Name KU', 'Name AR', 'Name EN', 'Delivery Fee', 'ETA Min',
            'Lat', 'Lng', 'Active', 'Sort', 'Created At',
        ], $neighborhoods->map(fn (Neighborhood $n) => [
            $n->id, $n->code, $n->name_ku, $n->name_ar, $n->name_en, $n->delivery_fee,
            $n->estimated_minutes, $n->center_lat, $n->center_lng, $this->yn($n->is_active),
            $n->sort_order, optional($n->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Addresses'] = $this->writeSheet($spreadsheet, 'Addresses', [
            'ID', 'User ID', 'Neighborhood ID', 'Label', 'Address', 'Landmark', 'Lat', 'Lng', 'Default', 'Created At',
        ], $addresses->map(fn (CustomerAddress $a) => [
            $a->id, $a->user_id, $a->neighborhood_id, $a->label, $a->address_line, $a->landmark,
            $a->lat, $a->lng, $this->yn($a->is_default), optional($a->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Coupons'] = $this->writeSheet($spreadsheet, 'Coupons', [
            'ID', 'Code', 'Store ID', 'Title KU', 'Type', 'Value', 'Min Order', 'Max Discount',
            'Usage Limit', 'Used', 'Starts', 'Expires', 'Active', 'Created At',
        ], $coupons->map(fn (Coupon $c) => [
            $c->id, $c->code, $c->store_id, $c->title_ku, $c->discount_type, $c->discount_value,
            $c->min_order_amount, $c->max_discount_amount, $c->usage_limit, $c->used_count,
            optional($c->starts_at)?->toDateTimeString(), optional($c->expires_at)?->toDateTimeString(),
            $this->yn($c->is_active), optional($c->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Banners'] = $this->writeSheet($spreadsheet, 'Banners', [
            'ID', 'Title KU', 'Title AR', 'Title EN', 'Subtitle KU', 'Badge', 'Target Type',
            'Store ID', 'Category ID', 'Active', 'Sort', 'Created At',
        ], $banners->map(fn (Banner $b) => [
            $b->id, $b->title_ku, $b->title_ar, $b->title_en, $b->subtitle_ku, $b->badge_text,
            $b->target_type, $b->store_id, $b->category_id, $this->yn($b->is_active), $b->sort_order,
            optional($b->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Payouts'] = $this->writeSheet($spreadsheet, 'Payouts', [
            'ID', 'Reference', 'User ID', 'Store ID', 'Recipient Type', 'Direction', 'Amount',
            'Payment Method', 'Status', 'Notes', 'Processed By', 'Processed At', 'Created At',
        ], $payouts->map(fn (Payout $p) => [
            $p->id, $p->reference_code, $p->user_id, $p->store_id, $p->recipient_type, $p->direction,
            $p->amount, $p->payment_method, $p->status, $p->notes, $p->processed_by,
            optional($p->processed_at)?->toDateTimeString(), optional($p->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Tickets'] = $this->writeSheet($spreadsheet, 'Tickets', [
            'ID', 'Ticket Number', 'User ID', 'Order ID', 'Category', 'Priority', 'Subject',
            'Description', 'Admin Reply', 'Status', 'Resolved By', 'Resolved At', 'Created At',
        ], $tickets->map(fn (SupportTicket $t) => [
            $t->id, $t->ticket_number, $t->user_id, $t->order_id, $t->category, $t->priority,
            $t->subject, $t->description, $t->admin_reply, $t->status, $t->resolved_by,
            optional($t->resolved_at)?->toDateTimeString(), optional($t->created_at)?->toDateTimeString(),
        ])->all());

        $sheetCounts['Settings'] = $this->writeSheet($spreadsheet, 'Settings', [
            'ID', 'Key', 'Group', 'Value JSON', 'Description', 'Updated At',
        ], $settings->map(fn (PlatformSetting $s) => [
            $s->id, $s->key, $s->group,
            is_array($s->value) ? json_encode($s->value, JSON_UNESCAPED_UNICODE) : (string) $s->value,
            $s->description, optional($s->updated_at)?->toDateTimeString(),
        ])->all());

        $binary = $this->spreadsheetToBinary($spreadsheet);
        $spreadsheet->disconnectWorksheets();
        unset($spreadsheet);

        return [
            'binary' => $binary,
            'file_name' => $fileName,
            'sheet_counts' => $sheetCounts,
        ];
    }

    /**
     * Persist workbook under storage/app/backups/{type}/.
     *
     * @return array{path: string, file_name: string, relative_path: string, size: int, sheet_counts: array<string, int>}
     */
    public function storeBackup(string $type = self::TYPE_WEEKLY): array
    {
        $type = $this->normalizeType($type);
        $built = $this->buildWorkbook($type);
        $relative = "backups/{$type}/{$built['file_name']}";

        Storage::disk(self::DISK)->put($relative, $built['binary']);

        return [
            'path' => Storage::disk(self::DISK)->path($relative),
            'file_name' => $built['file_name'],
            'relative_path' => $relative,
            'size' => strlen($built['binary']),
            'sheet_counts' => $built['sheet_counts'],
        ];
    }

    /**
     * List recent backup files across weekly/monthly/manual folders.
     *
     * @return list<array{file: string, type: string, relative_path: string, size: int, modified_at: string}>
     */
    public function listBackups(int $limit = 50): array
    {
        $items = [];
        foreach ([self::TYPE_WEEKLY, self::TYPE_MONTHLY, self::TYPE_MANUAL] as $type) {
            $dir = "backups/{$type}";
            if (! Storage::disk(self::DISK)->exists($dir)) {
                continue;
            }
            foreach (Storage::disk(self::DISK)->files($dir) as $path) {
                if (! str_ends_with(strtolower($path), '.xlsx')) {
                    continue;
                }
                $items[] = [
                    'file' => basename($path),
                    'type' => $type,
                    'relative_path' => $path,
                    'size' => (int) Storage::disk(self::DISK)->size($path),
                    'modified_at' => date('c', Storage::disk(self::DISK)->lastModified($path)),
                ];
            }
        }

        usort($items, fn ($a, $b) => strcmp($b['modified_at'], $a['modified_at']));

        return array_slice($items, 0, max(1, $limit));
    }

    public function resolveSafePath(string $file): ?string
    {
        $file = basename($file);
        if ($file === '' || $file === '.' || $file === '..') {
            return null;
        }
        if (! preg_match('/^REGA_Backup_[a-z]+_\d{8}_\d{6}\.xlsx$/i', $file)) {
            return null;
        }

        foreach ([self::TYPE_WEEKLY, self::TYPE_MONTHLY, self::TYPE_MANUAL] as $type) {
            $relative = "backups/{$type}/{$file}";
            if (Storage::disk(self::DISK)->exists($relative)) {
                return $relative;
            }
        }

        return null;
    }

    private function normalizeType(?string $type): string
    {
        $type = strtolower((string) $type);

        return in_array($type, [self::TYPE_MANUAL, self::TYPE_WEEKLY, self::TYPE_MONTHLY], true)
            ? $type
            : self::TYPE_MANUAL;
    }

    /**
     * @param  array<string, int|string>  $counts
     */
    private function writeSummarySheet(Spreadsheet $spreadsheet, array $counts): int
    {
        $sheet = $spreadsheet->createSheet();
        $sheet->setTitle('Summary');
        $rows = [
            ['REGA Full Excel Backup', now()->toDateTimeString()],
            ['Backup Type', (string) ($counts['type'] ?? 'manual')],
            ['Note', 'Generated from Laravel / PostgreSQL — passwords excluded'],
            [],
            ['Sheet', 'Rows'],
        ];
        foreach ($counts as $key => $value) {
            if ($key === 'type') {
                continue;
            }
            $rows[] = [$key, $value];
        }

        foreach ($rows as $r => $row) {
            foreach ($row as $c => $value) {
                $sheet->setCellValue([$c + 1, $r + 1], $value);
            }
        }

        return max(0, count($rows) - 5);
    }

    /**
     * @param  list<string>  $headers
     * @param  list<list<mixed>>  $rows
     */
    private function writeSheet(Spreadsheet $spreadsheet, string $title, array $headers, array $rows): int
    {
        $sheet = $spreadsheet->createSheet();
        $sheet->setTitle($title);

        foreach ($headers as $c => $header) {
            $sheet->setCellValue([$c + 1, 1], $header);
        }

        foreach ($rows as $r => $row) {
            foreach ($row as $c => $value) {
                if (is_bool($value)) {
                    $value = $this->yn($value);
                } elseif (is_array($value)) {
                    $value = json_encode($value, JSON_UNESCAPED_UNICODE);
                }
                $sheet->setCellValue([$c + 1, $r + 2], $value);
            }
        }

        return count($rows);
    }

    private function spreadsheetToBinary(Spreadsheet $spreadsheet): string
    {
        $writer = new Xlsx($spreadsheet);
        $temp = tempnam(sys_get_temp_dir(), 'rega_xlsx_');
        if ($temp === false) {
            throw new \RuntimeException('Unable to create temp file for Excel backup.');
        }
        try {
            $writer->save($temp);

            return (string) file_get_contents($temp);
        } finally {
            @unlink($temp);
        }
    }

    private function yn(mixed $value): string
    {
        return $value ? 'yes' : 'no';
    }
}
