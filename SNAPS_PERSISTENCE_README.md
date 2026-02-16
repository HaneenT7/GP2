# Snaps Board – Save to Database

Snaps are stored in **Firebase Firestore** and images in **Firebase Storage**. To have snaps **saved to the database and fetched when the app is reopened**, you need:

1. **Be signed in** – Only signed-in users can save and load snaps.
2. **Publish Firestore (and Storage) rules** – Otherwise you get "permission-denied" and nothing is saved or loaded.

## Quick fix for "permission-denied"

1. Open [Firebase Console](https://console.firebase.google.com) → your project.
2. Go to **Firestore Database** → **Rules**.
3. Paste the Firestore rules below, then click **Publish** (top right). Without clicking Publish, rules do not apply.
4. Optionally: **Storage** → **Rules** → paste the Storage rules below → **Publish**.
5. Reopen the app and try adding a snap again; it should save and load after restart.

## Firebase rules

### Firestore (Database)

In [Firebase Console](https://console.firebase.google.com) → your project → **Firestore Database** → **Rules**, use:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/boards/{boardId}/snaps/{snapId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/boards/{boardId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Storage (Images)

In **Storage** → **Rules**, use:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /snaps/{boardName}/{fileName} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Important:** After editing the rules, click **Publish** (top right in the Rules tab). If you see "Error saving snap: permission-denied", the rules are not published yet.

Then sign in in the app and add a snap. After closing and reopening the app, your snaps should load from the database.
