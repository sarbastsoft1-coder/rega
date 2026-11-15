<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_inbox_reads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('item_key', 80);
            $table->string('fingerprint', 120);
            $table->timestamp('read_at')->useCurrent();
            $table->timestamps();

            $table->unique(['admin_user_id', 'item_key']);
            $table->index(['admin_user_id', 'read_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_inbox_reads');
    }
};
