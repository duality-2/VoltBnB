# Firebase Integration - Quick Reference

## ✅ What's Been Done

### 1. Firebase Setup Complete

- ✅ Generated `firebase_options.dart` with platform configs
- ✅ Firebase initialized in `main.dart`
- ✅ Web build successfully compiled with Firebase

### 2. Architecture Improvements

- ✅ Created centralized `firebase_service_provider.dart` for all Firebase instances
- ✅ All services use dependency injection through Riverpod
- ✅ Clean separation of concerns between UI and Firebase logic

### 3. State Management Providers Created

**Auth & User:**

- `authServiceProvider` - Firebase Auth operations
- `authStateProvider` - Stream of authenticated user
- `userProvider` - Current authenticated user
- `userServiceProvider` - Firestore user operations
- `currentUserDataProvider` - User profile data
- `userStreamProvider` - Real-time user profile updates

**Charger:**

- `chargerServiceProvider` - Firestore charger operations
- `hostChargersProvider` - User's own chargers
- `availableChargersProvider` - All available chargers

**Firebase Core:**

- `firebaseAuthProvider` - Direct Firebase Auth instance
- `firebaseFirestoreProvider` - Direct Firestore instance
- `firebaseStorageProvider` - Direct Firebase Storage instance

## 🚀 Using Firebase in Your Screens

### Example: Authenticate User

```dart
final authService = ref.watch(authServiceProvider);
await authService.signUpWithEmail('email@example.com', 'password');
```

### Example: Load User Chargers

```dart
// In a ConsumerWidget build method:
final chargers = ref.watch(hostChargersProvider);

chargers.when(
  data: (chargerList) => ListView(children: chargerList.map(...).toList()),
  loading: () => LoadingWidget(),
  error: (err, stack) => ErrorWidget(err),
);
```

### Example: Real-time User Data

```dart
final userData = ref.watch(userStreamProvider);

userData.when(
  data: (user) => Text('Hello, ${user?.name}'),
  loading: () => CircularProgressIndicator(),
  error: (err, _) => Text('Error loading user'),
);
```

### Example: Firestore Operations

```dart
final userService = ref.watch(userServiceProvider);
final currentUser = ref.watch(userProvider);

if (currentUser != null) {
  await userService.updateUser(currentUser.uid, {'name': 'New Name'});
}
```

## 📊 Firestore Collections

### Users Collection

```
users/{uid}
├── email: string
├── name: string
├── phone: string
├── role: 'renter' | 'host'
├── profileImage: string (URL)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Chargers Collection

```
chargers/{chargerId}
├── id: string
├── hostUid: string
├── name: string
├── location: string
├── latitude: number
├── longitude: number
├── images: string[] (URLs)
├── pricePerHour: number
├── isAvailable: boolean
├── availability: {
│   ├── startTime: string
│   ├── endTime: string
│   └── daysAvailable: string[]
├── createdAt: timestamp
└── updatedAt: timestamp
```

### Bookings Collection

```
bookings/{bookingId}
├── id: string
├── chargerId: string
├── renterId: string
├── hostId: string
├── startTime: timestamp
├── endTime: timestamp
├── totalPrice: number
├── status: 'pending' | 'confirmed' | 'completed' | 'cancelled'
├── createdAt: timestamp
└── updatedAt: timestamp
```

## 🔐 Security Rules (To Be Set in Firebase Console)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users - only own profile
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if request.auth.uid == uid;
    }

    // Chargers - anyone can read, only host can write
    match /chargers/{chargerId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.hostUid;
    }

    // Bookings - only renter/host can read/write
    match /bookings/{bookingId} {
      allow read: if request.auth.uid in
                     [resource.data.renterId, resource.data.hostId];
      allow create: if request.auth.uid == request.resource.data.renterId;
      allow update, delete: if request.auth.uid in
                               [resource.data.renterId, resource.data.hostId];
    }
  }
}
```

## 📝 Files Modified/Created

**Created:**

- `lib/firebase_options.dart` - Auto-generated Firebase config
- `lib/core/providers/firebase_service_provider.dart` - Centralized providers
- `lib/features/auth/providers/user_provider.dart` - User data management
- `FIREBASE_INTEGRATION.md` - Full documentation

**Modified:**

- `lib/main.dart` - Now uses firebase_options
- `lib/features/auth/providers/auth_provider.dart` - Uses firebase_service_provider
- `lib/features/charger/providers/charger_provider.dart` - Uses firebase_service_provider

## 🔗 Important Files

| File                                                   | Purpose                                            |
| ------------------------------------------------------ | -------------------------------------------------- |
| `lib/main.dart`                                        | Firebase initialization                            |
| `lib/firebase_options.dart`                            | Platform-specific Firebase config (Auto-generated) |
| `lib/core/providers/firebase_service_provider.dart`    | Central Firebase service providers                 |
| `lib/features/auth/services/auth_service.dart`         | Firebase Auth wrapper                              |
| `lib/features/auth/services/user_service.dart`         | Firestore user operations                          |
| `lib/features/charger/services/charger_service.dart`   | Firestore charger operations                       |
| `lib/features/auth/providers/auth_provider.dart`       | Auth state management                              |
| `lib/features/auth/providers/user_provider.dart`       | User data management                               |
| `lib/features/charger/providers/charger_provider.dart` | Charger state management                           |

## 📚 Next Steps

1. **Google Sign-In Setup** (Optional but recommended)
   - Configure OAuth 2.0 in Firebase Console
   - Download google-services.json (Android) and GoogleService-Info.plist (iOS)
   - Uncomment Google Sign-In code in `auth_service.dart`

2. **Set Firestore Security Rules**
   - Copy the rules above into Firebase Console
   - Test with Firebase Emulator Suite

3. **Add More Features**
   - Image uploads to Firebase Storage
   - Push notifications with Cloud Messaging
   - Automatic cleanup jobs with Cloud Functions

4. **Testing**
   - Use Firebase Emulator Suite for local development
   - Add unit tests for services
   - Add widget tests for screens

## ⚠️ Important Notes

- `firebase_options.dart` is auto-generated. Don't edit manually.
- To regenerate after Firebase changes: `flutterfire configure`
- Never commit Firebase keys/credentials to Git
- Keep `.gitignore` updated to exclude sensitive files

## 🐛 Troubleshooting

**Firebase not initializing?**

- Check internet connection
- Verify `firebase_options.dart` exists
- Check Flutter analyzer for import errors

**Can't access Firestore data?**

- Verify security rules are set correctly
- Check user is authenticated
- Enable Firestore in Firebase Console

**Build fails with Firebase errors?**

- Run `flutter pub get`
- Run `flutter clean`
- Re-run `flutterfire configure`

---

**Last Updated:** April 17, 2026
**Status:** ✅ Ready for Development
