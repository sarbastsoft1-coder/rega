void openExternalUrl(String url) {
  // Desktop/mobile: no-op fallback; admin panel is primarily Flutter web.
  throw UnsupportedError('Opening URLs is supported on Flutter web.');
}
