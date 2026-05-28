# TruckCab 🚚

**TruckCab** is a Flutter-based logistics marketplace that connects **sellers** (businesses that need goods transported) with **drivers** (truck/van operators). Sellers post delivery orders, drivers accept and fulfill them, and an admin team manages subscriptions and payments — all in one mobile app.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Firebase Setup](#firebase-setup)
- [Building for Release](#building-for-release)
- [Version History](#version-history)

---

## Overview

TruckCab solves a real logistics problem: small businesses have no easy way to find reliable truck drivers on demand, and independent drivers have no central marketplace to find consistent work. TruckCab bridges that gap with a clean, role-based mobile experience.

| Role | What they do |
|------|-------------|
| **Seller** | Post delivery orders, track shipment status, chat with drivers |
| **Driver** | Browse open orders, accept jobs, navigate to pickup/drop-off |
| **Admin** | Approve subscription payments, manage users |

---

## Features

### Authentication
- Email/password sign-up and login via Firebase Auth
- Role selection at sign-up: **Seller** or **Driver**
- Welcome screen with role-based routing
- Persistent session (stays logged in across restarts)

### Seller Dashboard
- Create delivery orders with pickup & drop-off locations
- Attach photos of cargo via image picker
- Map-based location picker (flutter_map + OpenStreetMap)
- View all orders with shipping tracker (Open → Accepted → In Transit → Delivered)
- Real-time order status updates
- Chat with assigned driver
- In-app notifications for status changes
- Subscription required to post orders (gated via Firestore)

### Driver Dashboard
- Browse all open delivery orders
- View order details including cargo photos and seller info
- Accept orders and update status (Picked Up → On the Way → Delivered)
- One-tap Google Maps navigation to pickup/drop-off coordinates
- Vehicle profile (SUV, Small Truck, Medium Truck, Big Truck)
- Driver experience and safety record stored on profile
- Chat with sellers
- In-app notifications for new available orders

### Admin Panel
- View all pending subscription payment requests
- Approve payments → user receives 30-day subscription
- Reject payments with an optional note
- View full payment history across all users
- Logout with protected admin routing

### Subscription System
- Drivers and Sellers subscribe to unlock full app features
- Admin manually approves payments via the admin dashboard
- Subscription stored with expiry date in Firestore
- Automatic expiry checks on every login

### Chat
- Real-time chat between seller and driver on a per-order basis
- Chat request system
- Unread message badge counts
- Message history persisted in Firestore

### Notifications
- In-app notification feed
- Notifications triggered on: order accepted, order status update, payment approved/rejected

### Map
- Interactive map picker using `flutter_map` + OpenStreetMap (no API key needed)
- Tap to set pickup or drop-off coordinates
- Coordinates stored on the order for driver navigation

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| Backend | Firebase (Auth + Firestore) |
| State Management | Provider |
| Maps | flutter_map + OpenStreetMap (latlong2) |
| Location | geolocator |
| Navigation | Google Maps (url_launcher) |
| Images | image_picker |
| Audio | audioplayers (notification sounds) |
| Geocoding | geocoding |

---

## Architecture

```
lib/
├── core/
│   └── constants/          # App-wide constants (status codes, etc.)
├── models/                 # Data models
│   ├── user_model.dart
│   ├── order_model.dart
│   ├── chat_model.dart
│   ├── notification_model.dart
│   └── payment_model.dart
├── providers/              # State management (Provider pattern)
│   ├── auth_provider.dart
│   ├── order_provider.dart
│   ├── chat_provider.dart
│   ├── notification_provider.dart
│   └── payment_provider.dart
├── services/               # Firebase data layer
│   ├── auth_service.dart
│   ├── order_service.dart
│   ├── chat_service.dart
│   ├── notification_service.dart
│   └── payment_service.dart
├── screens/
│   ├── auth/               # Login, Signup, Welcome
│   ├── seller/             # Seller home, create order, orders list, chat requests
│   ├── driver/             # Driver home, dashboard, active order, navigation
│   ├── admin/              # Admin panel (payment approval)
│   ├── chat/               # Chat list, chat screen
│   ├── map/                # Map picker screen
│   ├── notifications/      # Notification feed
│   ├── payment/            # Subscription screen
│   └── splash/             # Splash / loading screen
├── routes/
│   └── app_routes.dart     # Named route definitions
├── widgets/                # Reusable UI components
└── main.dart
```

### Data Flow

```
UI Screen
  └── reads/writes via Provider
        └── Provider calls Service
              └── Service talks to Firestore / Firebase Auth
```

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.7.0`
- Dart `^3.0`
- Android Studio or Xcode (for device/emulator)
- A Firebase project (see below)

### Clone & Install

```bash
git clone https://github.com/uitumenm1023-beep/truckcab.git
cd truckcab
flutter pub get
```

### Run

```bash
flutter run
```

---

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Email/Password** authentication
3. Create a **Firestore** database in production mode
4. Download `google-services.json` → place at `android/app/google-services.json`
5. Download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`

### Firestore Collections

| Collection | Description |
|------------|-------------|
| `users` | User profiles with role, subscription, vehicle info |
| `orders` | Delivery orders with status, locations, photos |
| `chats` | Chat sessions between sellers and drivers |
| `messages` | Individual chat messages per chat |
| `notifications` | Per-user notification feed |
| `payments` | Subscription payment requests and approvals |

---

## Building for Release

### Android AAB (Google Play)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Android APK (direct install)

```bash
flutter build apk --release
```

> A signing keystore is required. Create `android/key.properties` with your keystore path, alias, and passwords.

---

## Version History

### v2.0.0 — May 2026 (Current)
- Redesigned login screen and new Welcome screen
- Seller dashboard overhaul with visual shipping tracker (step indicator)
- Driver home screen rebuilt with vehicle emoji, order cards, and one-tap map navigation
- Order cards show full route (pickup → drop-off city), price, and date
- Admin screen fixed with working logout navigation
- Dark mode / light mode teal color scheme
- Firebase config updated for production

### v1.0.1
- Bug fixes for admin login routing
- Seller order card UI improvements
- Fixed role assignment on Firestore user document creation

### v1.0.0 — Initial Release
- Seller, Driver, Admin roles
- Order creation with map picker
- Real-time chat between seller and driver
- Subscription/payment system with admin approval
- In-app notifications with sound

---

## Repository

[https://github.com/uitumenm1023-beep/truckcab](https://github.com/uitumenm1023-beep/truckcab)
