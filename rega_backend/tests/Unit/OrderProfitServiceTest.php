<?php

namespace Tests\Unit;

use App\Services\OrderProfitService;
use PHPUnit\Framework\TestCase;

class OrderProfitServiceTest extends TestCase
{
    public function test_case_1_twenty_percent_on_gross_profit(): void
    {
        $svc = new OrderProfitService;
        $r = $svc->calculateShares(5000, 7000, 20);

        $this->assertSame(2000, $r['gross_profit']);
        $this->assertSame(400, $r['admin_share']);
        $this->assertSame(1600, $r['seller_share']);
    }

    public function test_case_2_ten_percent_on_gross_profit(): void
    {
        $svc = new OrderProfitService;
        $r = $svc->calculateShares(10000, 15000, 10);

        $this->assertSame(5000, $r['gross_profit']);
        $this->assertSame(500, $r['admin_share']);
        $this->assertSame(4500, $r['seller_share']);
    }

    public function test_quantity_multiplies_shares(): void
    {
        $svc = new OrderProfitService;
        $r = $svc->calculateShares(5000, 7000, 20, 2);

        $this->assertSame(4000, $r['gross_profit']);
        $this->assertSame(800, $r['admin_share']);
        $this->assertSame(3200, $r['seller_share']);
    }

    public function test_commission_clamped_and_cost_capped(): void
    {
        $svc = new OrderProfitService;
        $r = $svc->calculateShares(9000, 7000, 150);

        $this->assertSame(0, $r['gross_profit']);
        $this->assertSame(0, $r['admin_share']);
        $this->assertSame(0, $r['seller_share']);
    }
}
