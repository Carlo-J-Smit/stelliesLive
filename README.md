# StelliesLive

**StelliesLive** is an open-source project aimed at making it easy to discover and keep up with events in and around Stellenbosch. It consists of a Flutter-based mobile and web app, backed by Firebase for real-time updates, notifications, and storage.

This project is open for contributions as long as it remains non-commercial. I make no claims that this is perfect code — it's a work in progress, and any improvements or insights are welcome.

---

## Features

* Browse local events with filtering by category, date, and location.
* Real-time updates on event changes.
* Individual event pages with images, descriptions, and status.
* Minimal offline support for cached events.
* Push notifications, with subscription toggles for different event types.
* Cross-platform (Android, iOS, Web).
* Admin tools for creating and updating events in Firebase.

---

## Installation & Setup

Assumes you know Flutter and Firebase basics.

1. Clone the repo:

```bash
git clone https://github.com/yourusername/StelliesLive.git
cd StelliesLive
```

2. Get dependencies:

```bash
flutter pub get
```

3. Configure Firebase for Android, iOS, and Web. Add your `google-services.json` and `GoogleService-Info.plist` as needed, and update Web config in `index.html`.

4. Run:

```bash
flutter run
```

---

## Usage Notes

* Event subscriptions and toggle states are stored locally to reflect FCM subscriptions.
* Admin functionality is minimal and directly tied to Firebase permissions.
* This project is a work in progress — expect quirks, and feel free to fix things.

---

## Architecture

* **Frontend:** Flutter (mobile & web)
* **Backend:** Firebase (Firestore, Storage, Cloud Messaging)
* **Notifications:** FCM
* **State Management:** Provider / ChangeNotifier
* **Image Storage:** Firebase Storage

---

## Contributing

* Fork, branch, and PR as usual.
* Keep in mind non-commercial usage.
* No need to be formal — if you see a way to make things cleaner, do it.

---

## License

**Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**

* Use, share, adapt **non-commercially**.
* Credit must be given.
* [License link](https://creativecommons.org/licenses/by-nc/4.0/)

```
Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
Copyright (c) 2026 Carlo Smit

You are free to:
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material

Under the following terms:
- Attribution — Give appropriate credit, provide a link to the license, and indicate changes.
- NonCommercial — No commercial use.
```

---

## Contact

Carlo Smit – [Email] – [GitHub/LinkedIn]
Repo: [https://github.com/yourusername/StelliesLive](https://github.com/yourusername/StelliesLive)

