# WATAD 🎓

WATAD is a Flutter study-companion app that helps students organize course
materials, build a personalized revision plan, quiz themselves with
AI-generated questions, and take short brain-training breaks — all backed by
Firebase.

## ✨ Features

- **Authentication** – email/password sign up, sign in, and password reset via Firebase Auth
- **Course Folders** – upload, organize, and view PDF course materials (Syncfusion PDF viewer)
- **Revision Plan** – set up a study schedule and get an auto-generated revision plan with exam-day tracking and overdue task handling
- **AI Quizzes** – generate multiple-choice quizzes from course PDFs using the Gemini API
- **Snaps Board** – save and revisit quick notes/snapshots, stored in Firestore and Firebase Storage
- **Health Connect** – track heart rate and receive alerts during study sessions
- **Notifications** – local and background notifications to keep you on track
- **Brain Games** – Sudoku, Memory, Word Search, and Math Lab mini-games for study breaks

## 🛠 Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Auth, Firestore, Realtime Database, Storage, Cloud Functions, Messaging)
- **AI:** Google Gemini API (quiz generation)
- **PDF:** Syncfusion Flutter PDF / PDF Viewer
- **Other:** `flutter_local_notifications`, `health`, `image_picker`, `file_picker`, `google_fonts`

## 📁 Project Structure

```
lib/
├── config/         # App-level configuration
├── models/         # Data models (course folders, files, etc.)
├── pages/          # App screens (dashboard, revision plan, games, auth, etc.)
├── services/       # Firebase, Gemini, notifications, health, and other services
├── theme/          # Shared styling
├── utils/          # Helpers (error dialogs, overdue logic, etc.)
└── widgets/        # Reusable UI components
functions/          # Firebase Cloud Functions
```

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.1.0)
- A Firebase project (see [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) for full setup instructions)
- A [Gemini API key](https://ai.google.dev/) for quiz generation

### Installation

1. **Clone the repo**
   ```bash
   git clone https://github.com/HaneenT7/GP2.git
   cd GP2
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   Follow the step-by-step guide in [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) to run
   `flutterfire configure` and generate `lib/firebase_options.dart`,
   `google-services.json`, and `GoogleService-Info.plist`.

4. **Add environment variables**

   Create a `.env` file in the project root:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## 🔥 Firebase Security Rules

Firestore and Storage rules must be published for features like the Snaps
Board to work — see [`SNAPS_PERSISTENCE_README.md`](SNAPS_PERSISTENCE_README.md)
for the exact rules and troubleshooting steps ("permission-denied" errors).

## 🧪 Testing

```bash
flutter test
```

## 👥 Contributors

- Noura Alyemni
- Lama Alhunayhin
- Sarah Alotaibi
- Hanin Alturki 
- Jana Alromeh


