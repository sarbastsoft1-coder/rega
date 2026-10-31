@echo off
cd /d "%~dp0"
echo Starting REGA Laravel + PostgreSQL Backend on http://127.0.0.1:8001 ...
php artisan serve --host=0.0.0.0 --port=8001
pause

