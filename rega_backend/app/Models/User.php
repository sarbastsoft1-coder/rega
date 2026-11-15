<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'phone',
        'email',
        'password',
        'role',
        'avatar_url',
        'language',
        'city',
        'is_active',
        'fcm_token',
        'last_login_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    public function isAdmin(): bool
    {
        return in_array($this->role, ['super_admin', 'admin', 'dispatcher'], true);
    }

    public function isVendor(): bool
    {
        return $this->role === 'vendor';
    }

    public function isDriver(): bool
    {
        return $this->role === 'driver';
    }

    public function isCustomer(): bool
    {
        return $this->role === 'customer';
    }

    public function ownedStore(): HasOne
    {
        // Deterministic when a plain HasOne is eager-loaded / first()'d.
        // Prefer resolveOwnedStore() for vendor catalog so multi-store owners
        // keep reading/writing the same store (avoids "data disappeared" on reload).
        return $this->hasOne(Store::class, 'owner_id')->latestOfMany();
    }

    /**
     * Pick one store for a vendor who may own several (admin test duplicates, etc.).
     * Prefer the store with the richest catalog so added products/categories
     * still appear after logout / app restart instead of an empty sibling store.
     */
    public function resolveOwnedStore(): ?Store
    {
        return $this->stores()
            ->with(['category', 'neighborhood'])
            ->withCount(['products', 'storeCategories'])
            ->orderByDesc('products_count')
            ->orderByDesc('store_categories_count')
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->first();
    }

    public function stores(): HasMany
    {
        return $this->hasMany(Store::class, 'owner_id');
    }

    public function driverProfile(): HasOne
    {
        return $this->hasOne(DriverProfile::class);
    }

    public function addresses(): HasMany
    {
        return $this->hasMany(CustomerAddress::class);
    }

    public function favoriteStores(): BelongsToMany
    {
        return $this->belongsToMany(Store::class, 'favorite_stores')->withTimestamps();
    }

    public function customerOrders(): HasMany
    {
        return $this->hasMany(Order::class, 'customer_id');
    }

    public function driverOrders(): HasMany
    {
        return $this->hasMany(Order::class, 'driver_id');
    }

    public function payouts(): HasMany
    {
        return $this->hasMany(Payout::class);
    }

    public function supportTickets(): HasMany
    {
        return $this->hasMany(SupportTicket::class);
    }
}
