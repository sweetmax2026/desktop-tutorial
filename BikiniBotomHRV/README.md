# BikiniBotomHRV

A personal-use SwiftUI app for Apple Watch and iPhone that reads existing HealthKit HRV (SDNN) samples and presents lightweight trends and reminders.

## What it does

- Reads existing HRV samples from HealthKit
- Shows the latest reading, baseline, trend, and diagnostic state
- Offers reminder rules with a cooldown and quiet hours
- Includes companion iPhone dashboard views

## Important limits

This is an experimental personal wellness project, not medical software. It does not measure HRV directly or diagnose health conditions. Refreshing only re-reads samples that HealthKit already has, and watchOS background delivery and notifications are system-scheduled rather than guaranteed in real time.

## Run locally

1. Open `BikiniBotomHRV.xcodeproj` in Xcode.
2. Select each iPhone and Watch target and choose your own signing team.
3. Replace the example bundle identifiers before installing on a device.
4. Enable HealthKit for your Apple developer account and grant the requested Health permissions on the test device.

The published project intentionally excludes personal signing details, Xcode user settings, build artifacts, and Health data.
