<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'fcm_token')) {
            return;
        }

        $driver = Schema::getConnection()->getDriverName();
        if ($driver === 'pgsql') {
            DB::statement('ALTER TABLE users ALTER COLUMN fcm_token TYPE TEXT');
        } elseif ($driver === 'mysql') {
            DB::statement('ALTER TABLE users MODIFY fcm_token TEXT NULL');
        }
    }

    public function down(): void
    {
        // no-op: widening is safe to keep
    }
};
