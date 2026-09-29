import 'package:flutter_test/flutter_test.dart';
import 'package:course_attendance_manager/main.dart';

void main() {
  testWidgets('Course Attendance Manager loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CourseAttendanceManager(),
    );

    expect(find.byType(CourseAttendanceManager), findsOneWidget);
  });
}