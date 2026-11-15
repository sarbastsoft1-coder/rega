<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\ExcelBackupService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

class BackupController extends Controller
{
    public function __construct(private readonly ExcelBackupService $backup)
    {
    }

    /**
     * Manual full Excel export — streams .xlsx download (also stores a copy under backups/manual/).
     */
    public function export(Request $request): StreamedResponse|JsonResponse
    {
        $persist = filter_var($request->query('persist', '1'), FILTER_VALIDATE_BOOLEAN);

        if ($persist) {
            $stored = $this->backup->storeBackup(ExcelBackupService::TYPE_MANUAL);
            $relative = $stored['relative_path'];
            $fileName = $stored['file_name'];

            return Storage::disk(ExcelBackupService::DISK)->download($relative, $fileName, [
                'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ]);
        }

        $built = $this->backup->buildWorkbook(ExcelBackupService::TYPE_MANUAL);

        return response()->streamDownload(function () use ($built) {
            echo $built['binary'];
        }, $built['file_name'], [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }

    /**
     * List recent auto/manual backups on disk.
     */
    public function index(Request $request): JsonResponse
    {
        $limit = (int) $request->query('limit', 40);
        $items = $this->backup->listBackups(min(100, max(1, $limit)));

        return response()->json([
            'success' => true,
            'data' => $items,
            'meta' => [
                'schedule' => [
                    'weekly' => 'Sunday 02:00 — php artisan backup:excel --type=weekly',
                    'monthly' => '1st of month 03:00 — php artisan backup:excel --type=monthly',
                    'note' => 'Requires php artisan schedule:run (cron / Windows Task Scheduler) every minute.',
                ],
            ],
        ]);
    }

    /**
     * Download a previously stored backup file by basename.
     */
    public function download(string $file): StreamedResponse|JsonResponse
    {
        $relative = $this->backup->resolveSafePath($file);
        if ($relative === null) {
            return response()->json([
                'success' => false,
                'message' => 'Backup file not found.',
            ], 404);
        }

        return Storage::disk(ExcelBackupService::DISK)->download($relative, basename($relative), [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }
}
