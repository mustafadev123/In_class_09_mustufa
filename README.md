# Mobile Application Development — In-Class Activity 09

## Local Storage Part II: Card Catalogue

This Flutter app extends the In-Class Activity 08 Fall Festival Roster. The existing SQLite database is upgraded from version 1 to version 2. The upgrade adds related **folders** and **cards** tables and keeps the Part I guest table and its rows unchanged.

**Student pathway:** Graduate.

## Setup and run

```powershell
flutter pub get
flutter run
flutter build apk --release
```

- Flutter SDK: Flutter 3.47.4 stable; Dart 3.13.3.
- Platform: Android (Samsung Galaxy S25 FE). The `sqflite` setup used here does not support Flutter web or Windows/Linux desktop.
- Release APK: `build/app/outputs/flutter-apk/app-release.apk`.
- The Android application ID `com.example.in_class_08` and the database filename `MyDatabase.db` are intentionally unchanged from Part I. Version 2 therefore installs over the Part I app and opens the same database file.
- No dependencies were added. The `sqflite`, `path_provider`, and `path` versions from Part I are retained.

## Database lifecycle

| Item | Part I | Part II |
|---|---|---|
| File | `MyDatabase.db` (app documents directory) | same file |
| Version | 1 | 2 |
| Tables | `my_table` | `my_table`, `folders`, `cards` |
| Index | — | `idx_cards_folder_id` on `cards(folder_id)` |

The lifecycle is defined in `lib/database_helper.dart`:

- `onConfigure` runs `PRAGMA foreign_keys = ON` on every connection. SQLite does not enforce foreign keys without it.
- `onCreate` (fresh install) calls `createPartOneTables()` and then `createCatalogueTables()`.
- `onUpgrade` calls only `createCatalogueTables()` when `oldVersion < 2`. The `my_table` table is never dropped or recreated. Version gates keep a future version 3 from rerunning this step.
- Migration errors are not caught. They propagate, the sqflite callback transaction rolls back, and the existing startup error screen in `main.dart` is shown.
- No seed data is inserted. Every folder and card is created through the UI.

```sql
CREATE TABLE folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL            -- ISO-8601
);
CREATE TABLE cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  suit TEXT NOT NULL,                 -- Hearts | Diamonds | Clubs | Spades
  notes TEXT NOT NULL DEFAULT '',
  image_ref TEXT,                     -- nullable reference, not image bytes
  folder_id INTEGER NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
);
CREATE INDEX idx_cards_folder_id ON cards(folder_id);
```

## Code structure

| File | Responsibility |
|---|---|
| `lib/database_helper.dart` | Opens the database, versioned schema, Part I guest CRUD, read-only `diagnostics()` |
| `lib/models.dart` | `Suit`, `Folder`, `CardRecord` with `fromMap`/`toMap` |
| `lib/catalogue_repository.dart` | All catalogue SQL. Uses `whereArgs`, returns insert IDs and affected-row counts, and converts UNIQUE violations into `DuplicateFolderNameException`. |
| `lib/folders_page.dart` | Folder list with `LEFT JOIN` counts, create dialog, confirmed delete, links to roster and diagnostics |
| `lib/cards_page.dart` | One folder's cards (queried by `folder_id`), confirmed delete |
| `lib/card_form_page.dart` | Shared Add/Edit card form |
| `lib/card_image.dart` | Renders `image_ref`, with a suit-symbol fallback |
| `lib/diagnostics_page.dart` | Read-only PRAGMA and Part I row evidence for T1 |
| `lib/roster_page.dart` | Part I guest roster (unchanged), opened from the 👥 icon |

## Design decisions

### Delete policy: `ON DELETE CASCADE`

In this lab a card belongs to its folder, so deleting a folder deletes its cards. The confirmation dialog shows the folder ID, its name, and how many cards will be removed. After the delete, the app checks how many cards still reference the deleted ID and displays that number.

The alternatives are worth choosing in other situations:

- **`RESTRICT` / `NO ACTION`:** refuse to delete a folder that still has cards. This is preferable when cards are valuable on their own and losing them silently would be costly. The user must empty the folder first.
- **Reassign:** inside one transaction, move the cards to another folder (for example "Unsorted") and then delete the parent. This is preferable when folders are just labels and the cards matter more.
- **Archive (soft delete):** add an `archived_at` column and hide archived folders instead of deleting rows. This is preferable when undo, an audit trail, or sync with a server is needed. It costs extra filtering in every query.

Folder names are never overwritten with `ConflictAlgorithm.replace`. A replace deletes the old parent row, and the cascade would then delete its cards. A duplicate name is shown as an error instead.

### Image storage: nullable `image_ref`

`image_ref` stores a reference (an `assets/...` path or an `http(s)://` URL), never image bytes. Most cards use `NULL` and display the suit-symbol fallback. A reference that is invalid, a missing asset, or a failed network load also falls back to the suit symbol, so the row stays usable. No image is bundled and no gallery picker is used, so no private photo paths are stored and no test depends on the network.

| Approach | Trade-off |
|---|---|
| Bundled asset path | Works offline; increases app size; changing the image needs a new build |
| App-private file path | Keeps the database small; the app must manage the file's lifecycle and handle missing files |
| Remote URL | Small record; needs a network connection, may be slow, and may change or disappear |
| BLOB in row | Self-contained; makes the database larger and every read heavier |

### Validation

- **Folder name:** trimmed and must be nonempty. Duplicates are rejected by the UNIQUE constraint with visible feedback. The comparison is case-sensitive (SQLite default), so "Atlas" and "atlas" are distinct folders.
- **Card title:** trimmed and must be nonempty. Duplicate titles are allowed. The suit (exactly one) and folder (an existing ID) are required. Empty notes are stored as `''` and an empty image reference is stored as `NULL`.
- **Writes:** Edit and Delete target the integer ID. An update or delete that affects 0 rows is reported as a failure. While a write is running a single busy flag disables the controls, input is kept when a write fails, and a failed refresh after a successful write is reported separately without repeating the write.

## Manual test matrix

Tests were run on the Samsung Galaxy S25 FE (Android). Values come from the screenshots in `evidence/` unless marked **reported (no screenshot)**. Those steps were performed and observed on the device but not captured. Rows marked **Pending** have not been run and are not claimed as passing.

### T1 — Upgrade and fresh creation

**Limitation:** the original In-Class 08 database on the device was lost, so the upgrade could not be tested against the original Part I rows. To retest the v1 → v2 upgrade path, I reinstalled the Part I (database version 1) APK, added two fictional guests (river/34 and pearl/35), and then installed the v2 release APK over that installation without clearing storage. This is a genuine version 1 → version 2 upgrade of a populated database, not a fresh v2 install.

**Part I state before the upgrade (v1 app):** river, age 34, and pearl, age 35; count 2 (reported; `evidence/T1_before.png` to be added if available).

**Part I state after the upgrade** (`evidence/T1_upgrade_part_one_rows.jpg`, 12:36):

| `_id` | name | age |
|---|---|---|
| 1 | river | 34 |
| 2 | pearl | 35 |

`part_one_count`: 2

| Subtest | Target | Action | Expected | Observed | Pass/fail |
|---|---|---|---|---|---|
| T1a | S25 FE, reinstalled Part I v1 install (`com.example.in_class_08`) with 2 guests | Installed the v2 release APK over the v1 install and opened Schema diagnostics | `user_version` 2; `foreign_keys` 1; tables `my_table`, `folders`, `cards`; FK with CASCADE; index present; Part I rows unchanged | `user_version` 2; `foreign_keys` 1; tables `cards`, `folders`, `my_table`; `foreign_key_list(cards)`: `folder_id → folders(id)`, `on_delete` CASCADE, `on_update` NO ACTION; `index_list(cards)`: `idx_cards_folder_id` (unique 0, origin `c`). The first-run screenshot (`T1_upgrade_schema_diagnostics.jpg`, 12:15) shows `user_version` and `foreign_keys`; the second-run screenshot (`T1_upgrade_part_one_rows.jpg`, 12:36) shows the same FK and index on the re-upgraded database. Part I rows after the upgrade: 1 river/34, 2 pearl/35, count 2, matching the two guests added in v1 (`T1_upgrade_part_one_rows.jpg`) | Pass (see limitation above) |
| T1b | Separate fresh v2 install, target: _TARGET_ (13 Oct, 1:01) | Fresh install of v2, opened Schema diagnostics and the folder list | `user_version` 2; `foreign_keys` 1; all three tables and the index present; empty folder opens with no schema error | `user_version` 2; `foreign_keys` 1; tables `cards`, `folders`, `my_table`; FK `folder_id → folders(id)` `on_delete` CASCADE; `idx_cards_folder_id` present (`T1_fresh_schema_diagnostics.jpg`). `part_one_rows` [], `part_one_count` 0, so `onCreate` built the Part I table empty (`T1_fresh_part_one_empty.jpg`). Catalogue opened with "Folders: 0" and the empty-state message, no schema error (`T1_fresh_empty_catalogue.jpg`). Opening an empty folder was not captured. | Pass (schema); empty-folder open not captured |

### T2–T6

**Note on test runs:** the screenshots come from two database instances on the same device, distinguishable by time and IDs:

- **First run (12:15–12:22):** v2 schema diagnostics, T2, T3, T4, the T5 cascade, and T6 validation. Atlas is folder 1, Harbor is folder 2, and the Compass cards are card IDs 1 and 2.
- **Second run (from 12:36):** after reinstalling the v1 app with two guests and upgrading again (see T1). It covers the T1 Part I row preservation and the T6 Signal fallback. In this database Signal is card ID 1 in Harbor (folder 2).

IDs are only compared within the same run.

| Test | Action/input | Expected | Observed IDs/values/counts | Pass/fail |
|---|---|---|---|---|
| T2 | Created Atlas and Harbor; added Compass ×2 to Atlas and Signal to Harbor (Signal `image_ref` NULL) | 3 distinct card IDs; Atlas 2, Harbor 1 | Folder IDs: 1 Atlas, 2 Harbor. Atlas cards: ID 1 Compass (Hearts, `image_ref` NULL), ID 2 Compass (Diamonds, `image_ref` NULL). Harbor count 1 (Signal's card ID in this run was not captured). Counts: Atlas 2, Harbor 1 (`T2_cards.png`) | Pass |
| T3 | Edited card ID 1 → "Compass revised", Save; then saved again with notes "updated card" | 1 row affected; only that ID changes | "Updated card ID 1: 1 row affected." shown for both saves. Card ID 1 = Compass revised / Hearts / notes "updated card"; card ID 2 unchanged (Compass / Diamonds); Atlas count 2 (`T3_edit_saved_title.jpg`, `T3_edit_saved_notes.jpg`) | Pass |
| T3 (cancel) | Edit card ID 2, Cancel | Nothing written; counts 2 and 1 | Reported (no screenshot): Cancel closed the form without writing; card ID 2 stayed Compass / Diamonds; counts stayed Atlas 2, Harbor 1. Consistent with `T3_edit_saved_notes.jpg`, where card ID 2 is unchanged. | Pass |
| T4 | Force stop, relaunch (procedure below) | Same folders, IDs, values, and counts; no duplicates | After relaunch: 1 Atlas (Cards 2), 2 Harbor (Cards 1), the same two folders as before; no duplicate folders or reseeded rows (`T4_after.png`, 12:20) | Pass |
| T5 (card) | Cancel delete of an Atlas card, then confirm | Cancel changes nothing; delete returns 1; Atlas count 1 | Reported (no screenshot): Cancel left Atlas at 2 cards; the confirmed delete showed "Deleted card ID 2: 1 row affected." (card ID 2, the unrevised "Compass"), and Atlas dropped to 1 card (ID 1, Compass revised), which was then removed by the folder cascade | Pass |
| T5 (folder) | Cancel delete of Atlas, then confirm (folder ID 1) | 1 parent row deleted; 0 cards reference ID 1; Harbor/Signal intact | Cancel (reported, no screenshot) left Atlas and its card in place. Confirmed delete: "Deleted 1 folder (ID 1). Cards still referencing ID 1: 0." Folders: 1; Harbor (ID 2) Cards 1 (`T5_folder_cascade_delete.jpg`). | Pass |
| T6 (fallback) | Open Harbor and view Signal (`image_ref` NULL) | Suit fallback displayed | Harbor (folder ID 2), card "signal", Spades, `image_ref: NULL`, shows the ♠ placeholder; Cards: 1 (`T6_signal_fallback.jpg`, 12:49). This screenshot is from the second database run (see note below), where Signal is card ID 1. NULL-reference cards in the first run also show the ♥/♦ placeholders (`T3_edit_saved_notes.jpg`) | Pass |
| T6 (title) | Add card in Harbor with empty title and no suit | "Enter a card title."; no write | "Enter a card title." and "Choose a suit." shown; form not submitted (`T6_blank_card_title_rejected.jpg`) | Pass |
| T6 (folder name) | Create a folder with a blank name | "Enter a folder name."; no write | "Enter a folder name." shown; Folders count stayed 1 (`T6_blank_folder_name_rejected.jpg`) | Pass |
| T6 (duplicate) | Create a folder named "Harbor" | Duplicate-name error; no write | 'A folder named "Harbor" already exists. Choose a different name.' Folders count stayed 1 (`T6_duplicate_folder_rejected.jpg`) | Pass |

### T4 restart procedure and pre-restart state

Pre-restart state (from `T2_cards.png` and `T3_edit_saved_notes.jpg`): folder 1 Atlas (cards: ID 1 Compass revised / Hearts / "updated card", ID 2 Compass / Diamonds), folder 2 Harbor (1 card: Signal). Counts 2 and 1.

Procedure (reported): closed the app, force-stopped it from Android App info (Force stop, not Clear storage), then reopened the same installation. The same two folders and counts appeared.

### Evidence files

| File | Test |
|---|---|
| `evidence/T1_before.png` | Pending: Part I roster before the upgrade |
| `evidence/T1_upgrade_schema_diagnostics.jpg` | T1: version, foreign keys, tables, FK, index |
| `evidence/T1_upgrade_part_one_rows.jpg` | T1: Part I rows after the upgrade |
| `evidence/T1_fresh_schema_diagnostics.jpg` | T1b: fresh install, version, foreign keys, tables, FK, index |
| `evidence/T1_fresh_part_one_empty.jpg` | T1b: fresh install, empty Part I table |
| `evidence/T1_fresh_empty_catalogue.jpg` | T1b: fresh install, empty catalogue with no error |
| `evidence/T2_cards.png` | T2: Atlas 2, Harbor 1 |
| `evidence/T3_edit_saved_title.jpg` | T3: card ID 1 renamed, 1 row affected |
| `evidence/T3_edit_saved_notes.jpg` | T3: card ID 1 notes saved, card ID 2 unchanged |
| `evidence/T4_after.png` | T4: state after the cold restart |
| `evidence/T5_folder_cascade_delete.jpg` | T5: folder ID 1 deleted, 0 cards still reference it |
| `evidence/T6_signal_fallback.jpg` | T6: Signal (NULL image_ref) shows the ♠ placeholder (second run) |
| `evidence/T6_blank_card_title_rejected.jpg` | T6: blank card title rejected |
| `evidence/T6_blank_folder_name_rejected.jpg` | T6: blank folder name rejected |
| `evidence/T6_duplicate_folder_rejected.jpg` | T6: duplicate "Harbor" rejected |
| `evidence/analysis_output.txt` | `flutter analyze` output |

## Analyzer

`flutter analyze` output is saved in `evidence/analysis_output.txt`. The final run reported **No issues found**.

## References and tool use

- sqflite package documentation; Flutter "Persist data with SQLite" recipe; SQLite foreign key and ALTER TABLE documentation.
- AI assistance: _(tool/model, date, and what it was used for)_
