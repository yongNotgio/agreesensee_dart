# AgriSense Codebase Index

Welcome to the AgriSense codebase! This document serves as a comprehensive index to help you navigate, understand, and modify the system. 

AgriSense is a Flutter mobile application for Farmers and Cooperatives acting as an Integrated Agricultural Decision Support System.

## 📁 Directory Structure

Here is a high-level overview of the project structure and where to find things:

### `lib/` - The Application Source Code
The `lib` directory contains the core Flutter codebase, structured by feature and concern.

- **`main.dart`**: The entry point of the app. Initializes Supabase, sets up caching, and runs the `ProviderScope`.
- **`app.dart`**: Contains the `MaterialApp.router` configuration and global theme settings.

#### 1. `lib/core/` (Foundational Logic & Utilities)
This contains the non-feature-specific code.
- **`config/`**: Compile-time configurations, demo-mode flags, and environment variables.
- **`constants/`**: App-wide constants (crop catalog, barangay names, thresholds).
- **`logic/`**: **Critical Business Logic**. Contains the pure, unit-testable decision engines:
  - `recommendation_engine.dart` (Crop recommendations)
  - `financial_engine.dart` (ROI, break-even analysis)
  - `scenario_engine.dart` (Best/expected/worst case forecasting)
  - `saturation_engine.dart` (Market saturation index)
  - `harvest_sync_engine.dart` (Harvest scheduling and congestion)
- **`router/`**: `go_router` configuration and role-based redirects.
- **`theme/`**: Material 3 theme data, color palettes, and typography.
- **`cache/`**: Offline-first caching layer (`shared_preferences`).
- **`network/`**: Connectivity services.
- **`widgets/`**: Reusable UI components shared across multiple features.

#### 2. `lib/features/` (UI & Feature Modules)
The presentation layer, organized by user roles.
- **`auth/`**: Splash screen, login, registration, and role-based routing gates.
- **`farmer/`**: The Farmer portal. Handles crop declarations, financial tabs, advisory, and logbook/calamity reporting.
- **`cooperative/`**: The Cooperative portal. Contains the supply-chain dashboard, surplus routing, and harvest synchronization overviews.
- **`shared/`**: Screens or features shared between Farmers and Cooperatives.

#### 3. `lib/models/` (Data Entities)
Contains plain Dart classes mapping 1:1 with Supabase database tables (e.g., `Profile`, `CropDeclaration`, `LogbookEntry`). Includes `fromJson`/`toJson` serialization.

#### 4. `lib/providers/` (State Management)
Riverpod providers, controllers, and state management classes that tie the UI to the repositories and logic engines.

#### 5. `lib/repositories/` (Data Access Layer)
Handles fetching and saving data. Implements an offline-first approach, communicating with the local cache and the Supabase backend.

#### 6. `lib/data/` (Static Datasets)
Contains loaders for static datasets (JSON) to calibrate the decision engines (market prices, production costs, agronomics).

---

### Other Important Directories & Files

- **`supabase/`**: Contains the database schema (`schema.sql`), auth migrations, and `seed.sql` for seeding test data in your Supabase instance.
- **`docs/`**: Detailed technical documentation:
  - `ARCHITECTURE.md`: Architecture overview.
  - `ANALYTICS_AND_MODELLING.md`: Mathematical models used in `lib/core/logic/`.
  - `SYSTEM_FLOW.md`: End-to-end system and cross-portal data flow.
  - `WEB_PORTAL_GUIDE.md`: Guide to building the MAO web portal.
- **`datasets/`**: Human-readable CSVs that act as the source of truth for the app's analytical engines. 
- **`tool/`**: Helper scripts, including `generate_datasets.dart` for converting CSV datasets to JSON.
- **`pubspec.yaml`**: Dart dependencies, SDK constraints, and asset declarations.
- **`README.md`**: Project introduction, setup instructions, and demo credentials.

---

## 🛠️ Tech Stack & Patterns
- **Framework**: Flutter (Dart 3.11)
- **State Management**: Riverpod (`flutter_riverpod`, `riverpod_annotation`)
- **Routing**: `go_router`
- **Backend / Database**: Supabase (`supabase_flutter`)
- **Local Storage**: `shared_preferences`
- **Charts**: `fl_chart`

## 🚀 Running the App

### 1. Demo Mode (Offline)
Run without `.env` to start the app in a fully offline demo mode with seeded data.
```bash
flutter run
```
**Demo Accounts**: `farmer@agrisense.ph` or `coop@agrisense.ph` (any password works).

### 2. Live Supabase Backend
Ensure your `.env` file is present or pass `--dart-define` variables:
```env
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```
Make sure you have run the SQL scripts in the `supabase/` folder to set up your backend first.

## 📝 Tips for Future Development
- **Modifying Math/Logic**: If you need to change how ROI or Market Saturation is calculated, look exclusively in `lib/core/logic/`. These engines are pure Dart functions and do not depend on Flutter or Supabase.
- **Adding a new feature**: Follow the existing pattern: define your data in `lib/models/`, create data access in `lib/repositories/`, handle state in `lib/providers/`, and build the UI in `lib/features/`.
- **Database Changes**: Remember to update the SQL scripts in `supabase/` and adjust your Dart models in `lib/models/` to match.
