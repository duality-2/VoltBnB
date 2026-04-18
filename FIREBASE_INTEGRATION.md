# Firebase Integration Guide for VoltBnB

## Overview

VoltBnB is a Flutter application that uses Firebase for authentication, real-time database (Firestore), and cloud storage. The Firebase integration has been set up with support for Web, Android, iOS, and Windows platforms.

## Architecture

### Firebase Services Configured

- **Firebase Authentication** - User registration, login, password reset, phone OTP, and Google Sign-In
- **Cloud Firestore** - Real-time database for users, chargers, and bookings
- **Firebase Storage** - Cloud storage for charger images and user profile pictures
- **Firebase Core** - Core Firebase initialization

### Project Structure

```
lib/
├── main.dart                          # Firebase initialization
├── core/
│   ├── providers/
│   │   └── firebase_service_provider.dart    # Centralized Firebase providers
│   ├── router/
│   │   └── app_router.dart           # Navigation with auth state
│   └── theme/
│       └── app_theme.dart            # App theming
├── features/
│   ├── auth/
│   │   ├── models/
│   │   │   └── user_model.dart       # User data model
│   │   ├── services/
│   │   │   ├── auth_service.dart     # Firebase Auth wrapper
│   │   │   └── user_service.dart     # Firestore user operations
│   │   ├── providers/
│   │   │   ├── auth_provider.dart    # Auth state management
│   │   │   └── user_provider.dart    # User data management
│   │   └── screens/
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       ├── signup_screen.dart
│   │       └── ...
│   ├── charger/
│   │   ├── models/
│   │   │   └── charger_model.dart
│   │   ├── services/
│   │   │   └── charger_service.dart  # Firestore charger operations
│   │   ├── providers/
│   │   │   └── charger_provider.dart # Charger state management
│   │   └── screens/
│   │       ├── home_screen.dart
│   │       ├── add_charger_screen.dart
│   │       └── ...
│   ├── booking/
│   │   ├── models/
│   │   │   └── booking_model.dart
│   │   └── screens/
│   │       └── ...
│   └── profile/
│       └── screens/
│           └── profile_screen.dart
└── firebase_options.dart             # Auto-generated Firebase configuration
```

## Key Features

### 1. Authentication

The `AuthService` class handles all Firebase Authentication operations:

- Email/password registration and login
- Password reset
- Phone number verification with OTP
- Google Sign-In
- Session management

**Usage:**

```dart
final authService = ref.watch(authServiceProvider);
await authService.signUpWithEmail(email, password);
```

### 2. Firestore Integration

The app uses two main services for Firestore operations:

#### UserService

Handles user profile data:

```dart
final userService = ref.watch(userServiceProvider);
await userService.createUser(userModel);
final user = await userService.getUser(uid);
```

#### ChargerService

Handles EV charger listings:

```dart
final chargerService = ref.watch(chargerServiceProvider);
await chargerService.addCharger(chargerModel);
final chargers = chargerService.getAvailableChargers();
```

### 3. State Management with Riverpod

The app uses Flutter Riverpod for state management with these key providers:

#### Auth Providers

- `authServiceProvider` - Firebase Auth service instance
- `authStateProvider` - Stream of current auth state
- `userProvider` - Current authenticated user

#### User Data Providers

- `userServiceProvider` - Firestore user service instance
- `currentUserDataProvider` - Future provider for user data
- `userStreamProvider` - Real-time user data stream

#### Charger Providers

- `chargerServiceProvider` - Firestore charger service instance
- `hostChargersProvider` - Stream of chargers owned by current user
- `availableChargersProvider` - Stream of all available chargers

#### Firebase Service Providers

- `firebaseAuthProvider` - Direct Firebase Auth instance
- `firebaseFirestoreProvider` - Direct Firestore instance
- `firebaseStorageProvider` - Direct Firebase Storage instance
- `firebaseAuthStateProvider` - Direct auth state stream
- `firebaseUserProvider` - Direct current user

### 4. Navigation & Auth Flow

The `GoRouter` automatically handles navigation based on authentication state:

- Unauthenticated users are redirected to `/login`
- Authenticated users can access protected routes
- Auth routes redirect to `/home` if already logged in

**Firestore Collections Schema:**

#### Users Collection

```json
{
  "uid": "user_id",
  "email": "user@example.com",
  "name": "User Name",
  "phone": "+1234567890",
  "role": "renter|host",
  "authProvider": "password|google.com",
  "passwordManagedByFirebase": true,
  "passwordUpdatedAt": "timestamp|null",
  "profileImage": "url",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

Security note: user passwords are NOT stored in Firestore. Firebase Authentication stores them using strong salted hashing. Firestore only stores metadata (for example `passwordManagedByFirebase`) and explicitly rejects password/hash fields via rules.

#### Chargers Collection

```json
{
  "id": "charger_id",
  "hostUid": "host_user_id",
  "name": "Charger Name",
  "location": "Address",
  "latitude": 0.0,
  "longitude": 0.0,
  "availability": {
    "startTime": "08:00",
    "endTime": "22:00",
    "daysAvailable": ["Monday", "Tuesday", ...]
  },
  "images": ["url1", "url2"],
  "pricePerHour": 5.99,
  "isAvailable": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### Bookings Collection

```json
{
  "id": "booking_id",
  "chargerId": "charger_id",
  "renterId": "renter_user_id",
  "hostId": "host_user_id",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "totalPrice": 25.99,
  "status": "pending|confirmed|completed|cancelled",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Getting Started

### 1. Firebase Project Setup

The Firebase project "voltbnb" has already been configured with:

```
Project ID: voltbnb
Owner: Your Firebase Account
```

### 2. Platform-Specific Configuration

The `firebase_options.dart` file was auto-generated and contains platform-specific configurations for:

- **Web** - App ID: 1:734117694381:web:88fcacca28923ebf2f6f24
- **Android** - App ID: 1:734117694381:android:5b3d401cc7feaf8f2f6f24
- **iOS** - App ID: 1:734117694381:ios:e264b02fe4b833e42f6f24
- **Windows** - App ID: 1:734117694381:web:81a896964777defc2f6f24

### 3. Environment Variables

No environment variables need to be set. Firebase configuration is handled automatically through `firebase_options.dart`.

### 4. Testing Firebase Integration

#### Test Authentication

```dart
void testAuth() async {
  final authService = ref.watch(authServiceProvider);
  try {
    await authService.signUpWithEmail('test@example.com', 'password123');
    print('User created successfully');
  } catch (e) {
    print('Error: $e');
  }
}
```

#### Test Firestore

```dart
void testFirestore() async {
  final userService = ref.watch(userServiceProvider);
  try {
    final user = await userService.getUser('uid');
    print('User: $user');
  } catch (e) {
    print('Error: $e');
  }
}
```

## Important Notes

### Google Sign-In

Google Sign-In requires additional setup:

1. Configure OAuth 2.0 credentials in Firebase Console
2. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
3. Uncomment the Google Sign-In code in `auth_service.dart`

### Security Rules

Before deploying to production, configure Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if request.auth.uid == uid;
    }

    match /chargers/{chargerId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.hostUid;
    }

    match /bookings/{bookingId} {
      allow read: if request.auth.uid in [resource.data.renterId, resource.data.hostId];
      allow create: if request.auth.uid == request.resource.data.renterId;
      allow update, delete: if request.auth.uid in [resource.data.renterId, resource.data.hostId];
    }
  }
}
```

## Troubleshooting

### Firebase Not Initializing

- Check that `firebase_options.dart` exists in `lib/`
- Ensure `flutterfire configure` was run successfully
- Verify internet connection for Firebase initialization

### Authentication Errors

- Check Firebase Console for API key restrictions
- Verify email/password requirements in Firebase Auth settings
- Ensure user is created before attempting login

### Firestore Access Denied

- Review and update Firestore security rules
- Verify user is authenticated
- Check user permissions in Firebase Console

## References

- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
- [Cloud Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Riverpod Documentation](https://riverpod.dev)
