# StudyAppMac

StudyAppMac is a native macOS companion for StudyApp. It provides a desktop dashboard, focus timer, study session entry, subject/material management, and local JSON persistence.

## Run

```sh
cd macos/StudyAppMac
./scripts/build_and_run.sh
```

The app stores local data in `~/Library/Application Support/StudyAppMac/study-data.json`.

## Verify

```sh
cd macos/StudyAppMac
swift build
./scripts/build_and_run.sh --verify
```
