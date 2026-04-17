# ⚡ VoltBnB: The Future of EV Charging

VoltBnB is a premium, community-driven marketplace for Electric Vehicle (EV) charging. It connects EV owners (Renters) with private charging station hosts, enabling a seamless "Airbnb-style" experience for EV infrastructure.

---

## 🧭 Project Vision
VoltBnB addresses the "range anxiety" of EV drivers by unlocking thousands of private charging points. Built with a focus on **premium aesthetics**, **real-time reliability**, and **secure transactions**.

## ✨ Key Features

### 🚗 For Drivers (Renters)
- **Map-Based Discovery**: Interactive Mapbox integration to find nearby chargers with real-time availability.
- **Smart Filtering**: Filter by connector type (Type 2, CCS2, etc.), price range, and host amenities.
- **Dynamic Pricing**: Automatic adjustment for "Happy Hours" or peak demand surges.
- **Secure Payments**: Integrated Razorpay checkout for slot reservation fees.
- **Live Charging Sessions**: High-tech dashboard to monitor energy delivery (kWh) and elapsed time in real-time.
- **Review System**: Rate and review stations to ensure community quality.

### 🏠 For Hosts
- **Station Management**: Easily list your home or commercial charger with photos and technical specs.
- **Approval Workflow**: Multi-stage booking approvals—hosts review and confirm session requests before they are finalized.
- **Earnings Dashboard**: Track revenue with interactive fl_chart visualizations and detailed payout history.
- **Live Session Control**: Monitor active charging sessions at your station via Firebase Realtime Database.
- **Notification Suite**: Dedicated host notification center for bookings, payments, and system alerts.

---

## 🎨 Design System: "Electric Modern"
VoltBnB has been meticulously modernized to meet an intermediate-to-advanced design standard:
- **Primary Brand Color**: `Electric Green (#22C55E)`
- **Typography**: `Inter` (Google Fonts) – focus on readability and modern tech aesthetic.
- **Geometry**: Consistent "Soft Rectangle" approach (14px—24px radii) for a premium, tactile feel.
- **Design Tokens**: Glassmorphism, subtle micro-animations (flutter_animate), and high-contrast dark modes for live sessions.

---

## 🛠 Tech Stack
- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Riverpod](https://riverpod.dev) (Functional & Signal-based reactive logic)
- **Backend/Database**: 
  - **Cloud Firestore**: Persistent data (Users, Chargers, Bookings).
  - **Firebase Realtime DB**: High-frequency telemetry (Live Charging Sessions).
  - **Firebase Auth**: Secure role-based authentication.
- **Payments**: Razorpay (Dual-platform: Mobile & Web).
- **Mapping**: Flutter Map with Mapbox Static & Vector tiles.

---

## ⚡ Getting Started

### Prerequisites
- Flutter SDK (v3.19.0 or higher recommended)
- Firebase Project configured
- Razorpay API Keys (Test Mode)
- Mapbox Access Token

### Configuration
Create a `.env` file in the root directory:
```env
MAPBOX_ACCESS_TOKEN=your_mapbox_token
RAZORPAY_TEST_KEY=rzp_test_your_key
```

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/duality-2/VoltBnB.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## 📁 Architecture
The project follows a **Feature-First** structure for maximum scalability:
```text
lib/
├── core/                # Global themes, constants, router, and utilities
├── features/
│   ├── auth/            # Login, Signup, OTP, Role-selection
│   ├── booking/         # Detail screens, Dashboard, Success/Live screens
│   ├── charger/         # Add/Edit chargers, My Chargers, Filters
│   ├── home/            # Map, Role-wrappers, Search
│   ├── profile/         # User management, Branding
│   └── notifications/   # Specialized host and driver alerts
└── main.dart            # App entry point
```

---

## 🤝 Community & Support
Developed with ❤️ by the VoltBnB team. Elevating the EV charging experience, one kilowatt at a time.
