# StelliesLive

**StelliesLive** is an project aimed exploring using LLM's to code a app aimed at making it easy to discover and keep up with events in and around Stellenbosch. It consists of a Flutter-based mobile and web app, backed by Firebase for real-time updates, notifications, and storage.

---

## Findings
ChatGPT, Gemnini and Claude was used during developement. The free version of all these agents was used.

While the LLM's preformed quite well in the early stages, the larger the project grew, the more they struggled to keep the entire project in scope and started breaking things more than helping and expanding the scope.

The experiment as an whole was insitfull into the current state of LLMs (as of december 2025). While I would not continue to use LLMs as the backbone of my coding, seeing as it caused to much friction and time wasted trying to wrangle the LLM into the right direction. I was very helpfull wit UI/UX since as of writing this, I have had minimal experiance in UI/UX.

I got it to a stage where it was releasable (as a student project, not professionaly) and went through the procedures of deployinig the app on the playstore and hosting the website version.

I ultimately decided to terminate this hobby project seeing as I moved outside the cover of the free tier for Firebase, and I am not prepared to spend money on this experiment at this stage.
As off March 2026, the firebase account has been deactivated and therefore most features will not work until it has been reactivated. As a result, it has been made private on the playstore.

---
## Features

* Browse local events with filtering by category, date, and location.
* Real-time updates on event changes.
* Real-time Map overlay on Google Maps showcasing events
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
