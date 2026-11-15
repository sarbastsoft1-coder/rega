<?php

namespace App\Console\Commands;

use App\Services\ExcelBackupService;
use Illuminate\Console\Command;

class CreateExcelBackupCommand extends Command
{
    protected $signature = 'backup:excel
                            {--type=weekly : Backup type: weekly, monthly, or manual}
                            {--keep=12 : How many newest files to keep per type folder}';

    protected $description = 'Create a multi-sheet REGA Excel (.xlsx) backup under storage/app/backups/{type}/';

    public function handle(ExcelBackupService $backup): int
    {
        $type = strtolower((string) $this->option('type'));
        if (! in_array($type, [
            ExcelBackupService::TYPE_WEEKLY,
            ExcelBackupService::TYPE_MONTHLY,
            ExcelBackupService::TYPE_MANUAL,
        ], true)) {
            $this->error('Invalid --type. Use weekly, monthly, or manual.');

            return self::FAILURE;
        }

        $this->info("Creating {$type} Excel backup...");

        $result = $backup->storeBackup($type);

        $this->info("Saved: {$result['relative_path']} ({$result['size']} bytes)");
        $this->table(
            ['Sheet', 'Rows'],
            collect($result['sheet_counts'])->map(fn ($count, $sheet) => [$sheet, $count])->values()->all()
        );

        $this->pruneOld($type, (int) $this->option('keep'));

        return self::SUCCESS;
    }

    private function pruneOld(string $type, int $keep): void
    {
        $keep = max(1, $keep);
        $disk = \Illuminate\Support\Facades\Storage::disk(ExcelBackupService::DISK);
        $dir = "backups/{$type}";
        if (! $disk->exists($dir)) {
            return;
        }

        $files = collect($disk->files($dir))
            ->filter(fn ($path) => str_ends_with(strtolower($path), '.xlsx'))
            ->sortByDesc(fn ($path) => $disk->lastModified($path))
            ->values();

        foreach ($files->slice($keep) as $old) {
            $disk->delete($old);
            $this->line("Pruned old backup: {$old}");
        }
    }
}
