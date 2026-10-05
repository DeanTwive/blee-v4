# blee

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running the Web App

### Recommended (Fastest & avoids Chrome debug WebSocket issues)
```bash
flutter run -d web-server --web-port 3000 --web-hostname 127.0.0.1
```
Then open `http://localhost:3000` in your browser.

### Direct Chrome Launch
```bash
flutter run -d chrome --web-port 3000 --web-hostname 127.0.0.1
```

flutter build apk --release