"""Comprehensive redeploy of REGA backend and all frontend web builds to Hostinger VPS."""
from __future__ import annotations

import os
import tarfile
import tempfile
import time
from pathlib import Path

import paramiko

HOST = "72.60.38.165"
USER = "root"
KEY_PATH = Path.home() / ".ssh" / "id_ed25519"
REMOTE_DIR = "/root/rega"
LOCAL_ROOT = Path(__file__).resolve().parent

UPLOAD_PATHS = [
    "rega/build/web",
    "rega_admin/build/web",
    "rega_froshyar/build/web",
    "rega_delivery/build/web",
    "rega/lib",
    "rega_admin/lib",
    "rega_froshyar/lib",
    "rega_delivery/lib",
    "rega_backend/app",
    "rega_backend/bootstrap/app.php",
    "rega_backend/database/migrations",
    "rega_backend/routes/api.php",
    "docker/Caddyfile",
]

PHP_COPIES = [
    "bootstrap/app.php",
    "routes/api.php",
    "app/Http/Middleware/EnforceIdempotency.php",
    "app/Http/Middleware/EnsureUserHasRole.php",
    "app/Http/Middleware/EnsureUserIsActive.php",
    "app/Http/Controllers/Api/DriverAppController.php",  # includes optional delivery PIN
    "app/Http/Controllers/Api/PublicAndCustomerController.php",
    "app/Http/Controllers/Api/VendorAppController.php",
    "app/Http/Controllers/Api/Admin/CatalogAndZonesController.php",
    "app/Http/Controllers/Api/Admin/StoreManagementController.php",
    "app/Http/Controllers/Api/Admin/OrderManagementController.php",
    "app/Http/Controllers/Api/Admin/MarketingController.php",
    "app/Http/Controllers/Api/Admin/FinanceAndSupportController.php",
    "app/Http/Controllers/Api/Admin/AdminInboxController.php",
    "app/Http/Controllers/Api/AuthController.php",
    "app/Models/User.php",
    "app/Models/Order.php",
    "app/Models/ServiceCity.php",
    "app/Models/Neighborhood.php",
    "app/Models/Store.php",
    "app/Models/AppNotification.php",
    "app/Services/FcmPushService.php",
    "app/Services/DriverDispatchService.php",
    "config/services.php",
]


def connect() -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    key = paramiko.Ed25519Key.from_private_key_file(str(KEY_PATH))
    client.connect(
        HOST,
        username=USER,
        pkey=key,
        timeout=45,
        allow_agent=False,
        look_for_keys=False,
    )
    return client


def run(client: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    print(f"$ {cmd}")
    _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", "replace")
    err = stderr.read().decode("utf-8", "replace")
    code = stdout.channel.recv_exit_status()
    if out.strip():
        print(out[-3000:])
    if err.strip():
        print(err[-1500:])
    if code != 0:
        raise RuntimeError(f"Command failed ({code}): {cmd}\n{err or out}")
    return out


def make_tarball() -> Path:
    present = [p for p in UPLOAD_PATHS if (LOCAL_ROOT / p).exists()]
    missing = [p for p in UPLOAD_PATHS if not (LOCAL_ROOT / p).exists()]
    if missing:
        print(f"Skipping missing paths: {missing}")

    fd, name = tempfile.mkstemp(prefix="rega_full_redeploy_", suffix=".tar.gz")
    os.close(fd)
    tar_path = Path(name)
    tar_path.unlink(missing_ok=True)
    with tarfile.open(tar_path, "w:gz") as tar:
        for rel in present:
            full = LOCAL_ROOT / rel
            print(f"  + {rel}")
            tar.add(full, arcname=rel)
    print(f"Tarball created: {tar_path} ({tar_path.stat().st_size / 1e6:.1f} MB)")
    return tar_path


def upload(client: paramiko.SSHClient, local: Path, remote: str) -> None:
    print(f"Uploading {local.name} -> {remote}")
    sftp = client.open_sftp()
    try:
        sftp.put(str(local), remote)
    finally:
        sftp.close()


def main() -> None:
    print("=== Starting REGA Deployment to Hostinger VPS ===")
    tar_path = make_tarball()
    remote_tar = "/tmp/rega_full_redeploy.tar.gz"

    client = connect()
    try:
        upload(client, tar_path, remote_tar)
        print("Extracting files on remote...")
        run(
            client,
            f"mkdir -p {REMOTE_DIR} && tar -xzf {remote_tar} -C {REMOTE_DIR} && rm -f {remote_tar}",
        )

        print("Copying updated PHP backend files into rega_backend container...")
        for rel in PHP_COPIES:
            local_check = LOCAL_ROOT / "rega_backend" / rel
            if not local_check.exists():
                continue
            parent = "/".join(rel.split("/")[:-1])
            if parent:
                run(
                    client,
                    f"docker exec rega_backend mkdir -p /var/www/html/{parent}",
                )
            run(
                client,
                f"docker cp {REMOTE_DIR}/rega_backend/{rel} rega_backend:/var/www/html/{rel}",
            )

        print("Restarting web and caddy containers to reload web builds and reverse proxy...")
        run(client, f"cd {REMOTE_DIR} && docker compose restart web caddy")
        time.sleep(4)

        print("Running database migrations and clearing Laravel cache...")
        run(client, "docker exec rega_backend php artisan migrate --force")
        run(client, "docker exec rega_backend php artisan optimize:clear || true")

        print("Verifying container endpoints...")
        run(
            client,
            "curl -sS -o /dev/null -w 'customer_8082:%{http_code}\\n' http://127.0.0.1:8082/ || true; "
            "curl -sS -o /dev/null -w 'admin_8080:%{http_code}\\n' http://127.0.0.1:8080/ || true; "
            "curl -sS -o /dev/null -w 'vendor_8081:%{http_code}\\n' http://127.0.0.1:8081/ || true; "
            "curl -sS -o /dev/null -w 'delivery_8083:%{http_code}\\n' http://127.0.0.1:8083/ || true; "
            "curl -sS 'http://127.0.0.1:8001/api/v1/public/bootstrap' | head -c 300 || true; echo; "
            "docker ps --format 'table {{.Names}}\\t{{.Status}}'",
        )

        print("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===")
        print("Customer: https://app.72.60.38.165.sslip.io/")
        print("Admin:    https://admin.72.60.38.165.sslip.io/")
        print("Vendor:   https://vendor.72.60.38.165.sslip.io/")
        print("Delivery: https://delivery.72.60.38.165.sslip.io/")
        print("API:      https://api.72.60.38.165.sslip.io/")
    finally:
        client.close()
        tar_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
