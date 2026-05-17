# Privacy Policy — WaterLogger

**Last updated: May 2026**

## Overview

WaterLogger is a free, offline-first iOS app for tracking daily water intake. We are committed to protecting your privacy. This policy explains what data the app accesses and how it is handled.

## Data We Access

### Water Intake Data
WaterLogger reads and writes water intake records (amount, beverage type, timestamp) to track your daily hydration progress.

### Apple Health (HealthKit)
With your explicit permission, WaterLogger syncs your water intake entries with the Apple Health app. This allows your data to be visible across other Health-compatible apps and your Apple Watch.

## Data Storage

**All data stays on your device.** WaterLogger uses Apple's SwiftData framework for local on-device storage. No data is transmitted to our servers — we do not operate any servers.

HealthKit sync occurs exclusively within Apple's ecosystem (device ↔ Apple Health ↔ iCloud Health sync if you have that enabled in iOS Settings). WaterLogger has no involvement in or visibility into iCloud sync.

## Data We Do NOT Collect

- We do not collect any personal information
- We do not use analytics or crash-reporting SDKs
- We do not track your usage or behavior
- We do not serve ads
- We do not sell, share, or transmit your data to any third party
- We do not have user accounts or login

## Permissions

| Permission | Why |
|---|---|
| Health (Read) | Display your existing water intake from Apple Health |
| Health (Write) | Save new entries to Apple Health |
| Notifications | Send adaptive hydration reminders during your active window |

All permissions are requested at the time you first use the relevant feature and can be revoked at any time in iOS Settings.

## Children's Privacy

WaterLogger does not knowingly collect data from children under 13. The app contains no user accounts and stores no personal information.

## Changes to This Policy

If we update this policy, the updated version will be committed to this repository and the "Last updated" date above will change.

## Contact

Questions? Open an issue at [github.com/lfmundim/WaterLogger](https://github.com/lfmundim/WaterLogger).
