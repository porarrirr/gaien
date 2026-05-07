# Strict UI Target Mapping

The images in `C:\Users\nmrhr\.codex\generated_images\019e01a0-74c7-72f2-8297-bd274c07973d\strict_selected` are iPhone UI targets for the iOS app. Each file maps to the current SwiftUI surface below.

| Target image | iOS surface |
| --- | --- |
| `01_home.png` | `HomeScreen` |
| `02_timer.png` | `TimerScreen` portrait |
| `03_session_evaluation.png` | `SessionEvaluationSheet` in `TimerScreen` |
| `04_manual_entry.png` | `ManualEntrySheet` in `TimerScreen` |
| `05_materials.png` | `MaterialsScreen` |
| `06_material_editor.png` | `MaterialEditorSheet` |
| `07_progress_editor.png` | `ProgressEditorSheet` |
| `08_isbn_search.png` | `IsbnSearchSheet` |
| `09_book_result.png` | `BookResultSheet` |
| `10_material_history.png` | `MaterialHistoryScreen` |
| `11_subjects.png` | `SubjectsScreen` |
| `12_calendar_summary.png` | `CalendarScreen` summary mode |
| `13_calendar_timeline.png` | `CalendarScreen` timeline mode |
| `14_history.png` | `HistoryScreen` |
| `15_history_editor.png` | history edit sheet in `HistoryScreen` and `CalendarScreen` |
| `16_timetable.png` | `TimetableScreen` |
| `17_timetable_entry_editor.png` | `TimetableEntryEditorSheet` |
| `18_timetable_term_editor.png` | `TimetableTermEditorSheet` |
| `19_timetable_period_settings.png` | `TimetablePeriodSettingsSheet` |
| `20_timetable_review_record.png` | `TimetableReviewEditorSheet` |
| `21_reports.png` | `ReportsScreen` |
| `22_plan_create.png` | `CreatePlanSheet` |
| `23_plan_item_editor.png` | `PlanItemEditorSheet` |
| `24_exam_editor.png` | `ExamEditorSheet` |
| `25_cloud_sync_auth.png` | `AuthSheet` in `SettingsScreen` |
| `26_debug_logs.png` | `DebugLogSheet` in `SettingsScreen` |
| `27_exams_strict.png` | `ExamsScreen` |
| `28_goals_strict.png` | `GoalsScreen` |
| `29_plan_strict.png` | `PlanScreen` |
| `30_settings_strict.png` | `SettingsScreen` |
| `31_onboarding.png` | `OnboardingScreen` |
| `32_barcode_scanner.png` | `BarcodeScannerSheet` / `BarcodeScannerView` |
| `33_landscape_timer_problem_progress.png` | `LandscapeTimerFocusView` |
| `34_landscape_timer_clock_only.png` | `LandscapeClockOnlyTimerView` |

Visual rules copied into implementation:

- Use a quiet light gray app background and white, bordered cards.
- Prefer green for primary progress/action states, blue for book/scanner utility actions, orange/red for warnings.
- Keep screens dense and readable, with compact pills and small section headers.
- Keep timer landscape views dark and full-screen.
