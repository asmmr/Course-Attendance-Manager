Course Manager - Final Settings/Backup Integration

Files included:
- lib/main.dart
- lib/services/google_drive_sync_service.dart
- pubspec.yaml

Integrated:
- Dashboard Settings button
- Profile page and profile photo
- Google Drive connection
- Attendance folder creation
- Initial full backup when Drive sync is enabled
- Background course backup after course/student/attendance/assessment/marks/conversion changes
- Google Drive restore with duplicate-aware merge
- Profile backup and profile restore
- Assessment, marks, and conversion data included in course backups
- Local data remains the primary/source-of-truth storage

Before building:
1. Replace your existing lib/main.dart with the included main.dart.
2. Replace lib/services/google_drive_sync_service.dart with the included service.
3. Keep your existing database/database_helper.dart and models/course.dart.
4. Run: flutter pub get
5. Build Android normally.
6. Build iOS through Codemagic.

Important:
The project must retain the Google Sign-In configuration required by the existing Google Drive service.
