````markdown
# Mobile Application Development — In-Class Activity 08

## Local Storage: Fall Festival Roster

This Flutter app stores a fictional Fall Festival guest roster in a local SQLite database. It supports adding, editing, deleting, refreshing, and validating guests on one Material screen.

**Student pathway:** Graduate.

## Setup and run

From the project root:

```powershell
flutter pub get
flutter run
```

Use an Android device or emulator on Windows. The supplied `sqflite` setup does not support Flutter web or Windows/Linux desktop.

- Flutter SDK: Flutter 3.47.4 stable.
- Dart SDK: Dart 3.13.3.
- Manual verification platform: Android.
- Device model: Samsung Galaxy S25 FE.

## Dependencies

The existing generated SDK constraint and project settings were retained. Dependencies were aligned with the assignment:

- `sqflite: ^2.4.1`
- `path_provider: ^2.1.5`
- `path: ^1.9.0`

## Implementation summary

- `DatabaseHelper.init()` opens `MyDatabase.db` in the application documents directory.
- SQLite table `my_table` contains `_id INTEGER PRIMARY KEY`, `name TEXT NOT NULL`, and `age INTEGER NOT NULL`.
- The roster screen loads rows and count from `initState()` and displays loading, empty, populated, and read-error states.
- Updates and deletes use parameterized `whereArgs` to target record IDs.
- Names are trimmed and must be nonempty.
- Ages use `int.tryParse()` and must be integers from 0 through 130.
- No records are seeded automatically.


## Manual verification matrix

The tests were completed during an Android mobile run. River record A had generated ID **1**, and River record B had generated ID **2**.

| Test ID | Action/input | Expected | Observed rows/count | Pass/fail |
|---|---|---|---|---|
| T1 | Start with zero disposable rows; press Refresh. | Count 0 and successful empty-state message. | Count 0; “No festival guests yet” shown. | Pass |
| T2 | Add River/21 and River/34. | Two distinct generated IDs; count 2. | ID 1: River/21; ID 2: River/34; count 2. | Pass |
| T3 | Edit ID 2 to 99 and Cancel; edit ID 2 again and save 35. | Cancel preserves 34; update affects 1; count 2; ID 1 remains 21. | Cancel preserved 34; update affected 1 row; ID 1 remained 21; ID 2 became 35; count 2. | Pass |
| T4 | Stop the process and relaunch without clearing storage. | Same IDs, names, ages, and count; no reseeding. | ID 1: River/21; ID 2: River/35; count 2 after relaunch. | Pass |
| T5 | Cancel deletion of ID 1, then confirm deletion and Refresh. | Cancel leaves count 2; delete affects 1; only ID 2 remains; count 1. | Cancel left count 2; delete affected 1 row; only ID 2 remained; count 1. | Pass |
| T6a | Space-only name with age 21. | Validation feedback; no write; count 1. | Rejected; no row written; ID 2 remained River/35; count 1. | Pass |
| T6b | Maple with age `abc`. | Validation feedback; no write; count 1. | Rejected; no row written; ID 2 remained River/35; count 1. | Pass |
| T6c | Maple with age `1.5`. | Validation feedback; no write; count 1. | Rejected; no row written; ID 2 remained River/35; count 1. | Pass |
| T6d | Maple with age `-1`. | Validation feedback; no write; count 1. | Rejected; no row written; ID 2 remained River/35; count 1. | Pass |
| T6e | Maple with age `131`. | Validation feedback; no write; count 1. | Rejected; no row written; ID 2 remained River/35; count 1. | Pass |
| T6f | Add Acorn, age 0. | Accepted with a distinct generated ID; count 2. | Accepted with a distinct generated ID; count 2. | Pass |
| T6g | Add Oak, age 130. | Accepted with a distinct generated ID; final count 3. | Accepted with a distinct generated ID; final count 3. | Pass |



The required screenshots were captured during the manual mobile run. 
### T4 restart method

I stopped the app, force-stopped it through Android App Info, and reopened the same installation without clearing storage or uninstalling it.

Before and after restarting, the roster contained:

- ID 1: River, age 21.
- ID 2: River, age 35.
- Record count: 2.

The before and after screenshots document these results.

## Analyzer

The final analyzer output is saved in:

`evidence/analysis_output.txt`

The analyzer passed with no issues.

## Graduate reflections

### 1. The disappearing-data mystery

Before restarting, I predicted that both River records would remain because they were saved in the local database instead of only being kept on the screen. In `main.dart`, I first prepare Flutter, create the helper, and wait for `helper.init()` to open `MyDatabase.db`; then I start `RosterPage`. In the page’s `initState()`, `_loadRoster()` asks the helper for the saved rows and count, and the page displays them after the results are returned. The records had IDs 1 and 2, ages 21 and 35, and count 2 before and after I force-stopped and reopened the app, as documented in `evidence/T4_before.png` and `evidence/T4_after.png`; missing or changed records or IDs, or a count returning to zero, would have disproved my prediction.

### 2. Two Rivers, one wrong edit

I used the ID to tell the two River records apart because they had the same name. I changed River with ID 2 to age 99 and canceled, so it stayed 34, then edited ID 2 again and saved age 35. The update affected one row, River with ID 1 stayed at age 21, and the count remained 2.

### 3. My usability walkthrough

I found the screen easy to follow because it showed the name field, age field, record count, and saved guests together. The validation messages helped me correct values such as age `131`, and the delete confirmation helped prevent accidental deletion. One improvement I would consider is showing a more noticeable success message after every add, edit, or delete.

### 4. Defending the storage boundary

I chose ages from 0 through 130 and required a trimmed, nonempty name because those checks prevent clearly unusable guest records while accepting the assignment’s valid boundaries. These checks belong in the form for immediate feedback, but the supplied schema’s `NOT NULL` constraints alone cannot reject empty names or out-of-range ages if another write path bypasses the form. A specific schema-change risk is adding a new required column: existing database files would not receive it merely because the creation code changed, since `onCreate` runs only when creating the database. A future change would require a higher database version and a migration that supplies valid values for existing rows while preserving saved guests; implementing that migration is outside this lab.
