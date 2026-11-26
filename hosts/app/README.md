# mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## WordPress Articles

This app integrates WordPress content from thestrongrope.com using the WP v2 API.

- Bottom navigation has two tabs: Home and Articles
- Articles list supports category chips, search, infinite scroll, and modern cards
- Tapping a bookmark icon saves the article for offline reading
- Article details render HTML content with a clean reading layout

### Caching & Offline

- Lists and categories are cached in Hive for one hour (lists) / 24 hours (categories)
- You can save specific articles for offline; they are stored in Hive and available without network
- WordPress requests use a dedicated client without auth headers

### Run

1. Ensure Flutter SDK is set up.
2. From the `mobile` directory, run the app on your target device.

