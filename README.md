# MacroCheck — Smart Nutrition Tracker

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)

A full-featured Flutter nutrition tracking app with multi-source food search (Brazilian TACO table, Open Food Facts, FatSecret API), barcode scanning, voice input, daily macro dashboard, and meal history calendar.

## Key Features

- **Progressive Multi-source Search:** Fast offline searches with SQLite (TACO DB) and fallback to Open Food Facts and FatSecret API, utilizing relevance scoring.
- **Advanced Inputs:** Support for text search, barcode scanning (`mobile_scanner`), and voice input (`speech_to_text`).
- **Offline-First Architecture:** Local data persistence with `sqflite` ensures the app works smoothly without an internet connection.
- **OAuth2 Token Management:** Secure API communication with FatSecret.
- **Beautiful UI:** Bento-grid daily dashboard and calendar-based meal history.
- **Internationalization:** Support for Portuguese (PT) and English (EN).

## Tech Stack

- **Framework/Language:** Flutter / Dart
- **State Management:** Riverpod
- **Local Storage:** SQLite (`sqflite`, `sqlite3_flutter_libs`)
- **Networking:** Dio
- **UI Components:** `fl_chart`, `table_calendar`, `cached_network_image`, Bento-grid layouts
- **Sensors/Inputs:** `mobile_scanner`, `speech_to_text`

## Architecture Diagram

```mermaid
flowchart TD
    UI[User Input] -->|Text / Barcode / Voice| SE[Search Engine]
    
    subgraph Search Sources
        SE --> LocalDB[(Local TACO DB)]
        SE --> OFA[Open Food Facts]
        SE --> FSA[FatSecret API]
    \end
    
    LocalDB --> RR[Relevance Ranking]
    OFA --> RR
    FSA --> RR
    
    RR --> Details[Food Details & Macro Calculator]
    Details --> Tracking[Meal Tracking]
    Tracking --> SQLite[(SQLite Persistence)]
    SQLite --> Dashboard[Calendar History & Dashboard]
```

## Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/macrocheck-nutrition-app.git
   ```

2. **Install Dependencies:**
   ```bash
   cd macrocheck-nutrition-app
   flutter pub get
   ```

3. **Environment Setup:**
   - Copy the example config files to create your own configuration:
     ```bash
     cp lib/config/env.dart.example lib/config/env.dart
     cp lib/config/secrets.dart.example lib/config/secrets.dart
     ```
   - Add your FatSecret API credentials in `secrets.dart`.

4. **Run the App:**
   ```bash
   flutter run
   ```

## Screenshots
*(Add screenshots here)*

## License

This project is licensed under the MIT License.
