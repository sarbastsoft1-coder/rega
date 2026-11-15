#!/bin/bash
set -e

echo "=== REGA Backend Initializing ==="

# Wait for PostgreSQL to be ready
if [ -n "$DB_HOST" ]; then
  echo "Waiting for PostgreSQL at $DB_HOST:${DB_PORT:-5432}..."
  while ! nc -z "$DB_HOST" "${DB_PORT:-5432}"; do
    sleep 1
  done
  echo "PostgreSQL is reachable!"
fi

# Ensure .env exists
if [ ! -f .env ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
fi

# Override DB config from environment if provided
if [ -n "$DB_HOST" ]; then
  sed -i "s/DB_HOST=.*/DB_HOST=$DB_HOST/" .env
fi
if [ -n "$DB_PORT" ]; then
  sed -i "s/DB_PORT=.*/DB_PORT=$DB_PORT/" .env
fi
if [ -n "$DB_DATABASE" ]; then
  sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_DATABASE/" .env
fi
if [ -n "$DB_USERNAME" ]; then
  sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USERNAME/" .env
fi
if [ -n "$DB_PASSWORD" ]; then
  sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
fi

# Generate APP_KEY if empty
if ! grep -q "APP_KEY=base64" .env; then
  echo "Generating application key..."
  php artisan key:generate --force
fi

# Run database migrations
echo "Running migrations..."
php artisan migrate --force

# Seed database if users table is empty
echo "Checking if database is seeded..."
USER_COUNT=$(php artisan tinker --execute="echo App\Models\User::count();" 2>/dev/null || echo "0")
if [ "$USER_COUNT" = "0" ] || [ -z "$USER_COUNT" ]; then
  echo "Seeding database with default users, stores, orders, products..."
  php artisan db:seed --force
else
  echo "Database already contains $USER_COUNT users. Skipping seeder."
fi

# Link storage
php artisan storage:link || true

# Optimize cache
php artisan config:clear
php artisan route:clear

echo "=== REGA Backend Ready on Port 8001 ==="
exec "$@"

