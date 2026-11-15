#!/usr/bin/env bash
set -e

echo "=== Building REGA Flutter Web Applications ==="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "1/4 Building REGA Admin Web..."
cd "$ROOT_DIR/rega_admin"
flutter build web --release

echo "2/4 Building REGA Froshyar (Vendor) Web..."
cd "$ROOT_DIR/rega_froshyar"
flutter build web --release

echo "3/4 Building REGA Customer Marketplace Web..."
cd "$ROOT_DIR/rega"
flutter build web --release

echo "4/4 Building REGA Delivery Captain Web..."
cd "$ROOT_DIR/rega_delivery"
flutter build web --release

echo "=== All 4 REGA Web Apps Built Successfully! ==="
