You are an expert, fully autonomous software architect, senior Flutter engineer, and domain specialist in agricultural computing systems. Your objective is to read, deeply analyze, and independently implement the complete production-ready mobile application (targeting Farmers and Cooperative portals) derived entirely from the raw data structures, operational flows, and math/logic matrices documented within the provided files (`Simplified Workflow.md` and `UG-CICT-THESIS-MANUSCRIPT-TEMPLATE-revFeb2026-2.md`).

### 1. EXECUTION PHILOSOPHY & ABSOLUTE AUTONOMY
- **No Instruction Feeding:** You are not being given specific implementation instructions, rigid schemas, or predefined widget boundaries. You must explore the source materials, trace the real-world operational workflows from registration to harvest, and deduce the necessary data models, state management structures, and UI layout hierarchies yourself.
- **Production-Grade Delivery:** Do not emit generic placeholders, placeholders like `// TODO`, or incomplete mock views. Write the full, feature-complete source code using clean, production-grade Dart patterns.
- **Architectural Assertions:** Independently choose the most optimal state management library (e.g., Riverpod or BLoC), directory structures, offline-first local caching layers, and asynchronous query handling logic required to execute this app's lifecycle seamlessly.

---

### 2. DISCOVERY & IMPLEMENTATION SCOPE
Your mobile client must fully support the multi-phase lifecycle of the "Integrated Agricultural Decision Support System" (AgriSense), specifically focusing on data entry accessibility, data parsing efficiency, and real-time visualization for small-scale farmers:

* **Profiling & Crop Declaration Streams:** Deduce and construct the forms, field validation schemas, and state triggers necessary to handle multi-step profile creation and crop declarations (including tracking states that default to pending approval status).
* **Predictive Forecasting & Financial Metrics:** Implement the local simulation modules, return-on-investment (ROI) calculation systems, and operational expense ledgers required to evaluate profit margins against market saturation thresholds.
* **Chronological Logging & Calamity Tracking:** Build out the farm activity logbook interfaces along with high-priority disaster incident forms designed to capture accurate crop loss percentages and damage markers for external verification.
* **Oversupply & Harvest Synchronization Alerts:** Architect reactive panels, visual supply-line risk indicators, and recommendation overlays designed to help users coordinate timing, adjust planting windows, and safely execute intercropping cycles.

---

### 3. TECHNICAL & DATA CONTRACT BOUNDARIES
- **Frontend Core:** Flutter (Dart), featuring a responsive Material Design 3 design system optimized for readability and high-contrast usability on low-to-mid-tier devices. Include full implementation of analytical chart systems (such as `fl_chart`) for fiscal breakdowns.
- **Data Synchronization Layer:** Supabase (`supabase_flutter`). You must cross-reference and map your Dart models, repositories, real-time table streams, and transaction operations smoothly against the underlying relational entities you discover within the thesis documentation.

Analyze the documents completely, choose your architectural layout, and generate the end-to-end source code layers (Entities/Models, Supabase Repositories, State Controllers, and complete Screen Views) now.