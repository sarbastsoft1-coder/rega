<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

/*
|--------------------------------------------------------------------------
| REGA Excel backups (weekly + monthly)
|--------------------------------------------------------------------------
| Local/Windows: register a Task Scheduler job that runs every minute:
|   php artisan schedule:run
| Or run manually:
|   php artisan backup:excel --type=weekly
|   php artisan backup:excel --type=monthly
*/
Schedule::command('backup:excel --type=weekly --keep=12')
    ->weeklyOn(0, '02:00')
    ->withoutOverlapping()
    ->name('rega-excel-backup-weekly');

Schedule::command('backup:excel --type=monthly --keep=24')
    ->monthlyOn(1, '03:00')
    ->withoutOverlapping()
    ->name('rega-excel-backup-monthly');
