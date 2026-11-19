# ڕێبەری تەواوی دانانی سیستەمی ڕێگا لەسەر سێرڤەری تایبەت (VPS Deployment Guide)

ئەم ڕێبەرە هەنگاو بە هەنگاو ڕوونی دەکاتەوە چۆن تەواوی ٥ بەشەکەی سیستەمی **REGA (ڕێگا)** لەسەر هەر سێرڤەرێکی Linux VPS (وەک Ubuntu 20.04 / 22.04 / 24.04 یان Debian) بە ئاسانترین شێوە و بە یەک فەرمان دابمەزرێنیت.

---

## تەلارسازیی پۆرتەکان لەسەر VPS

| بەش / ئەپڵیکەیشن | پۆرت (Port) | بەستەری ناخۆیی / گشتی | ڕۆڵ لە سیستەم |
|---|---|---|---|
| **باکئێند (Laravel 12 API)** | `8001` | `http://YOUR_VPS_IP:8001/api/health` | بزوێنەری سەرەکی API، داتابەیسی PostgreSQL و تەلەمەتری |
| **پانێڵی ئادمین (REGA Admin)** | `8080` | `http://YOUR_VPS_IP:8080` | کۆنتڕۆڵی تەواوی فرۆشیار، کڕیار، شۆفێر، ڕاداری ڕاستەوخۆ و دارایی |
| **ئەپی فرۆشیار (REGA Froshyar)** | `8081` | `http://YOUR_VPS_IP:8081/?bypass=true` | وەرگرتنی داواکاری لە چێشتخانە، پین کۆد و بەڕێوەبردنی مێنیو |
| **ئەپی کڕیار (REGA Customer)** | `8082` | `http://YOUR_VPS_IP:8082/?bypass=true` | بینینی دوکانەکان، داواکردنی خواردن و بەدواداچوونی نەخشە |
| **ئەپی دلیڤەری (REGA Delivery)** | `8083` | `http://YOUR_VPS_IP:8083/?bypass=true` | وەرگرتنی داواکاری، نەخشەی GPS لە کەلار، پینی تەسلیمکردن |
| **دەروازەی گشتی (Nginx Gateway)** | `80` | `http://YOUR_VPS_IP/` | پڕۆکسی گشتی و بەستنەوەی هەموو ئەپەکان بەبێ نووسینی پۆرت |

---

## شێوازی یەکەم: دامەزراندنی خۆکار بە یەک کلیک (خێراترین و پێشنیارکراو)

لە ڕێگەی تێرمیناڵەوە بچۆ ناو VPSـەکەت:

```bash
ssh root@YOUR_VPS_IP
```

ئینجا ئەم فەرمانانە لێبدە بۆ داگرتنی پڕۆژەکە لە GitHub و جێبەجێکردنی سکریپتی ئۆتۆماتیک:

```bash
# 1. کۆپیکردنی پرۆژەکە لە گیت
git clone https://github.com/sarbastsoft1-coder/rega.git
cd rega

# 2. پێدانی مۆڵەتی جێبەجێکردن بە سکریپتەکە
chmod +x deploy_vps.sh

# 3. دەستپێکردنی سکریپت
./deploy_vps.sh
```

سکریپتەکە لێت دەپرسێت چ شێوازێکت پێ باشە:
1. **Docker Compose** (پێشنیارکراو بۆ سێرڤەری مۆدێرن بەبێ کێشەی پاکێج)
2. **Native Host** (دامەزراندنی ڕاستەوخۆی PHP 8.2 و PostgreSQL و بەگەڕخستنی سێرڤیسی Systemd)

تەنها ژمارە **1** یان **2** بنووسە و Enter داگرە؛ سکریپتەکە هەموو شتێک جێبەجێ دەکات لە فایەروۆڵ، داتابەیس، میگرەیشن و خزمەتگوزارییەکان.

---

## شێوازی دووەم: بەکارهێنانی Docker Compose بە دەستی

ئەگەر دەتەوێت خۆت لە ڕێگەی Dockerـەوە ڕاستەوخۆ دەستی پێبکەیت:

```bash
cd rega

# دڵنیابە لە هەبوونی دۆکەر
docker compose up -d --build
```

پشکنینی کۆنتێنەرە کاراکان:
```bash
docker compose ps
```

بینینی لۆگەکان:
```bash
docker compose logs -f
```

---

## شێوازی سێیەم: بەگەڕخستن لە ڕێگەی Python + Systemd

ئەگەر دەتەوێت سکریپتی `serve_all.py` وەک سێرڤیسی باکگراوند (Service) لە Linux لە کاتی داگیرسانی سێرڤەر خۆی ئۆتۆماتیک دەستپێبکات:

```bash
# 1. کۆپیکردنی فایلی سێرڤیس بۆ سیستەم
sudo cp /var/www/rega/deploy_vps.sh /dev/null # (یان دروستکردنی فایلی rega.service)

# 2. چالاککردنی لە کاتی بووتدا
sudo systemctl enable rega.service
sudo systemctl start rega.service

# 3. بینینی دۆخی کارکردن
sudo systemctl status rega.service
```

---

## ڕێکخستنی فایەروۆڵ (Firewall - UFW)

دڵنیابەرەوە ئەم پۆرتانە لە VPS کراوەن بۆ ئەوەی خەڵک بتوانن بچنە ناو ئەپەکان:

```bash
sudo ufw allow 22/tcp     # بۆ SSH
sudo ufw allow 80/tcp     # بۆ وێب
sudo ufw allow 443/tcp    # بۆ SSL / HTTPS
sudo ufw allow 8001/tcp   # بۆ API Backend
sudo ufw allow 8080/tcp   # بۆ Admin
sudo ufw allow 8081/tcp   # بۆ Vendor
sudo ufw allow 8082/tcp   # بۆ Customer
sudo ufw allow 8083/tcp   # بۆ Delivery Captain
sudo ufw enable
```

---

## بەستنەوەی دۆمەین و کاراکردنی SSL (HTTPS)

ئەگەر دۆمەینت هەیە (وەک `rega.iq`)، فایلی ئامادەکراوی `docker/nginx/nginx_domain.conf` بەکاربهێنە:

```bash
sudo cp docker/nginx/nginx_domain.conf /etc/nginx/sites-available/rega.conf
sudo ln -s /etc/nginx/sites-available/rega.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

ئینجا بۆ بەدەستهێنانی بڕوانامەی ئەمنیی خۆڕایی SSL:
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d rega.iq -d api.rega.iq -d admin.rega.iq -d vendor.rega.iq -d captain.rega.iq
```

---

## SMS / OTP (نوێکردنەوەی وشەی نهێنی کڕیار)

کۆدی پشتڕاستکردنەوە بە `RegaSmsDispatcher` دەنێردرێت — **هیچ Twilio یان دەروازەی عێراقی لەناو کۆدەکەدا نییە**؛ تەنها POSTی JSON بۆ webhookێکی دەرەکی:

```json
{ "phone": "07703331122", "message": "...", "type": "password_reset_otp" }
```

1. لە `/var/www/rega` فایلی `.env` دروست بکە (یان زیادی بکە):

```bash
REGA_SMS_WEBHOOK_URL=https://YOUR-SMS-BRIDGE/send
# REGA_SMS_OTP_TEMPLATE="کۆدی نوێکردنەوەی هەژمار REGA: {otp}"
```

2. دووبارە بیلدکردنی backend:

```bash
cd /var/www/rega
docker compose up -d --build backend
```

3. پشکنین — لە لۆگدا `rega.sms.sent` دەبینیت؛ بەبێ webhook تەنها `rega.sms.skipped` لە `storage/logs/laravel.log`.

**ئاگاداری:** `APP_DEBUG=false` لە prod بەجێبهێڵە — `debug_otp` تەنها کاتێک لە API دەگەڕێتەوە کە `APP_DEBUG=true` بێت.

---

## زانیاریی چوونەژوورەوەی بنەڕەتی (Seeded Credentials)

هەموو ئەژمارەکان بە وشەی نهێنی: **`password123`** ئامادە کراون:
- **سووپەر ئادمین**: `07700000001` (یان `admin@rega.iq`)
- **فرۆشیار (چێشتخانەی مام ڕەشید)**: `07701112233`
- **ماتۆرسوار (ڕەوەند کەریم - RA-884)**: `07501234567`
- **کڕیار (ئاراس ڕەحمان)**: `07703331122`

