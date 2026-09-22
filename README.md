# Apartment Platform (FIG 2026)

A cross-platform mobile application developed with **Flutter** and **Firebase**, designed to assist users in searching, evaluating, and applying for rental and purchase properties, while managing mortgage simulations and document submissions.

---

## 📋 Table of Contents
- [Project Overview](#project-overview)
- [Target User Personas](#target-user-personas)
- [Core Features & Epics](#core-features--epics)
- [Tech Stack & Architecture](#tech-stack--architecture)
- [Sprint 0 Requirements & Checklist](#sprint-0-requirements--checklist)
- [Getting Started](#getting-started)
- [Git Workflow & Branching Strategy](#git-workflow--branching-strategy)
- [Team & Course Contacts](#team--course-contacts)

---

## 🏢 Project Overview

The **Apartment Platform** simplifies the real estate search and acquisition process for both prospective tenants and buyers. The application centralizes:
- Finding, filtering, and bookmarking available apartments and houses.
- Scheduling visits and submitting rental dossiers.
- Calculating mortgage estimates and affordability ratios.
- Securely storing documents and interacting with real estate listings in real time.

---

## 👥 Target User Personas

1. **The Prospective Tenant (e.g., Student / Young Professional)**
   - Needs fast search, price/commute filters, dossier uploads, and visit bookings.
2. **The Property Buyer / Family**
   - Focuses on detailed property metrics, surface area, neighborhood ratings, and mortgage simulation tools.
3. **The Property Owner / Agency Representative**
   - Manages apartment listings, reviews applicant dossiers, and coordinates visit slots.

---

## 🚀 Core Features & Epics

Derived from the Product Backlog (`ProductBacklog_FIG_2026_Apartment`):

### 1. Authentication & Profile Management
- Secure authentication via Firebase (Email/Password, OAuth providers).
- Role-based profile management (Tenant, Buyer, Landlord/Agent).
- Dossier profile management (identity proofs, salary slips, credit certificates).

### 2. Property Discovery & Search
- Interactive map view and list view of available listings.
- Multi-criteria filtering (location, rent/sale price, number of rooms, surface area, amenities, energy ratings).
- Detailed property pages with image galleries, floor plans, and amenity highlights.
- Favorites / Bookmarking system for quick comparison.

### 3. Mortgage & Affordability Calculator
- Loan estimation tool based on down payment, interest rates, and loan duration.
- Affordability threshold check (e.g., debt-to-income ratio guidelines).

### 4. Visit Scheduling & In-App Inquiries
- Request and schedule on-site or virtual visits.
- Direct messaging or contact forms with listing agents/owners.

### 5. Application & Dossier Submission
- One-click application using pre-uploaded dossier documents.
- Application status tracking (Under Review, Accepted, Declined).

---

## 🛠️ Tech Stack & Architecture

- **Framework:** [Flutter](https://flutter.dev/) (Targeting Android and iOS)
- **Programming Language:** [Dart](https://dart.dev/)
- **Backend & Database:** [Google Firebase](https://firebase.google.com/) (Authentication, Cloud Firestore, Firebase Storage)
- **Routing & Navigation:** [`go_router`](https://pub.dev/packages/go_router)
- **State Management:** Provider / Riverpod / Bloc *(team preference)*
- **Version Control:** Git & GitHub

---

## 📌 Sprint 0 Requirements & Checklist

- [x] Complete the individual Flutter Lab.
- [x] Create project repository and link to GitHub.
- [x] Add course instructor (`@Gianou` / `david.gianadda@hevs.ch`) as collaborator.
- [ ] Ensure all team members have cloned and successfully executed `flutter run`.
- [ ] Formulate and document git branching strategy.
- [ ] Scaffold folder architecture with placeholder screens using `go_router`.
- [ ] Configure Android build settings for deployment on Google Play Console (Closed Beta).

---

## 💻 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter & Dart extensions
- Git installed on your system

### Installation & Execution

1. **Clone the repository:**
   ```bash
   git clone https://github.com/dace4/apartment-app.git
   cd apartment-app
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter setup:**
   ```bash
   flutter doctor
   ```

4. **Run the project on a connected device/emulator:**
   ```bash
   flutter run
   ```

---

## 🌿 Git Workflow & Branching Strategy

To keep development organized and maintain clean releases, follow the **Feature Branch Workflow**:

- **`main`**: Production-ready code. No direct commits allowed; updates arrive only through reviewed Pull Requests.
- **`develop`**: Integration branch for ongoing sprint features.
- **Feature Branches**: Branch off from `develop` using the following naming structure:
  - `feature/<backlog-id>-<short-description>` (e.g., `feature/US-01-auth-screen`)
  - `fix/<short-description>` (e.g., `fix/navigation-back-button`)

### Contribution Steps
1. Pull the latest updates: `git checkout develop && git pull`
2. Create your branch: `git checkout -b feature/US-02-property-list`
3. Commit with concise messages: `git commit -m "feat: implement property card widget"`
4. Push and open a Pull Request against `develop`.

---

## 👥 Course & Team Information

- **Course:** Mobile Application Development (FIG 2026) — HES-SO Valais-Wallis (HEVS)
- **Instructor:** David Gianadda ([@Gianou](https://github.com/Gianou) / `david.gianadda@hevs.ch`)
- **Group:** Group 2