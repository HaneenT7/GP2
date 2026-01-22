# Firebase Setup Guide for GP2

This guide will help you connect your GP2 Flutter app to your existing Firebase database.

## Prerequisites

1. A Firebase project already created in the [Firebase Console](https://console.firebase.google.com/)
2. Flutter SDK installed
3. Node.js installed (for Firebase CLI) - Download from https://nodejs.org/
4. FlutterFire CLI installed (we'll install this in step 1)

## Step 1: Install FlutterFire CLI

Run the following command in your terminal:

```bash
dart pub global activate flutterfire_cli
```

## Step 2: Configure Firebase for Your Flutter App

**Note:** You may see lint errors in `lib/main.dart` about missing `firebase_options.dart`. This is normal and will be resolved after running `flutterfire configure`.

1. Make sure you're logged into Firebase:
   ```bash
   firebase login
   ```

2. Navigate to your project directory and run:
   ```bash
   flutterfire configure
   ```

   This command will:
   - Detect your Firebase projects
   - Let you select your existing Firebase project
   - Automatically generate `lib/firebase_options.dart` (this will fix the lint errors)
   - Download and configure `google-services.json` for Android
   - Download and configure `GoogleService-Info.plist` for iOS

## Step 3: Install Dependencies

After configuring Firebase, install the Flutter packages:

```bash
flutter pub get
```

## Step 4: Verify Configuration Files

Make sure these files exist:

### Android
- `android/app/google-services.json` (should be created automatically by `flutterfire configure`)

### iOS
- `ios/Runner/GoogleService-Info.plist` (should be created automatically by `flutterfire configure`)

### Flutter
- `lib/firebase_options.dart` (should be created automatically by `flutterfire configure`)

## Step 5: Test the Connection

The app is now configured to connect to your Firebase database. The Firebase initialization happens in `lib/main.dart`.

## Using Firebase Services

### Firestore (Cloud Firestore)
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Example: Read data
FirebaseFirestore.instance
    .collection('users')
    .get()
    .then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.forEach((doc) {
        print(doc.data());
      });
    });

// Example: Write data
FirebaseFirestore.instance
    .collection('users')
    .add({'name': 'John Doe', 'email': 'john@example.com'});
```

### Realtime Database
```dart
import 'package:firebase_database/firebase_database.dart';

final databaseRef = FirebaseDatabase.instance.ref();

// Example: Read data
databaseRef.child('users').once().then((DatabaseEvent snapshot) {
  print(snapshot.snapshot.value);
});

// Example: Write data
databaseRef.child('users').set({'name': 'John Doe'});
```

## Troubleshooting

### If `flutterfire configure` doesn't work:
1. Make sure you have the Firebase CLI installed: `npm install -g firebase-tools`
2. Make sure you're logged in: `firebase login`
3. Try running `flutterfire configure --project=YOUR_PROJECT_ID` with your specific project ID

### If you get build errors:
1. Make sure `google-services.json` is in `android/app/` directory
2. Make sure `GoogleService-Info.plist` is in `ios/Runner/` directory
3. Run `flutter clean` and then `flutter pub get`
4. For Android, make sure the `google-services` plugin is applied in `android/app/build.gradle.kts`

## Next Steps

After completing the setup:
1. Your app will automatically connect to Firebase when it starts
2. You can start using Firestore or Realtime Database in your app
3. Make sure to set up proper security rules in Firebase Console
