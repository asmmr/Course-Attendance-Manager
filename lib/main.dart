import 'dart:typed_data';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';

import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/google_drive_sync_service.dart';

import 'database/database_helper.dart';
import 'models/course.dart';

void main() {
  //WidgetsFlutterBinding.ensureInitialized();

  runApp(const CourseAttendanceManager());
}

class CourseAttendanceManager extends StatelessWidget {
  const CourseAttendanceManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Course Attendance Manager PRO",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  int? selectedCourseId;

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  final dashboardKey = GlobalKey<_DashboardState>();
  final courseKey = GlobalKey<_CoursePageState>();
  final studentKey = GlobalKey<_StudentPageState>();
  final marksKey = GlobalKey<_MarksPageState>();

  void goTo(int index) {
    setState(() {
      currentIndex = index;
    });

    // Refresh the relevant page whenever it becomes visible so the
    // dashboard and course cards always reflect the latest database data.
    if (index == 0) {
      dashboardKey.currentState?.loadDashboard();
    } else if (index == 1) {
      courseKey.currentState?.loadCourses();
    } else if (index == 2) {
      studentKey.currentState?.loadData();
    } else if (index == 4) {
      marksKey.currentState?.loadData();
    }
  }

  void openCourseStudents(Course course) {
    selectedCourseId = course.id;
    goTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(
        key: dashboardKey,
        onCourse: () => goTo(1),
        onStudent: () => goTo(2),
        onAttendance: () => goTo(3),
        onReport: () => goTo(5),
        onMarks: () => goTo(4),
        onSettings: () => _openSettings(context),
      ),
      CoursePage(
        key: courseKey,
        onCourseStudents: openCourseStudents,
      ),
      StudentPage(
        key: studentKey,
        initialCourseId: selectedCourseId,
      ),
      const AttendancePage(),
      MarksPage(key: marksKey),
      const ReportPage(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
            )
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: "Course",
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: "Student",
            ),
            NavigationDestination(
              icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle),
              label: "Attend",
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: "Marks",
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: "Report",
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileData {
  const ProfileData({
    this.name = '',
    this.institution = '',
    this.department = '',
    this.email = '',
    this.phone = '',
    this.photoPath = '',
  });

  final String name;
  final String institution;
  final String department;
  final String email;
  final String phone;
  final String photoPath;
}

class ProfileStore {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  final ValueNotifier<ProfileData> notifier =
      ValueNotifier<ProfileData>(const ProfileData());

  Future<ProfileData> load() async {
    final prefs = await SharedPreferences.getInstance();

    final profile = ProfileData(
      name: prefs.getString('profile_name') ?? '',
      institution: prefs.getString('profile_institution') ?? '',
      department: prefs.getString('profile_department') ?? '',
      email: prefs.getString('profile_email') ?? '',
      phone: prefs.getString('profile_phone') ?? '',
      photoPath: prefs.getString('profile_photo_path') ?? '',
    );

    notifier.value = profile;
    return profile;
  }

  Future<void> save(ProfileData profile) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('profile_name', profile.name);
    await prefs.setString('profile_institution', profile.institution);
    await prefs.setString('profile_department', profile.department);
    await prefs.setString('profile_email', profile.email);
    await prefs.setString('profile_phone', profile.phone);
    await prefs.setString('profile_photo_path', profile.photoPath);

    notifier.value = profile;
  }
}

class _DashboardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffDCEBFA)
      ..strokeWidth = .65;

    const gap = 28.0;

    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.path,
    required this.size,
  });

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = path.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xffC8E0FF),
          width: 2,
        ),
        color: const Color(0xffE8F3FF),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: Color(0xff1976D2),
                  size: 25,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                color: Color(0xff1976D2),
                size: 25,
              ),
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({
    super.key,
    this.onSettings,
    this.onCourse,
    this.onStudent,
    this.onAttendance,
    this.onReport,
    this.onMarks,
  });

  final VoidCallback? onSettings;
  final VoidCallback? onCourse;
  final VoidCallback? onStudent;
  final VoidCallback? onAttendance;
  final VoidCallback? onReport;
  final VoidCallback? onMarks;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  static const Color primary = Color(0xff0B6EDC);
  static const Color dark = Color(0xff14213D);
  static const Color background = Color(0xffF5F9FF);

  bool loading = true;
  int courseCount = 0;
  int studentCount = 0;
  int sessionCount = 0;
  int presentCount = 0;
  int attendanceTotal = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final courses = await DatabaseHelper.instance.getCourses();
      int students = 0;
      int sessions = 0;
      int present = 0;
      int total = 0;
      final sessionDates = <String>{};

      for (final course in courses) {
        if (course.id == null) continue;

        final courseStudents =
            await DatabaseHelper.instance.getStudents(course.id!);
        final records =
            await DatabaseHelper.instance.getAttendance(course.id!);

        students += courseStudents.length;
        total += records.length;

        for (final record in records) {
          final status = record['status']?.toString().trim().toLowerCase();
          final isPresent = status == 'present' ||
              status == 'p' ||
              status == 'true' ||
              record['present'] == true;

          if (isPresent) present++;

          final date = record['date']?.toString().trim();
          if (date != null && date.isNotEmpty) {
            sessionDates.add('${course.id}:$date');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        courseCount = courses.length;
        studentCount = students;
        sessionCount = sessionDates.length;
        presentCount = present;
        attendanceTotal = total;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load dashboard data: $e')),
      );
    }
  }

  double get attendancePercentage =>
      attendanceTotal == 0 ? 0 : (presentCount / attendanceTotal) * 100;

  String get attendanceText => '${attendancePercentage.round()}%';

  Widget _statCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffC8E0FF), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100B6EDC),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xffE8F3FF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: primary, size: 23),
                  ),
                  const Spacer(),
                  Icon(icon, color: const Color(0xff9ABBE2), size: 19),
                ],
              ),
              const SizedBox(height: 11),
              loading
                  ? const SizedBox(
                      height: 27,
                      width: 27,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 27,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
              const SizedBox(height: 5),
              Text(title,
                  style: const TextStyle(
                      color: dark, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xff718096),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceOverview() {
    final value = attendancePercentage / 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0B6EDC), Color(0xff1488E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x250B6EDC), blurRadius: 22, offset: Offset(0, 9)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.fact_check_rounded,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance Overview',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Keep track of classroom participation',
                        style: TextStyle(color: Color(0xffDCEEFF), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.insights_rounded, color: Color(0xffBFE0FF)),
            ],
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              Expanded(
                child: Text(
                  loading ? '...' : attendanceText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: .18)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: Color(0xffD7F8E7), size: 17),
                    SizedBox(width: 5),
                    Text('Overall Attendance',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: loading ? 0 : value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0x35FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xffC8E0FF)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xffEAF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primary, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: dark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xff718096), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: Color(0xff7EA9D7)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DashboardGridPainter())),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: dark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: Colors.white, size: 27),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('COURSE MANAGER',
                                  style: TextStyle(
                                      color: primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1)),
                              SizedBox(height: 2),
                              Text('Academic Assistant',
                                  style: TextStyle(
                                      color: dark,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        ValueListenableBuilder<ProfileData>(
                          valueListenable: ProfileStore.instance.notifier,
                          builder: (context, profile, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: widget.onSettings,
                                child: _ProfileAvatar(path: profile.photoPath, size: 46),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: widget.onSettings,
                                borderRadius: BorderRadius.circular(15),
                                child: Ink(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: const Color(0xffC8E0FF))),
                                  child: const Icon(Icons.settings_outlined,
                                      color: dark, size: 21),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 21),
                    const SizedBox(height: 8),
                    const Text('At a Glance',
                        style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    const Text('Your academic workspace',
                        style: TextStyle(color: Color(0xff718096), fontSize: 12)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 11,
                      mainAxisSpacing: 11,
                      childAspectRatio: 1.03,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _statCard(value: '$courseCount', title: 'Courses', subtitle: 'Active courses', icon: Icons.menu_book_rounded, onTap: widget.onCourse),
                        _statCard(value: '$studentCount', title: 'Students', subtitle: 'Across all courses', icon: Icons.people_alt_rounded, onTap: widget.onStudent),
                        _statCard(value: '$sessionCount', title: 'Sessions', subtitle: 'Attendance records', icon: Icons.calendar_month_rounded, onTap: widget.onAttendance),
                        _statCard(value: attendanceText, title: 'Attendance', subtitle: 'Overall rate', icon: Icons.percent_rounded, onTap: widget.onReport),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text('Quick Actions',
                        style: TextStyle(color: dark, fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    const Text('Start your next task',
                        style: TextStyle(color: Color(0xff718096), fontSize: 12)),
                    const SizedBox(height: 12),
                    _quickAction(title: 'Add Course', subtitle: 'Create a new course', icon: Icons.add_box_rounded, onTap: widget.onCourse),
                    const SizedBox(height: 9),
                    _quickAction(title: 'Manage Students', subtitle: 'Add or update student records', icon: Icons.person_add_alt_1_rounded, onTap: widget.onStudent),
                    const SizedBox(height: 9),
                    _quickAction(title: 'Take Attendance', subtitle: "Record today's attendance", icon: Icons.fact_check_rounded, onTap: widget.onAttendance),
                    const SizedBox(height: 9),
                    _quickAction(title: 'Enter Marks', subtitle: 'Manage course assessments', icon: Icons.edit_note_rounded, onTap: widget.onMarks),
                    const SizedBox(height: 9),
                    _quickAction(title: 'View Reports', subtitle: 'Review attendance analytics', icon: Icons.analytics_rounded, onTap: widget.onReport),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoursePage extends StatefulWidget {
  const CoursePage({
    super.key,
    this.onCourseStudents,
  });

  final ValueChanged<Course>? onCourseStudents;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  List<Course> courses = [];
  final Map<int, int> studentCounts = {};
  bool loadingCourses = true;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    try {
      final data = await DatabaseHelper.instance.getCourses();
      final counts = <int, int>{};

      for (final course in data) {
        if (course.id == null) continue;
        final students =
            await DatabaseHelper.instance.getStudents(course.id!);
        counts[course.id!] = students.length;
      }

      if (!mounted) return;

      setState(() {
        courses = data;
        studentCounts
          ..clear()
          ..addAll(counts);
        loadingCourses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingCourses = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load courses: $e')),
      );
    }
  }

  void addCourseDialog() {
    _showCourseEditor();
  }

  void editCourseDialog(Course course) {
    _showCourseEditor(course: course);
  }

  void _showCourseEditor({Course? course}) {
    final isEditing = course != null;

    final codeController = TextEditingController(
      text: course?.code ?? '',
    );
    final nameController = TextEditingController(
      text: course?.name ?? '',
    );
    final semesterController = TextEditingController(
      text: course?.semester ?? '',
    );
    final sectionController = TextEditingController(
      text: course?.section ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Text(
            isEditing ? "Edit Course" : "Add New Course",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "Course Code",
                    prefixIcon: Icon(Icons.book),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Course Name",
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: semesterController,
                  decoration: const InputDecoration(
                    labelText: "Semester",
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sectionController,
                  decoration: const InputDecoration(
                    labelText: "Section",
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final name = nameController.text.trim();
                final semester = semesterController.text.trim();
                final section = sectionController.text.trim();

                if (code.isEmpty ||
                    name.isEmpty ||
                    semester.isEmpty ||
                    section.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill in Course Code, Course Name, Semester and Section.',
                      ),
                    ),
                  );
                  return;
                }

                // Do not allow the exact same course offering twice.
                // During editing, ignore the course currently being edited.
                final duplicate = courses.any(
                  (existing) =>
                      existing.id != course?.id &&
                      existing.code.trim().toLowerCase() ==
                          code.toLowerCase() &&
                      existing.name.trim().toLowerCase() ==
                          name.toLowerCase() &&
                      existing.semester.trim().toLowerCase() ==
                          semester.toLowerCase() &&
                      existing.section.trim().toLowerCase() ==
                          section.toLowerCase(),
                );

                if (duplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This course offering already exists.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  if (isEditing) {
                    // Keep the original ID so existing students and
                    // attendance records remain linked to this course.
                    final updatedCourse = Course(
                      id: course!.id,
                      code: code,
                      name: name,
                      semester: semester,
                      section: section,
                      createdAt: course.createdAt,
                    );

                    final result = await DatabaseHelper.instance
                        .updateCourse(updatedCourse);

                    if (result == 0) {
                      throw Exception('Course could not be updated.');
                    }
                  } else {
                    final newCourse = Course(
                      code: code,
                      name: name,
                      semester: semester,
                      section: section,
                    );

                    final result = await DatabaseHelper.instance
                        .insertCourse(newCourse);

                    if (result == 0) {
                      throw Exception('Course could not be saved.');
                    }
                  }

                  if (!mounted) return;

                  Navigator.of(dialogContext).pop();
                  await loadCourses();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Course updated successfully.'
                            : 'Course added successfully.',
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Could not update course: $e'
                            : 'Could not save course: $e',
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(isEditing ? "Update" : "Save"),
            ),
          ],
        );
      },
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        codeController.dispose();
        nameController.dispose();
        semesterController.dispose();
        sectionController.dispose();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff2563EB),
                  Color(0xff7C3AED),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Courses 📚",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Manage your courses",
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: addCourseDialog,
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: loadingCourses
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : courses.isEmpty
                    ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "No courses added",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: addCourseDialog,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Course"),
                      )
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];

                      final count =
                          course.id == null ? 0 : (studentCounts[course.id!] ?? 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: .2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: .12),
                              blurRadius: 15,
                            )
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              if (widget.onCourseStudents != null) {
                                widget.onCourseStudents!(course);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        Colors.blue.withValues(alpha: .15),
                                    child: const Icon(
                                      Icons.book,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course.code,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          course.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${course.semester} | ${course.section}",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 9),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xffEAF4FF),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$count Students',
                                            style: const TextStyle(
                                              color: Color(0xff2563EB),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 17,
                                    color: Color(0xff7EA9D7),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit course',
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Color(0xff2563EB),
                                    ),
                                    onPressed: () {
                                      editCourseDialog(course);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete course',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await DatabaseHelper.instance
                                          .deleteCourse(course.id!);
                                      await loadCourses();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

class _StudentIdentity extends StatelessWidget {
  const _StudentIdentity({
    required this.studentId,
    required this.name,
    this.idFontSize = 16,
    this.nameFontSize = 11,
    this.idColor = const Color(0xff1D4ED8),
    this.nameColor = const Color(0xff334155),
  });

  final String studentId;
  final String name;
  final double idFontSize;
  final double nameFontSize;
  final Color idColor;
  final Color nameColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          studentId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            color: idColor,
            fontSize: idFontSize,
            fontWeight: FontWeight.w900,
            height: .98,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            color: nameColor,
            fontSize: nameFontSize,
            fontWeight: FontWeight.w600,
            height: 1.02,
          ),
        ),
      ],
    );
  }
}

class StudentPage extends StatefulWidget {
  const StudentPage({
    super.key,
    this.initialCourseId,
  });

  final int? initialCourseId;

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  List<Course> courses = [];
  List<Map<String, dynamic>> students = [];

  Course? selectedCourse;

  bool loading = true;
  bool bangla = false;
  bool isUploading = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void didUpdateWidget(covariant StudentPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialCourseId != widget.initialCourseId) {
      loadData();
    }
  }

  // ============================================================
  // LANGUAGE
  // ============================================================

  String t(String english, String banglaText) {
    return bangla ? banglaText : english;
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> loadData() async {
    try {
      setState(() {
        loading = true;
      });

      final data = await DatabaseHelper.instance.getCourses();

      if (!mounted) return;

      setState(() {
        courses = data;

        if (courses.isEmpty) {
          selectedCourse = null;
        } else if (widget.initialCourseId != null) {
          try {
            selectedCourse = courses.firstWhere(
              (course) => course.id == widget.initialCourseId,
            );
          } catch (_) {
            selectedCourse = courses.first;
          }
        } else if (selectedCourse != null) {
          final oldId = selectedCourse!.id;

          try {
            selectedCourse = courses.firstWhere(
              (course) => course.id == oldId,
            );
          } catch (_) {
            selectedCourse = courses.first;
          }
        } else {
          selectedCourse = courses.first;
        }

        loading = false;
      });

      await loadStudents();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        "${t("Failed to load courses", "কোর্স লোড করা যায়নি")}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // LOAD STUDENTS
  // ============================================================

  Future<void> loadStudents() async {
    if (selectedCourse == null || selectedCourse!.id == null) {
      if (mounted) {
        setState(() {
          students = [];
        });
      }
      return;
    }

    try {
      final data = await DatabaseHelper.instance.getStudents(
        selectedCourse!.id!,
      );

      // Keep every student list in ascending roll/ID order.
      data.sort((a, b) {
        final aText = a['student_id']?.toString().trim() ?? '';
        final bText = b['student_id']?.toString().trim() ?? '';
        final aNumber = int.tryParse(aText);
        final bNumber = int.tryParse(bText);
        if (aNumber != null && bNumber != null) {
          return aNumber.compareTo(bNumber);
        }
        return aText.toLowerCase().compareTo(bText.toLowerCase());
      });

      if (!mounted) return;

      setState(() {
        students = data;
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "${t("Failed to load students", "শিক্ষার্থী লোড করা যায়নি")}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // ADD SINGLE STUDENT
  // ============================================================

  void showAddStudentDialog() {
    if (selectedCourse == null || selectedCourse!.id == null) {
      showMessage(
        t(
          "Please select a course first.",
          "প্রথমে একটি কোর্স নির্বাচন করুন।",
        ),
        isError: true,
      );
      return;
    }

    final idController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            t(
              "Add Student",
              "শিক্ষার্থী যোগ করুন",
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: InputDecoration(
                  labelText: t(
                    "Student ID",
                    "শিক্ষার্থী আইডি",
                  ),
                  hintText: "e.g. 2026001",
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: t(
                    "Student Name",
                    "শিক্ষার্থীর নাম",
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                t("Cancel", "বাতিল"),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(
                t("Save", "সংরক্ষণ"),
              ),
              onPressed: () async {
                final studentId = idController.text.trim();

                final studentName = nameController.text.trim();

                if (studentId.isEmpty || studentName.isEmpty) {
                  showMessage(
                    t(
                      "Please enter Student ID and Name.",
                      "শিক্ষার্থী আইডি এবং নাম দিন।",
                    ),
                    isError: true,
                  );
                  return;
                }

                final duplicate = students.any(
                  (student) =>
                      student['student_id']?.toString().trim().toLowerCase() ==
                      studentId.toLowerCase(),
                );

                if (duplicate) {
                  showMessage(
                    t(
                      "This Student ID already exists.",
                      "এই শিক্ষার্থী আইডি ইতোমধ্যে রয়েছে।",
                    ),
                    isError: true,
                  );
                  return;
                }

                try {
                  await DatabaseHelper.instance.insertStudent({
                    'student_id': studentId,
                    'name': studentName,
                    'course_id': selectedCourse!.id!,
                  });

                  if (!mounted) return;

                  Navigator.pop(dialogContext);

                  await loadStudents();

                  showMessage(
                    t(
                      "Student added successfully.",
                      "শিক্ষার্থী সফলভাবে যোগ হয়েছে।",
                    ),
                  );
                } catch (e) {
                  showMessage(
                    "${t("Failed to add student", "শিক্ষার্থী যোগ করা যায়নি")}: $e",
                    isError: true,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // EXCEL CELL TEXT
  // ============================================================

  String cellToText(Data? cell) {
    if (cell == null || cell.value == null) {
      return '';
    }

    final value = cell.value;

    if (value is TextCellValue) {
      return value.value.text?.trim() ?? '';
    }

    if (value is IntCellValue) {
      return value.value.toString();
    }

    if (value is DoubleCellValue) {
      return value.value.toString();
    }

    if (value is BoolCellValue) {
      return value.value.toString();
    }

    if (value is DateCellValue) {
      return value.asDateTimeLocal().toString();
    }

    return value.toString().trim();
  }

  // ============================================================
  // NORMALIZE HEADER
  // ============================================================

  String normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(
          RegExp(r'[\s_\-/\\().]+'),
          '',
        );
  }

  // ============================================================
  // ID HEADER
  // ============================================================

  bool isIdHeader(String value) {
    final h = normalizeHeader(value);

    const headers = [
      'studentid',
      'id',
      'studentno',
      'studentnumber',
      'studentroll',
      'roll',
      'rollno',
      'rollnumber',
      'registration',
      'registrationno',
      'regno',
      'regnumber',
      'শিক্ষার্থীআইডি',
      'আইডি',
      'রোল',
      'রোলনং',
      'শিক্ষার্থীনম্বর',
    ];

    return headers.contains(h);
  }

  // ============================================================
  // NAME HEADER
  // ============================================================

  bool isNameHeader(String value) {
    final h = normalizeHeader(value);

    const headers = [
      'studentname',
      'name',
      'fullname',
      'studentfullname',
      'শিক্ষার্থীরনাম',
      'নাম',
    ];

    return headers.contains(h);
  }

  // ============================================================
  // FIND EXCEL HEADER
  // ============================================================

  Map<String, int>? findHeaderColumns(
    Sheet sheet,
  ) {
    final maxRows = sheet.rows.length > 10 ? 10 : sheet.rows.length;

    for (int rowIndex = 0; rowIndex < maxRows; rowIndex++) {
      final row = sheet.rows[rowIndex];

      int idColumn = -1;
      int nameColumn = -1;

      for (int i = 0; i < row.length; i++) {
        final text = cellToText(row[i]);

        if (text.isEmpty) continue;

        if (isIdHeader(text)) {
          idColumn = i;
        }

        if (isNameHeader(text)) {
          nameColumn = i;
        }
      }

      if (idColumn != -1 && nameColumn != -1) {
        return {
          'row': rowIndex,
          'id': idColumn,
          'name': nameColumn,
        };
      }
    }

    return null;
  }

  // ============================================================
  // EXCEL UPLOAD
  // ============================================================

  Future<void> uploadStudentsFromExcel() async {
    if (selectedCourse == null || selectedCourse!.id == null) {
      showMessage(
        t(
          "Please select a course first.",
          "প্রথমে একটি কোর্স নির্বাচন করুন।",
        ),
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        isUploading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'xlsx',
          'xls',
        ],
        withData: true,
      );

      if (result == null) {
        setState(() {
          isUploading = false;
        });
        return;
      }

      final Uint8List? bytes = result.files.single.bytes;

      if (bytes == null) {
        throw Exception(
          t(
            "Could not read the Excel file.",
            "Excel ফাইলটি পড়া যাচ্ছে না।",
          ),
        );
      }

      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception(
          t(
            "No worksheet found.",
            "কোনো worksheet পাওয়া যায়নি।",
          ),
        );
      }

      final sheetName = excel.tables.keys.first;

      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception(
          t(
            "The Excel sheet is empty.",
            "Excel sheet খালি।",
          ),
        );
      }

      final headerInfo = findHeaderColumns(sheet);

      if (headerInfo == null) {
        throw Exception(
          t(
            "Required columns were not found.\n\n"
                "Use: Student ID and Student Name.",
            "প্রয়োজনীয় column পাওয়া যায়নি।\n\n"
                "ব্যবহার করুন: Student ID এবং Student Name।",
          ),
        );
      }

      final headerRow = headerInfo['row']!;

      final idColumn = headerInfo['id']!;

      final nameColumn = headerInfo['name']!;

      final existingStudents = await DatabaseHelper.instance.getStudents(
        selectedCourse!.id!,
      );

      final Set<String> existingIds = {};

      for (final student in existingStudents) {
        final id = student['student_id']?.toString().trim().toLowerCase() ?? '';

        if (id.isNotEmpty) {
          existingIds.add(id);
        }
      }

      int added = 0;
      int skipped = 0;
      int invalid = 0;

      for (int rowIndex = headerRow + 1;
          rowIndex < sheet.rows.length;
          rowIndex++) {
        final row = sheet.rows[rowIndex];

        if (row.isEmpty) continue;

        if (idColumn >= row.length || nameColumn >= row.length) {
          invalid++;
          continue;
        }

        final studentId = cellToText(row[idColumn]);

        final studentName = cellToText(row[nameColumn]);

        if (studentId.isEmpty && studentName.isEmpty) {
          continue;
        }

        if (studentId.isEmpty || studentName.isEmpty) {
          invalid++;
          continue;
        }

        final normalizedId = studentId.trim().toLowerCase();

        if (existingIds.contains(
          normalizedId,
        )) {
          skipped++;
          continue;
        }

        await DatabaseHelper.instance.insertStudent({
          'student_id': studentId.trim(),
          'name': studentName.trim(),
          'course_id': selectedCourse!.id!,
        });

        existingIds.add(normalizedId);

        added++;
      }

      await loadStudents();

      if (!mounted) return;

      setState(() {
        isUploading = false;
      });

      showUploadResult(
        added,
        skipped,
        invalid,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isUploading = false;
      });

      showMessage(
        "${t("Upload failed", "আপলোড ব্যর্থ")}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // UPLOAD RESULT
  // ============================================================

  void showUploadResult(
    int added,
    int skipped,
    int invalid,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            t(
              "Upload Complete",
              "আপলোড সম্পন্ন",
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              resultRow(
                t("Added", "যোগ হয়েছে"),
                added,
                Colors.green,
              ),
              const SizedBox(height: 10),
              resultRow(
                t("Skipped", "বাদ দেওয়া হয়েছে"),
                skipped,
                Colors.orange,
              ),
              const SizedBox(height: 10),
              resultRow(
                t("Invalid", "ত্রুটিপূর্ণ"),
                invalid,
                Colors.red,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                t("OK", "ঠিক আছে"),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // RESULT ROW
  // ============================================================

  Widget resultRow(
    String title,
    int value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DELETE STUDENT
  // ============================================================

  Future<void> deleteStudent(
    Map<String, dynamic> student,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            t(
              "Delete Student?",
              "শিক্ষার্থী মুছে ফেলবেন?",
            ),
          ),
          content: _StudentIdentity(
            studentId: student['student_id']?.toString() ?? '',
            name: student['name']?.toString() ?? '',
            idFontSize: 18,
            nameFontSize: 12,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                t("Cancel", "বাতিল"),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(
                t("Delete", "মুছে ফেলুন"),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final id = student['id'];

    if (id == null) {
      showMessage(
        t(
          "Invalid student ID.",
          "শিক্ষার্থীর ID সঠিক নয়।",
        ),
        isError: true,
      );
      return;
    }

    try {
      await DatabaseHelper.instance.deleteStudent(id);

      await loadStudents();

      showMessage(
        t(
          "Student deleted successfully.",
          "শিক্ষার্থী সফলভাবে মুছে ফেলা হয়েছে।",
        ),
      );
    } catch (e) {
      showMessage(
        "${t(
          "Failed to delete student",
          "শিক্ষার্থী মুছে ফেলা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // COURSE SELECTOR
  // ============================================================

  Widget courseSelector() {
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xffDCE3F0),
          ),
        ),
        child: Text(
          t(
            "No courses available. Please add a course first.",
            "কোনো কোর্স নেই। প্রথমে একটি কোর্স যোগ করুন।",
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffDCE3F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Course>(
          value: selectedCourse,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xff2563EB),
          ),
          items: courses.map(
            (course) {
              return DropdownMenuItem<Course>(
                value: course,
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book,
                      color: Color(0xff2563EB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${course.code} • "
                        "${course.name}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
          onChanged: (course) async {
            if (course == null) return;

            setState(() {
              selectedCourse = course;
              students = [];
            });

            await loadStudents();
          },
        ),
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget studentCard(
    Map<String, dynamic> student,
    int index,
  ) {
    final studentName = student['name']?.toString() ?? '';

    final studentId = student['student_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffE1E7F0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xffE8F1FF),
            child: Text(
              "${index + 1}",
              style: const TextStyle(
                color: Color(0xff2563EB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentIdentity(
                  studentId: studentId,
                  name: studentName,
                  idFontSize: 16,
                  nameFontSize: 11,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t("Delete", "মুছে ফেলুন"),
            onPressed: () {
              deleteStudent(student);
            },
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xffE1E7F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xffEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 50,
              color: Color(0xff2563EB),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            t(
              "No students added",
              "কোনো শিক্ষার্থী যোগ করা হয়নি",
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(
              "Click + to add a student or upload an Excel file.",
              "+ চিহ্ন ব্যবহার করে শিক্ষার্থী যোগ করুন অথবা Excel ফাইল আপলোড করুন।",
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                16,
                22,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xff2563EB),
                    Color(0xff7C3AED),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  // TITLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            "Students 👥",
                            "শিক্ষার্থীরা 👥",
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selectedCourse == null
                              ? t(
                                  "Manage your students",
                                  "শিক্ষার্থী ব্যবস্থাপনা",
                                )
                              : selectedCourse!.code,
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // + BUTTON
                  InkWell(
                    onTap: showAddStudentDialog,
                    borderRadius: BorderRadius.circular(
                      15,
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.20,
                        ),
                        borderRadius: BorderRadius.circular(
                          15,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // LANGUAGE
                  InkWell(
                    onTap: () {
                      setState(() {
                        bangla = !bangla;
                      });
                    },
                    borderRadius: BorderRadius.circular(
                      15,
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(
                          15,
                        ),
                      ),
                      child: Text(
                        bangla ? "EN" : "বাং",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : RefreshIndicator(
                      onRefresh: loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          18,
                          18,
                          30,
                        ),
                        children: [
                          // COURSE
                          courseSelector(),

                          const SizedBox(
                            height: 16,
                          ),

                          // EXCEL
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xff2563EB,
                                ),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              icon: isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.upload_file,
                                    ),
                              label: Text(
                                isUploading
                                    ? t(
                                        "Uploading...",
                                        "আপলোড হচ্ছে...",
                                      )
                                    : t(
                                        "Upload Students from Excel",
                                        "Excel থেকে শিক্ষার্থী আপলোড",
                                      ),
                              ),
                              onPressed:
                                  isUploading ? null : uploadStudentsFromExcel,
                            ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          // COURSE INFO
                          Container(
                            padding: const EdgeInsets.all(
                              18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                              border: Border.all(
                                color: const Color(
                                  0xffE1E7F0,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xffE8F1FF,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      14,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.people_alt,
                                    color: Color(
                                      0xff2563EB,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedCourse == null
                                            ? t(
                                                "No Course",
                                                "কোনো কোর্স নেই",
                                              )
                                            : selectedCourse!.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                      if (selectedCourse != null)
                                        Text(
                                          selectedCourse!.name,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      students.length.toString(),
                                      style: const TextStyle(
                                        color: Color(
                                          0xff2563EB,
                                        ),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      t(
                                        "Students",
                                        "জন",
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // STUDENT LIST
                          Text(
                            t(
                              "Student List",
                              "শিক্ষার্থী তালিকা",
                            ),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          if (students.isEmpty)
                            emptyState()
                          else
                            ...List.generate(
                              students.length,
                              (index) {
                                return studentCard(
                                  students[index],
                                  index,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Course> courses = [];

  List<Map<String, dynamic>> students = [];

  Course? selectedCourse;

  DateTime selectedDate = DateTime.now();

  bool loading = true;

  bool saving = false;

  bool bangla = false;

  // student database ID -> Present / Absent
  final Map<int, bool> attendance = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ============================================================
  // LANGUAGE
  // ============================================================

  String t(String english, String banglaText) {
    return bangla ? banglaText : english;
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> loadData() async {
    try {
      setState(() {
        loading = true;
      });

      final data = await DatabaseHelper.instance.getCourses();

      if (!mounted) return;

      setState(() {
        courses = data;

        if (courses.isEmpty) {
          selectedCourse = null;
        } else {
          if (selectedCourse != null) {
            final oldCourseId = selectedCourse!.id;

            try {
              selectedCourse = courses.firstWhere(
                (course) => course.id == oldCourseId,
              );
            } catch (_) {
              selectedCourse = courses.first;
            }
          } else {
            selectedCourse = courses.first;
          }
        }

        loading = false;
      });

      await loadStudents();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        "${t(
          "Failed to load courses",
          "কোর্স লোড করা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // LOAD STUDENTS
  // ============================================================

  Future<void> loadStudents() async {
    if (selectedCourse == null || selectedCourse!.id == null) {
      if (!mounted) return;

      setState(() {
        students = [];
        attendance.clear();
      });

      return;
    }

    try {
      final data = await DatabaseHelper.instance.getStudents(
        selectedCourse!.id!,
      );

      if (!mounted) return;

      setState(() {
        students = data;

        attendance.clear();

        // New date is Present by default
        for (final student in students) {
          final id = student['id'];

          if (id is int) {
            attendance[id] = true;
          }
        }
      });

      // Load saved attendance for selected date
      await loadAttendanceForSelectedDate();
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "${t(
          "Failed to load students",
          "শিক্ষার্থী লোড করা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // LOAD ATTENDANCE FOR SELECTED DATE
  // ============================================================

  Future<void> loadAttendanceForSelectedDate() async {
    if (selectedCourse == null || selectedCourse!.id == null) {
      return;
    }

    try {
      final records = await DatabaseHelper.instance.getAttendance(
        selectedCourse!.id!,
      );

      final dateString = _dateToString(selectedDate);

      final Map<int, bool> newAttendance = {};

      // --------------------------------------------------------
      // DEFAULT: EVERYONE PRESENT
      // --------------------------------------------------------

      for (final student in students) {
        final id = student['id'];

        if (id is int) {
          newAttendance[id] = true;
        }
      }

      // --------------------------------------------------------
      // APPLY SAVED ATTENDANCE
      // --------------------------------------------------------

      for (final record in records) {
        final recordDate = record['date']?.toString().trim() ?? '';

        if (recordDate != dateString) {
          continue;
        }

        final studentId = record['student_id'];

        if (studentId is int) {
          final status = record['status']?.toString().trim().toLowerCase();

          newAttendance[studentId] = status == 'present';
        }
      }

      if (!mounted) return;

      setState(() {
        attendance
          ..clear()
          ..addAll(newAttendance);
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "${t(
          "Failed to load attendance",
          "উপস্থিতির তথ্য লোড করা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });

    // Important:
    // Load attendance saved for the new date
    await loadAttendanceForSelectedDate();
  }

  // ============================================================
  // DATE TO STRING
  // ============================================================

  String _dateToString(DateTime date) {
    return "${date.year}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // DISPLAY DATE
  // ============================================================

  String get formattedDate {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    final month = months[selectedDate.month - 1];

    return "${selectedDate.day} "
        "$month "
        "${selectedDate.year}";
  }

  // ============================================================
  // TOGGLE ATTENDANCE
  // ============================================================

  void toggleAttendance(
    int studentId,
    bool value,
  ) {
    setState(() {
      attendance[studentId] = value;
    });
  }

  // ============================================================
  // PRESENT COUNT
  // ============================================================

  int get presentCount {
    return attendance.values.where((value) => value).length;
  }

  // ============================================================
  // ABSENT COUNT
  // ============================================================

  int get absentCount {
    return attendance.values.where((value) => !value).length;
  }

  // ============================================================
  // SAVE / OVERWRITE ATTENDANCE
  // ============================================================

  Future<void> saveAttendance() async {
    if (selectedCourse == null || selectedCourse!.id == null) {
      showMessage(
        t(
          "Please select a course.",
          "একটি কোর্স নির্বাচন করুন।",
        ),
        isError: true,
      );
      return;
    }

    if (students.isEmpty) {
      showMessage(
        t(
          "No students found.",
          "কোনো শিক্ষার্থী পাওয়া যায়নি।",
        ),
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        saving = true;
      });

      final dateString = _dateToString(selectedDate);

      // --------------------------------------------------------
      // SAVE EACH STUDENT
      // --------------------------------------------------------

      for (final student in students) {
        final studentId = student['id'];

        if (studentId is! int) {
          continue;
        }

        final isPresent = attendance[studentId] ?? true;

        await DatabaseHelper.instance.saveOrUpdateAttendance({
          'course_id': selectedCourse!.id!,
          'student_id': studentId,
          'date': dateString,
          'status': isPresent ? 'Present' : 'Absent',
        });
      }

      if (!mounted) return;

      setState(() {
        saving = false;
      });

      // Reload from database
      await loadAttendanceForSelectedDate();

      showMessage(
        t(
          "Attendance saved successfully.",
          "উপস্থিতি সফলভাবে সংরক্ষণ হয়েছে।",
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      showMessage(
        "${t(
          "Failed to save attendance",
          "উপস্থিতি সংরক্ষণ করা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // COURSE SELECTOR
  // ============================================================

  Widget courseSelector() {
    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          t(
            "No courses available.",
            "কোনো কোর্স পাওয়া যায়নি।",
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xffE1E7F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Course>(
          value: selectedCourse,
          isExpanded: true,
          items: courses.map(
            (course) {
              return DropdownMenuItem<Course>(
                value: course,
                child: Text(
                  "${course.code} • "
                  "${course.name}",
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ).toList(),
          onChanged: (Course? course) async {
            if (course == null) {
              return;
            }

            setState(() {
              selectedCourse = course;
              students = [];
              attendance.clear();
            });

            await loadStudents();
          },
        ),
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget studentCard(
    Map<String, dynamic> student,
    int index,
  ) {
    final databaseId = student['id'];

    final studentName = student['name']?.toString() ?? '';

    final studentId = student['student_id']?.toString() ?? '';

    final present = databaseId is int ? (attendance[databaseId] ?? true) : true;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: present
              ? Colors.green.withValues(alpha: .30)
              : Colors.red.withValues(alpha: .30),
        ),
      ),
      child: Row(
        children: [
          // ------------------------------------------------------
          // NUMBER / ICON
          // ------------------------------------------------------

          CircleAvatar(
            backgroundColor: present
                ? Colors.green.withValues(alpha: .15)
                : Colors.red.withValues(alpha: .15),
            child: Icon(
              Icons.person,
              color: present ? Colors.green : Colors.red,
            ),
          ),

          const SizedBox(
            width: 15,
          ),

          // ------------------------------------------------------
          // NAME + ID
          // ------------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentIdentity(
                  studentId: studentId,
                  name: studentName,
                  idFontSize: 16,
                  nameFontSize: 11,
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // PRESENT / ABSENT SWITCH
          // ------------------------------------------------------

          Switch(
            value: present,
            activeThumbColor: Colors.green,
            onChanged: databaseId is int
                ? (value) {
                    toggleAttendance(
                      databaseId,
                      value,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget summaryCard(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(
            width: 10,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Container(
              padding: const EdgeInsets.fromLTRB(
                25,
                25,
                20,
                30,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xffF59E0B),
                    Color(0xffF97316),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            "Attendance ✓",
                            "উপস্থিতি ✓",
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          selectedCourse == null
                              ? t(
                                  "Mark today's attendance",
                                  "আজকের উপস্থিতি নিন",
                                )
                              : selectedCourse!.code,
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------------
                  // LANGUAGE
                  // ------------------------------------------------

                  InkWell(
                    onTap: () {
                      setState(() {
                        bangla = !bangla;
                      });
                    },
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: .18,
                        ),
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Text(
                        bangla ? "EN" : "বাং",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // BODY
            // ==================================================

            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : RefreshIndicator(
                      onRefresh: loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        children: [
                          // ======================================
                          // COURSE
                          // ======================================

                          Text(
                            t(
                              "Course",
                              "কোর্স",
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          courseSelector(),

                          const SizedBox(
                            height: 15,
                          ),

                          // ======================================
                          // DATE
                          // ======================================

                          InkWell(
                            onTap: selectDate,
                            borderRadius: BorderRadius.circular(
                              18,
                            ),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  18,
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.calendar_month,
                                  color: Colors.orange,
                                ),
                                title: Text(
                                  formattedDate,
                                ),
                                subtitle: Text(
                                  t(
                                    "Tap to change date",
                                    "তারিখ পরিবর্তন করতে চাপুন",
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.keyboard_arrow_down,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          // ======================================
                          // SUMMARY
                          // ======================================

                          Row(
                            children: [
                              Expanded(
                                child: summaryCard(
                                  t(
                                    "Present",
                                    "উপস্থিত",
                                  ),
                                  presentCount,
                                  Colors.green,
                                  Icons.check_circle,
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: summaryCard(
                                  t(
                                    "Absent",
                                    "অনুপস্থিত",
                                  ),
                                  absentCount,
                                  Colors.red,
                                  Icons.cancel,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // ======================================
                          // STUDENTS TITLE
                          // ======================================

                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t(
                                    "Students",
                                    "শিক্ষার্থীরা",
                                  ),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                "${students.length} "
                                "${t("students", "জন")}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ======================================
                          // STUDENT LIST
                          // ======================================

                          if (students.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(
                                35,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.people_outline,
                                    size: 55,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Text(
                                    t(
                                      "No students found.",
                                      "কোনো শিক্ষার্থী পাওয়া যায়নি।",
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...List.generate(
                              students.length,
                              (index) {
                                return studentCard(
                                  students[index],
                                  index,
                                );
                              },
                            ),

                          const SizedBox(
                            height: 20,
                          ),

                          // ======================================
                          // SAVE BUTTON
                          // ======================================

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                ),
                              ),
                              icon: saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.save,
                                    ),
                              label: Text(
                                saving
                                    ? t(
                                        "Saving...",
                                        "সংরক্ষণ হচ্ছে...",
                                      )
                                    : t(
                                        "SAVE ATTENDANCE",
                                        "উপস্থিতি সংরক্ষণ করুন",
                                      ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: saving ? null : saveAttendance,
                            ),
                          ),

                          const SizedBox(
                            height: 15,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  static const Color primary = Color(0xff2563EB);
  static const Color purple = Color(0xff7C3AED);
  static const Color background = Color(0xffF6F8FC);
  static const Color textDark = Color(0xff172033);

  List<Course> courses = [];
  Course? selectedCourse;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> assessments = [];
  Map<int, List<Map<String, dynamic>>> assessmentMarks = {};
  Map<String, TextEditingController> conversionControllers = {};
  TextEditingController attendanceConversionController = TextEditingController();

  bool loading = true;
  bool bangla = false;
  bool exportingPdf = false;
  bool exportingExcel = false;
  int reportTab = 0;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  @override
  void dispose() {
    for (final c in conversionControllers.values) {
      c.dispose();
    }
    attendanceConversionController.dispose();
    super.dispose();
  }

  String t(String english, String banglaText) =>
      bangla ? banglaText : english;

  String _formatNumber(num value) {
    final n = value.toDouble();
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  String percentageText(double value) => '${value.toStringAsFixed(1)}%';

  Color percentageColor(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> loadReport() async {
    if (mounted) setState(() => loading = true);
    try {
      final data = await DatabaseHelper.instance.getCourses();
      Course? course;
      if (data.isNotEmpty) {
        if (selectedCourse != null) {
          final matches = data.where((c) => c.id == selectedCourse!.id).toList();
          course = matches.isNotEmpty ? matches.first : data.first;
        } else {
          course = data.first;
        }
      }

      selectedCourse = course;
      courses = data;
      await loadCourseReport();

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMessage('Failed to load report: $e', isError: true);
      }
    }
  }

  Future<void> loadCourseReport() async {
    if (selectedCourse?.id == null) {
      if (mounted) {
        setState(() {
          students = [];
          attendanceRecords = [];
          assessments = [];
          assessmentMarks = {};
        });
      }
      return;
    }

    final courseId = selectedCourse!.id!;
    final studentData = await DatabaseHelper.instance.getStudents(courseId);
    final attendanceData =
        await DatabaseHelper.instance.getAttendance(courseId);
    final assessmentData =
        await DatabaseHelper.instance.getAssessments(courseId);

    final marksMap = <int, List<Map<String, dynamic>>>{};
    for (final assessment in assessmentData) {
      final id = int.tryParse(assessment['id'].toString());
      if (id != null) {
        marksMap[id] = await DatabaseHelper.instance.getMarks(id);
      }
    }

    final savedConversions =
        await DatabaseHelper.instance.getAssessmentConversions(courseId);

    final newControllers = <String, TextEditingController>{};
    for (final type in assessmentData
        .map((a) => a['type']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()) {
      final value = savedConversions[type];
      newControllers[type] = TextEditingController(
        text: value == null ? '' : _formatNumber(value),
      );
    }
    final newAttendanceController = TextEditingController(
      text: savedConversions['__attendance__'] == null
          ? ''
          : _formatNumber(savedConversions['__attendance__']!),
    );

    for (final c in conversionControllers.values) {
      c.dispose();
    }

    if (!mounted) return;
    setState(() {
      students = studentData;
      attendanceRecords = attendanceData;
      assessments = assessmentData;
      assessmentMarks = marksMap;
      conversionControllers = newControllers;
      attendanceConversionController.dispose();
      attendanceConversionController = newAttendanceController;
    });
  }

  Future<void> changeCourse(Course? course) async {
    if (course == null) return;
    setState(() {
      selectedCourse = course;
      loading = true;
    });
    await loadCourseReport();
    if (mounted) setState(() => loading = false);
  }

  bool isPresent(Map<String, dynamic> record) {
    final status = record['status'];
    if (status != null) {
      final value = status.toString().trim().toLowerCase();
      if (value == 'present' || value == 'p' || value == 'true') return true;
      if (value == 'absent' || value == 'a' || value == 'false') return false;
    }
    final value = record['present'];
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  int? studentDatabaseId(Map<String, dynamic> student) {
    final value = student['id'];
    if (value is int) return value;
    return value == null ? null : int.tryParse(value.toString());
  }

  int studentTotalClasses(int studentId) => attendanceRecords.where((r) =>
      r['student_id'] == studentId ||
      r['student_id']?.toString() == studentId.toString()).length;

  int studentPresentCount(int studentId) => attendanceRecords.where((r) {
        final same = r['student_id'] == studentId ||
            r['student_id']?.toString() == studentId.toString();
        return same && isPresent(r);
      }).length;

  int studentAbsentCount(int studentId) => attendanceRecords.where((r) {
        final same = r['student_id'] == studentId ||
            r['student_id']?.toString() == studentId.toString();
        return same && !isPresent(r);
      }).length;

  double studentPercentage(int studentId) {
    final total = studentTotalClasses(studentId);
    return total == 0 ? 0 : studentPresentCount(studentId) / total * 100;
  }

  int get overallPresent => attendanceRecords.where(isPresent).length;
  int get overallAbsent => attendanceRecords.where((r) => !isPresent(r)).length;

  int get totalClasses => attendanceRecords
      .map((r) => r['date']?.toString().trim() ?? '')
      .where((d) => d.isNotEmpty)
      .toSet()
      .length;

  double get overallPercentage {
    final total = overallPresent + overallAbsent;
    return total == 0 ? 0 : overallPresent / total * 100;
  }

  Widget courseSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xffD8E1EE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Course>(
          value: selectedCourse,
          isExpanded: true,
          items: courses.map((course) {
            return DropdownMenuItem<Course>(
              value: course,
              child: Text('${course.code} • ${course.name}',
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: changeCourse,
        ),
      ),
    );
  }

  Widget _tabButton(String title, IconData icon, int index) {
    final selected = reportTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => reportTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [primary, purple])
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.transparent : const Color(0xffD8E1EE),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? Colors.white : const Color(0xff64748B)),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                    color: selected ? Colors.white : textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2563EB), Color(0xff06B6D4)],
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          const Text('Overall Attendance',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(percentageText(overallPercentage),
              style: const TextStyle(color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryMetric('Present', overallPresent, Colors.white),
              _summaryMetric('Absent', overallAbsent, Colors.white),
              _summaryMetric('Classes', totalClasses, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(color: color, fontSize: 17,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(color: color.withValues(alpha: .85), fontSize: 9)),
      ],
    );
  }

  Widget _attendanceStudentCard(Map<String, dynamic> student) {
    final id = studentDatabaseId(student);
    if (id == null) return const SizedBox.shrink();
    final studentId = student['student_id']?.toString() ?? '';
    final name = student['name']?.toString() ?? '';
    final present = studentPresentCount(id);
    final absent = studentAbsentCount(id);
    final total = studentTotalClasses(id);
    final percentage = studentPercentage(id);
    final color = percentageColor(percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StudentIdentity(
                  studentId: studentId,
                  name: name,
                  idFontSize: 15,
                  nameFontSize: 10,
                ),
              ),
              Text(percentageText(percentage),
                  style: TextStyle(color: color, fontSize: 17,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 7,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: _summaryMetric('Present', present, Colors.green)),
              Expanded(child: _summaryMetric('Absent', absent, Colors.red)),
              Expanded(child: _summaryMetric('Total', total, primary)),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------- ASSESSMENT REPORT --------------------

  List<String> get conductedTypes {
    final result = <String>[];
    for (final a in assessments) {
      final id = int.tryParse(a['id'].toString());
      final type = a['type']?.toString().trim() ?? '';
      if (id == null || type.isEmpty) continue;
      if ((assessmentMarks[id] ?? []).isEmpty) continue;
      if (!result.any((e) => e.toLowerCase() == type.toLowerCase())) {
        result.add(type);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> _conductedForType(String type) {
    return assessments.where((a) {
      final id = int.tryParse(a['id'].toString());
      return id != null &&
          (assessmentMarks[id] ?? []).isNotEmpty &&
          a['type']?.toString().trim().toLowerCase() ==
              type.trim().toLowerCase();
    }).toList();
  }

  double _conversionFor(String type) =>
      double.tryParse(conversionControllers[type]?.text.trim() ?? '') ?? 0;

  bool _validateConversionsForReport() {
    if (totalClasses <= 0 && _conductedAssessments.isEmpty) {
      showMessage('No attendance or conducted assessment data found.', isError: true);
      return false;
    }

    if (totalClasses > 0) {
      final attendanceTo = double.tryParse(attendanceConversionController.text.trim()) ?? 0;
      if (attendanceTo <= 0) {
        showMessage('Enter a valid converted mark for Attendance.', isError: true);
        return false;
      }
    }

    for (final type in conductedTypes) {
      final value = _conversionFor(type);
      if (value <= 0) {
        showMessage('Enter a valid converted mark for $type.', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> saveConversions() async {
    if (selectedCourse?.id == null) return;
    final map = <String, double>{};
    if (totalClasses > 0) {
      final attendanceTo = double.tryParse(attendanceConversionController.text.trim()) ?? 0;
      if (attendanceTo <= 0) return;
      map['__attendance__'] = attendanceTo;
    }
    for (final type in conductedTypes) {
      final value = _conversionFor(type);
      if (value <= 0) {
        showMessage('Enter a valid converted mark for $type.',
            isError: true);
        return;
      }
      map[type] = value;
    }
    await DatabaseHelper.instance
        .saveAssessmentConversions(selectedCourse!.id!, map);
  }

  // Conversion is applied only while building the report. Raw marks remain
  // unchanged in the database. Each conducted assessment gets its own column,
  // while the conversion rule is shared by its assessment TYPE.
  double _rawMarkForAssessment(int assessmentId, int studentDbId) {
    final record = (assessmentMarks[assessmentId] ?? []).firstWhere(
      (m) =>
          m['student_id'] == studentDbId ||
          m['student_id']?.toString() == studentDbId.toString(),
      orElse: () => <String, dynamic>{},
    );
    return (record['marks'] as num?)?.toDouble() ?? 0;
  }

  double _convertedAssessmentMark(
      Map<String, dynamic> assessment, int studentDbId) {
    final assessmentId = int.tryParse(assessment['id'].toString());
    final outOf = (assessment['out_of'] as num?)?.toDouble() ?? 0;
    final type = assessment['type']?.toString().trim() ?? '';
    final convertedTo = _conversionFor(type);
    if (assessmentId == null || outOf <= 0 || convertedTo <= 0) return 0;

    final raw = _rawMarkForAssessment(assessmentId, studentDbId);
    return (raw / outOf) * convertedTo;
  }

  double _attendanceConvertedForStudent(int studentDbId) {
    final convertedTo = double.tryParse(attendanceConversionController.text.trim()) ?? 0;
    final total = studentTotalClasses(studentDbId);
    if (total <= 0 || convertedTo <= 0) return 0;
    return studentPresentCount(studentDbId) / total * convertedTo;
  }

  double _attendanceConvertedPossible() {
    if (totalClasses <= 0) return 0;
    return double.tryParse(attendanceConversionController.text.trim()) ?? 0;
  }

  double _totalConvertedPossible() => _attendanceConvertedPossible() + assessments
      .where((a) {
        final id = int.tryParse(a['id'].toString());
        return id != null && (assessmentMarks[id] ?? []).isNotEmpty;
      })
      .fold<double>(0, (sum, assessment) {
        final type = assessment['type']?.toString().trim() ?? '';
        return sum + _conversionFor(type);
      });

  double _totalConvertedForStudent(int studentDbId) =>
      _attendanceConvertedForStudent(studentDbId) +
      _conductedAssessments.fold<double>(0, (sum, assessment) =>
          sum + _convertedAssessmentMark(assessment, studentDbId));

  List<Map<String, dynamic>> get _conductedAssessments {
    return assessments.where((assessment) {
      final id = int.tryParse(assessment['id'].toString());
      return id != null && (assessmentMarks[id] ?? []).isNotEmpty;
    }).toList();
  }

  Widget _assessmentDistribution() {
    final types = conductedTypes;
    if (types.isEmpty && totalClasses <= 0) return _emptyAssessment();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xffDCE4EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assessment Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                  color: textDark)),
          const SizedBox(height: 3),
          const Text('Only conducted assessments are included.',
              style: TextStyle(fontSize: 9, color: Color(0xff64748B))),
          const SizedBox(height: 10),
          if (totalClasses > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xff059669).withValues(alpha: .055),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xff059669).withValues(alpha: .18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xff059669).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.fact_check_rounded, color: Color(0xff059669), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Attendance', style: TextStyle(color: Color(0xff059669), fontSize: 12, fontWeight: FontWeight.w900)),
                        Text('Calculated from classes held', style: TextStyle(fontSize: 9, color: Color(0xff64748B))),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 94,
                    child: TextField(
                      controller: attendanceConversionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        labelText: 'Converted to', suffixText: 'marks',
                        labelStyle: TextStyle(fontSize: 8), suffixStyle: TextStyle(fontSize: 8),
                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...types.map((type) {
            final color = _assessmentColor(type);
            final count = _conductedForType(type).length;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.assessment_rounded, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type,
                            style: TextStyle(color: color, fontSize: 12,
                                fontWeight: FontWeight.w900)),
                        Text('$count conducted assessment${count == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 9,
                                color: Color(0xff64748B))),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 94,
                    child: TextField(
                      controller: conversionControllers[type],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        labelText: 'Converted to',
                        suffixText: 'marks',
                        labelStyle: const TextStyle(fontSize: 8),
                        suffixStyle: const TextStyle(fontSize: 8),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saveConversions,
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Save Conversion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _assessmentColor(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return const Color(0xff2563EB);
      case 'assignment':
        return const Color(0xff7C3AED);
      case 'class test':
        return const Color(0xff0891B2);
      case 'midterm':
        return const Color(0xffEA580C);
      case 'final':
        return const Color(0xffDC2626);
      case 'presentation':
        return const Color(0xff059669);
      case 'lab':
        return const Color(0xffCA8A04);
      default:
        return const Color(0xff475569);
    }
  }

  int _assessmentTypeOrder(String type) {
    switch (type.trim().toLowerCase()) {
      case 'quiz':
        return 0;
      case 'assignment':
        return 1;
      case 'class test':
        return 2;
      case 'midterm':
        return 3;
      case 'final':
        return 4;
      case 'presentation':
        return 5;
      case 'lab':
        return 6;
      default:
        return 99;
    }
  }

  int _naturalAssessmentNameCompare(String a, String b) {
    final aName = a.trim();
    final bName = b.trim();
    final aMatch = RegExp(r'^(.*?)(\\d+)\\s*$').firstMatch(aName);
    final bMatch = RegExp(r'^(.*?)(\\d+)\\s*$').firstMatch(bName);

    if (aMatch != null && bMatch != null &&
        aMatch.group(1)!.trim().toLowerCase() ==
            bMatch.group(1)!.trim().toLowerCase()) {
      final numberCompare = int.parse(aMatch.group(2)!)
          .compareTo(int.parse(bMatch.group(2)!));
      if (numberCompare != 0) return numberCompare;
    }
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  }

  List<Map<String, dynamic>> get _groupedConductedAssessments {
    final result = List<Map<String, dynamic>>.from(_conductedAssessments);
    result.sort((a, b) {
      final typeA = a['type']?.toString() ?? '';
      final typeB = b['type']?.toString() ?? '';
      final typeCompare = _assessmentTypeOrder(typeA)
          .compareTo(_assessmentTypeOrder(typeB));
      if (typeCompare != 0) return typeCompare;

      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      return _naturalAssessmentNameCompare(nameA, nameB);
    });
    return result;
  }

  Widget _assessmentGroupHeader(String type) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _assessmentColor(type),
      ),
      child: Text(
        type.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _assessmentTable() {
    final conducted = _groupedConductedAssessments;
    if (conducted.isEmpty && totalClasses <= 0) return _emptyAssessment();

    final groupedTypes = <String>[];
    for (final assessment in conducted) {
      final type = assessment['type']?.toString().trim() ?? 'Other';
      if (!groupedTypes.any((e) => e.toLowerCase() == type.toLowerCase())) {
        groupedTypes.add(type);
      }
    }

    final assessmentColumnCount = conducted.length + (totalClasses > 0 ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffC9D5E5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const FixedColumnWidth(70),
              1: const FixedColumnWidth(145),
              if (totalClasses > 0) 2: const FixedColumnWidth(82),
              for (int i = 0; i < conducted.length; i++)
                i + 2 + (totalClasses > 0 ? 1 : 0): const FixedColumnWidth(82),
              assessmentColumnCount + 2: const FixedColumnWidth(86),
            },
            border: TableBorder.all(color: const Color(0xffD6DFEB), width: .7),
            children: [
              TableRow(
                children: [
                  _assessmentGroupHeader('Student'),
                  _assessmentGroupHeader('Student'),
                  if (totalClasses > 0)
                    _assessmentGroupHeader('Attendance'),
                  // One group-header cell is required for every assessment
                  // column because Flutter Table does not support colspan.
                  // Repeating the type across adjacent columns keeps the
                  // Quiz/Assignment groups visually together without causing
                  // an irregular TableRow.
                  ...conducted.map((assessment) => _assessmentGroupHeader(
                      assessment['type']?.toString().trim().isEmpty == true
                          ? 'Other'
                          : assessment['type'].toString())),
                  _assessmentGroupHeader('Total'),
                ],
              ),
              TableRow(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [primary, purple])),
                children: [
                  _reportHeader('ID'),
                  _reportHeader('Name'),
                  if (totalClasses > 0)
                    _reportHeader('Attendance\n/${_formatNumber(_attendanceConvertedPossible())}'),
                  ...conducted.map((assessment) => _reportHeader(
                      '${assessment['name']?.toString() ?? 'Assessment'}\n/${_formatNumber(_conversionFor(assessment['type']?.toString() ?? ''))}')),
                  _reportHeader('Total\n/${_formatNumber(_totalConvertedPossible())}'),
                ],
              ),
              ...students.map((student) {
                final dbId = studentDatabaseId(student);
                final studentId = student['student_id']?.toString() ?? '';
                final name = student['name']?.toString() ?? '';
                return TableRow(
                  children: [
                    _reportCell(Text(studentId,
                        style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w900, color: primary))),
                    _reportCell(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(name, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5,
                                height: 1.05, fontWeight: FontWeight.w600,
                                color: textDark)),
                      ),
                    ),
                    if (totalClasses > 0)
                      _reportCell(Text(dbId == null
                          ? '0'
                          : _formatNumber(_attendanceConvertedForStudent(dbId)),
                          style: const TextStyle(fontSize: 9.5,
                              fontWeight: FontWeight.w800))),
                    ...conducted.map((assessment) {
                      final value = dbId == null ? 0
                          : _convertedAssessmentMark(assessment, dbId);
                      return _reportCell(Text(_formatNumber(value),
                          style: const TextStyle(fontSize: 9.5,
                              fontWeight: FontWeight.w800)));
                    }),
                    _reportCell(Text(dbId == null ? '0'
                        : _formatNumber(_totalConvertedForStudent(dbId)),
                        style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w900, color: textDark))),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportHeader(String text) => SizedBox(
        height: 46,
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 8.5,
                  fontWeight: FontWeight.w900)),
        ),
      );

  Widget _reportCell(Widget child) => Container(
        constraints: const BoxConstraints(minHeight: 47),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        alignment: Alignment.center,
        child: child,
      );

  Widget _emptyAssessment() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xffDCE4EF)),
      ),
      child: const Column(
        children: [
          Icon(Icons.assessment_outlined, size: 46,
              color: Color(0xff94A3B8)),
          SizedBox(height: 9),
          Text('No conducted assessments found.',
              style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 3),
          Text('Enter marks for an assessment first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff64748B), fontSize: 10)),
        ],
      ),
    );
  }

  // -------------------- EXPORTS --------------------

  Future<void> exportExcel() async {
    if (selectedCourse == null) {
      showMessage('Please select a course first.', isError: true);
      return;
    }

    try {
      setState(() => exportingExcel = true);
      if (reportTab == 1) {
        if (!_validateConversionsForReport()) {
          if (mounted) setState(() => exportingExcel = false);
          return;
        }
        await saveConversions();
      }

      final excel = Excel.createExcel();
      final sheet = excel[
          reportTab == 0 ? 'Attendance Report' : 'Assessment Report'];

      final endColumn =
          reportTab == 0 ? 5 : _conductedAssessments.length + (totalClasses > 0 ? 1 : 0) + 2;
      final endLetter = _excelColumn(endColumn);

      sheet.merge(CellIndex.indexByString('A1'),
          CellIndex.indexByString('${endLetter}1'));
      sheet.cell(CellIndex.indexByString('A1')).value =
          TextCellValue(reportTab == 0 ? 'Attendance Report' : 'Assessment Report');

      sheet.merge(CellIndex.indexByString('A2'),
          CellIndex.indexByString('${endLetter}2'));
      sheet.cell(CellIndex.indexByString('A2')).value =
          TextCellValue('${selectedCourse!.code} - ${selectedCourse!.name}');

      if (reportTab == 0) {
        _buildAttendanceExcel(sheet);
      } else {
        _buildAssessmentExcel(sheet);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Could not generate Excel file.');

      final prefix = reportTab == 0 ? 'Attendance' : 'Assessment';
      await downloadFile(
        bytes,
        '${prefix}_${safeFileName(selectedCourse!.code)}_${fileDate()}.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        setState(() => exportingExcel = false);
        showMessage('Excel report downloaded successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => exportingExcel = false);
        showMessage('Excel export failed: $e', isError: true);
      }
    }
  }

  void _buildAttendanceExcel(Sheet sheet) {
    const headers = [
      'Student ID', 'Student Name', 'Present', 'Absent',
      'Total Classes', 'Attendance %'
    ];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3))
          .value = TextCellValue(headers[i]);
    }

    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      final id = studentDatabaseId(student);
      if (id == null) continue;
      final values = [
        student['student_id']?.toString() ?? '',
        student['name']?.toString() ?? '',
        studentPresentCount(id),
        studentAbsentCount(id),
        studentTotalClasses(id),
        percentageText(studentPercentage(id)),
      ];
      for (int c = 0; c < values.length; c++) {
        final value = values[c];
        sheet.cell(CellIndex.indexByColumnRow(
                columnIndex: c, rowIndex: i + 4))
            .value = value is int
            ? IntCellValue(value)
            : TextCellValue(value.toString());
      }
    }
  }

  void _buildAssessmentExcel(Sheet sheet) {
    final conducted = _groupedConductedAssessments;
    final hasAttendance = totalClasses > 0;
    final headers = [
      'Student ID', 'Student Name',
      if (hasAttendance) 'Attendance /${_formatNumber(_attendanceConvertedPossible())}',
      ...conducted.map((assessment) =>
          '${assessment['name']?.toString() ?? 'Assessment'} /${_formatNumber(_conversionFor(assessment['type']?.toString() ?? ''))}'),
      'Total /${_formatNumber(_totalConvertedPossible())}',
    ];

    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('STUDENT');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('STUDENT');

    var groupStart = 2;
    if (hasAttendance) {
      final col = _excelColumn(groupStart);
      sheet.cell(CellIndex.indexByString('${col}3')).value = TextCellValue('ATTENDANCE');
      groupStart++;
    }

    while (groupStart < conducted.length + 2 + (hasAttendance ? 1 : 0)) {
      final idx = groupStart - 2 - (hasAttendance ? 1 : 0);
      final type = conducted[idx]['type']?.toString() ?? 'Other';
      var groupEnd = groupStart;
      while (groupEnd < conducted.length + 2 + (hasAttendance ? 1 : 0)) {
        final nextIdx = groupEnd - 2 - (hasAttendance ? 1 : 0);
        if ((conducted[nextIdx]['type']?.toString() ?? 'Other').trim().toLowerCase() != type.trim().toLowerCase()) break;
        groupEnd++;
      }
      final startLetter = _excelColumn(groupStart);
      final endLetter = _excelColumn(groupEnd - 1);
      sheet.merge(CellIndex.indexByString('${startLetter}3'), CellIndex.indexByString('${endLetter}3'));
      sheet.cell(CellIndex.indexByString('${startLetter}3')).value = TextCellValue(type.toUpperCase());
      groupStart = groupEnd;
    }

    final totalColumn = headers.length - 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: totalColumn, rowIndex: 2))
        .value = TextCellValue('TOTAL');

    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3))
          .value = TextCellValue(headers[i]);
    }

    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      final dbId = studentDatabaseId(student);
      if (dbId == null) continue;
      final values = <dynamic>[
        student['student_id']?.toString() ?? '',
        student['name']?.toString() ?? '',
        if (hasAttendance) _attendanceConvertedForStudent(dbId),
        ...conducted.map((assessment) => _convertedAssessmentMark(assessment, dbId)),
        _totalConvertedForStudent(dbId),
      ];
      for (int c = 0; c < values.length; c++) {
        final value = values[c];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 4))
            .value = value is num
            ? DoubleCellValue(value.toDouble())
            : TextCellValue(value.toString());
      }
    }
  }

  String _excelColumn(int index) {
    var n = index + 1;
    var result = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      result = String.fromCharCode(65 + rem) + result;
      n = (n - 1) ~/ 26;
    }
    return result;
  }

  Future<void> exportPdf() async {
    if (selectedCourse == null) {
      showMessage('Please select a course first.', isError: true);
      return;
    }

    try {
      setState(() => exportingPdf = true);
      if (reportTab == 1) {
        if (!_validateConversionsForReport()) {
          if (mounted) setState(() => exportingPdf = false);
          return;
        }
        await saveConversions();
      }

      final pdf = pw.Document();
      if (reportTab == 0) {
        _buildAttendancePdf(pdf);
      } else {
        _buildAssessmentPdf(pdf);
      }

      final bytes = await pdf.save();
      final prefix = reportTab == 0 ? 'Attendance' : 'Assessment';
      await downloadFile(
        bytes,
        '${prefix}_${safeFileName(selectedCourse!.code)}_${fileDate()}.pdf',
        'application/pdf',
      );

      if (mounted) {
        setState(() => exportingPdf = false);
        showMessage('PDF report downloaded successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => exportingPdf = false);
        showMessage('PDF export failed: $e', isError: true);
      }
    }
  }

  void _buildAttendancePdf(pw.Document pdf) {
    final data = students.map((student) {
      final id = studentDatabaseId(student);
      if (id == null) return <String>['', '', '', '', '', ''];
      return [
        student['student_id']?.toString() ?? '',
        student['name']?.toString() ?? '',
        studentPresentCount(id).toString(),
        studentAbsentCount(id).toString(),
        studentTotalClasses(id).toString(),
        percentageText(studentPercentage(id)),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text('Attendance Report',
              style: pw.TextStyle(fontSize: 20,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('${selectedCourse!.code} - ${selectedCourse!.name}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Student ID', 'Student Name', 'Present',
              'Absent', 'Total', 'Attendance'
            ],
            data: data,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blue),
            cellStyle: const pw.TextStyle(fontSize: 8),
            border: pw.TableBorder.all(color: PdfColors.grey400),
            cellPadding: const pw.EdgeInsets.all(5),
          ),
        ],
      ),
    );
  }

  void _buildAssessmentPdf(pw.Document pdf) {
    final conducted = _groupedConductedAssessments;
    final hasAttendance = totalClasses > 0;
    final headers = [
      'Student ID', 'Student Name',
      if (hasAttendance) 'Attendance /${_formatNumber(_attendanceConvertedPossible())}',
      ...conducted.map((assessment) =>
          '${assessment['name']?.toString() ?? 'Assessment'} /${_formatNumber(_conversionFor(assessment['type']?.toString() ?? ''))}'),
      'Total /${_formatNumber(_totalConvertedPossible())}',
    ];

    final data = students.map((student) {
      final id = studentDatabaseId(student);
      if (id == null) return List<String>.filled(headers.length, '');
      return [
        student['student_id']?.toString() ?? '',
        student['name']?.toString() ?? '',
        if (hasAttendance) _formatNumber(_attendanceConvertedForStudent(id)),
        ...conducted.map((assessment) =>
            _formatNumber(_convertedAssessmentMark(assessment, id))),
        _formatNumber(_totalConvertedForStudent(id)),
      ];
    }).toList();

    final groupRow = <String>['STUDENT', 'STUDENT'];
    if (hasAttendance) groupRow.add('ATTENDANCE');
    String? previousType;
    for (final assessment in conducted) {
      final type = (assessment['type']?.toString() ?? 'Other').toUpperCase();
      groupRow.add(type == previousType ? '' : type);
      previousType = type;
    }
    groupRow.add('TOTAL');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text('Assessment Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('${selectedCourse!.code} - ${selectedCourse!.name}'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            cellStyle: const pw.TextStyle(fontSize: 7),
            border: pw.TableBorder.all(color: PdfColors.grey400),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Future<void> downloadFile(
      List<int> bytes, String fileName, String mimeType) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      text: fileName,
    );
  }

  String fileDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String safeFileName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [purple, Color(0xffC026D3)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reports 📊',
                            style: TextStyle(color: Colors.white,
                                fontSize: 25, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Attendance & Assessment',
                            style: TextStyle(color: Colors.white70,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => bangla = !bangla),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(bangla ? 'EN' : 'বাং',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: loadReport,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(15, 15, 15, 105),
                        children: [
                          courseSelector(),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              _tabButton('Attendance',
                                  Icons.fact_check_rounded, 0),
                              const SizedBox(width: 8),
                              _tabButton('Assessment',
                                  Icons.assessment_rounded, 1),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (selectedCourse != null && reportTab == 0) ...[
                            _attendanceSummaryCard(),
                            const SizedBox(height: 13),
                            if (students.isEmpty)
                              emptyReport()
                            else
                              ...students.map(_attendanceStudentCard),
                          ],
                          if (selectedCourse != null && reportTab == 1) ...[
                            _assessmentDistribution(),
                            const SizedBox(height: 12),
                            _assessmentTable(),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: exportingPdf || exportingExcel
                                      ? null
                                      : exportPdf,
                                  icon: exportingPdf
                                      ? const SizedBox(
                                          width: 17, height: 17,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.picture_as_pdf_rounded),
                                  label: Text(
                                      exportingPdf ? 'Creating...' : 'PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: exportingPdf || exportingExcel
                                      ? null
                                      : exportExcel,
                                  icon: exportingExcel
                                      ? const SizedBox(
                                          width: 17, height: 17,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.table_chart_rounded),
                                  label: Text(
                                      exportingExcel ? 'Creating...' : 'Excel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyReport() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 46,
              color: Color(0xff94A3B8)),
          SizedBox(height: 9),
          Text('No attendance data available.',
              style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Save attendance first to generate the report.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff64748B), fontSize: 10)),
        ],
      ),
    );
  }
}

// ============================================================
// MARKS PAGE
// ============================================================

class MarksPage extends StatefulWidget {
  const MarksPage({super.key});

  @override
  State<MarksPage> createState() => _MarksPageState();
}

class _MarksPageState extends State<MarksPage> {
  static const Color primary = Color(0xff2563EB);
  static const Color purple = Color(0xff7C3AED);
  static const Color background = Color(0xffF5F7FB);
  static const Color textDark = Color(0xff172033);

  List<Course> courses = [];
  Course? selectedCourse;
  List<Map<String, dynamic>> assessments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final data = await DatabaseHelper.instance.getCourses();
      if (!mounted) return;

      setState(() {
        courses = data;
        if (selectedCourse != null) {
          final matches = data.where((c) => c.id == selectedCourse!.id).toList();
          selectedCourse = matches.isNotEmpty
              ? matches.first
              : (data.isEmpty ? null : data.first);
        } else {
          selectedCourse = data.isEmpty ? null : data.first;
        }
      });

      await loadAssessments();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load marks data: $e')),
      );
    }
  }

  Future<void> loadAssessments() async {
    if (selectedCourse?.id == null) {
      if (mounted) {
        setState(() {
          assessments = [];
          loading = false;
        });
      }
      return;
    }

    final data =
        await DatabaseHelper.instance.getAssessments(selectedCourse!.id!);

    if (!mounted) return;
    setState(() {
      assessments = data;
      loading = false;
    });
  }

  String _nextName(String type) {
    final prefix = type.trim().toLowerCase();
    int maxNo = 0;

    for (final a in assessments) {
      if (a['type'].toString().trim().toLowerCase() == prefix) {
        final match =
            RegExp(r'(\d+)\s*$').firstMatch(a['name'].toString());
        if (match != null) {
          maxNo = [
            maxNo,
            int.tryParse(match.group(1)!) ?? 0,
          ].reduce((a, b) => a > b ? a : b);
        }
      }
    }

    return '$type ${maxNo + 1}';
  }

  String _formatNumber(num value) {
    final n = value.toDouble();
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  Color _assessmentColor(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return const Color(0xff2563EB);
      case 'assignment':
        return const Color(0xff7C3AED);
      case 'class test':
        return const Color(0xff0891B2);
      case 'midterm':
        return const Color(0xffEA580C);
      case 'final':
        return const Color(0xffDC2626);
      case 'presentation':
        return const Color(0xff059669);
      case 'lab':
        return const Color(0xffCA8A04);
      default:
        return const Color(0xff475569);
    }
  }

  Future<void> _addAssessment() async {
    if (selectedCourse?.id == null) return;

    final typeController = ValueNotifier<String>('Quiz');
    final nameController =
        TextEditingController(text: _nextName('Quiz'));
    final outController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: const [
              Icon(Icons.add_chart_rounded, color: primary),
              SizedBox(width: 10),
              Text(
                'Add Assessment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: typeController.value,
                  decoration: InputDecoration(
                    labelText: 'Assessment Type',
                    prefixIcon: const Icon(Icons.category_rounded),
                    filled: true,
                    fillColor: const Color(0xffF5F7FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    'Quiz',
                    'Assignment',
                    'Class Test',
                    'Midterm',
                    'Final',
                    'Presentation',
                    'Lab',
                    'Other'
                  ]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    typeController.value = v;
                    nameController.text = _nextName(v);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Assessment Name',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    filled: true,
                    fillColor: const Color(0xffF5F7FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: outController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Out of Marks',
                    prefixIcon: const Icon(Icons.score_rounded),
                    hintText: 'e.g. 10 or 20.5',
                    filled: true,
                    fillColor: const Color(0xffF5F7FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final outOf =
                    double.tryParse(outController.text.trim());
                final name = nameController.text.trim();

                if (name.isEmpty || outOf == null || outOf < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid assessment name and Out of Marks.',
                      ),
                    ),
                  );
                  return;
                }

                final id =
                    await DatabaseHelper.instance.insertAssessment({
                  'course_id': selectedCourse!.id,
                  'type': typeController.value,
                  'name': name,
                  'out_of': outOf,
                });

                if (id == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Assessment already exists or data is invalid.',
                      ),
                    ),
                  );
                  return;
                }

                if (mounted) Navigator.pop(dialogContext);
                await loadAssessments();
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      outController.dispose();
      typeController.dispose();
    });
  }

  Future<void> _editAssessment(
    Map<String, dynamic> assessment,
  ) async {
    final nameController =
        TextEditingController(text: assessment['name'].toString());
    final outController = TextEditingController(
      text: (assessment['out_of'] as num).toString(),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: primary),
            SizedBox(width: 10),
            Text(
              'Edit Assessment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Assessment Name',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                filled: true,
                fillColor: const Color(0xffF5F7FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: outController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Out of Marks',
                prefixIcon: const Icon(Icons.score_rounded),
                filled: true,
                fillColor: const Color(0xffF5F7FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final outOf =
                  double.tryParse(outController.text.trim());

              if (nameController.text.trim().isEmpty ||
                  outOf == null ||
                  outOf < 0) {
                return;
              }

              final result =
                  await DatabaseHelper.instance.updateAssessment({
                'id': assessment['id'],
                'course_id': selectedCourse!.id,
                'type': assessment['type'],
                'name': nameController.text.trim(),
                'out_of': outOf,
              });

              if (result == -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Out of Marks cannot be lower than an existing student mark.',
                    ),
                  ),
                );
                return;
              }

              if (result == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update assessment.'),
                  ),
                );
                return;
              }

              if (mounted) Navigator.pop(dialogContext);
              await loadAssessments();
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Update'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      outController.dispose();
    });
  }

  Future<void> _deleteAssessment(
    Map<String, dynamic> assessment,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text(
              'Delete Assessment?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Delete ${assessment['name']} and all student marks for it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (yes == true) {
      await DatabaseHelper.instance
          .deleteAssessment(assessment['id'] as int);
      await loadAssessments();
    }
  }

  Future<void> _openMarks(
    Map<String, dynamic> assessment,
  ) async {
    if (selectedCourse?.id == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarksEntryPage(
          course: selectedCourse!,
          assessment: assessment,
        ),
      ),
    );

    await loadAssessments();
  }

  Widget _courseSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xffD8E1F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: DropdownButtonFormField<Course>(
        value: selectedCourse,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Select Course',
          prefixIcon: Container(
            margin: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primary, purple],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: const Color(0xffF7F9FE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        items: courses
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(
                  '${c.code} • ${c.name} • ${c.section}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (c) async {
          setState(() {
            selectedCourse = c;
            loading = true;
          });
          await loadAssessments();
        },
      ),
    );
  }

  Widget _assessmentCard(
    Map<String, dynamic> assessment,
    int index,
  ) {
    final color = _assessmentColor(assessment['type'].toString());
    final outOf = (assessment['out_of'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: .18),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openMarks(assessment),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: .72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assessment['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            assessment['type'].toString(),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Out of ${_formatNumber(outOf)}',
                            style: const TextStyle(
                              color: Color(0xff475569),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _editAssessment(assessment),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xff64748B),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editAssessment(assessment);
                  if (v == 'delete') _deleteAssessment(assessment);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marks',
              style: TextStyle(
                color: textDark,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Assessments & student scores',
              style: TextStyle(
                color: Color(0xff64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primary, purple],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Add Assessment',
              onPressed: selectedCourse == null ? null : _addAssessment,
              color: Colors.white,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _courseSelector(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Assessments',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (assessments.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffE8F0FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${assessments.length} total',
                            style: const TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: selectedCourse == null
                      ? Center(
                          child: _EmptyMarksState(
                            icon: Icons.menu_book_outlined,
                            title: 'No course available',
                            subtitle: 'Add a course before entering marks.',
                            buttonText: 'Go to Courses',
                            onPressed: null,
                          ),
                        )
                      : assessments.isEmpty
                          ? Center(
                              child: _EmptyMarksState(
                                icon: Icons.assignment_outlined,
                                title: 'No assessments yet',
                                subtitle:
                                    'Create Quiz, Assignment, Exam or other assessments.',
                                buttonText: 'Add Assessment',
                                onPressed: _addAssessment,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: loadAssessments,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  2,
                                  16,
                                  120,
                                ),
                                itemCount: assessments.length,
                                itemBuilder: (_, i) =>
                                    _assessmentCard(assessments[i], i),
                              ),
                            ),
                ),
              ],
            ),
    );
  }
}

class _EmptyMarksState extends StatelessWidget {
  const _EmptyMarksState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xffDDE5F1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xff2563EB),
                  Color(0xff7C3AED),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xff172033),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff64748B),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (onPressed != null)
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(buttonText),
            ),
        ],
      ),
    );
  }
}



// ============================================================
// SETTINGS
// ============================================================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color primary = Color(0xff0B6EDC);
  static const Color dark = Color(0xff14213D);
  static const Color background = Color(0xffF5F9FF);

  bool loading = true;
  bool connecting = false;
  bool disconnecting = false;
  bool backingUp = false;
  bool restoring = false;
  bool autoSyncEnabled = true;
  String lastBackup = 'No backup recorded';
  String? accountEmail;
  String driveStatus = 'Not connected';
  String folderStatus = 'Attendance folder not checked';
  String? errorText;

  @override
  void initState() {
    super.initState();
    _loadDriveState();
    ProfileStore.instance.load();
    GoogleDriveSyncService.instance.initialize();
  }

  Future<void> _loadDriveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = GoogleDriveSyncService.instance;
      await service.initialize();

      if (!mounted) return;
      setState(() {
        accountEmail = service.accountEmail ?? prefs.getString('drive_account_email');
        driveStatus = service.isConnected ? 'Connected' : 'Not connected';
        folderStatus = prefs.getString('drive_root_folder_id') != null
            ? 'Attendance folder ready ✓'
            : 'Attendance folder not checked';
        autoSyncEnabled = prefs.getBool('drive_auto_sync_enabled') ?? true;
        lastBackup = _formatBackupTime(prefs.getString('drive_last_backup_at'));
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = e.toString();
      });
    }
  }

  String _formatBackupTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'No backup recorded';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'No backup recorded';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _setAutoSync(bool enabled) async {
    if (autoSyncEnabled == enabled) return;

    setState(() {
      autoSyncEnabled = enabled;
      errorText = null;
    });

    try {
      await GoogleDriveSyncService.instance.setAutoSyncEnabled(enabled);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Auto Sync enabled.'
                : 'Auto Sync disabled. Manual sync is still available.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => autoSyncEnabled = !enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change Auto Sync: $e')),
      );
    }
  }

  Future<void> _backupNow() async {
    if (backingUp) return;
    if (!GoogleDriveSyncService.instance.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect Google Drive first.')),
      );
      return;
    }
    setState(() {
      backingUp = true;
      errorText = null;
      driveStatus = 'Backing up...';
    });
    try {
      final data = await DatabaseHelper.instance.exportAllData();
      await GoogleDriveSyncService.instance.syncFullBackup(data);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        backingUp = false;
        driveStatus = 'Connected';
        lastBackup = _formatBackupTime(prefs.getString('drive_last_backup_at'));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup completed successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        backingUp = false;
        driveStatus = 'Backup failed';
        errorText = e.toString();
      });
    }
  }

  Future<void> _restoreNow() async {
    if (restoring) return;
    if (!GoogleDriveSyncService.instance.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect Google Drive first.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'Missing courses, students, attendance, assessments and marks will '
          'be restored. Existing matching records will be preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      restoring = true;
      errorText = null;
      driveStatus = 'Restoring...';
    });
    try {
      final backup = await GoogleDriveSyncService.instance.downloadFullBackup();
      if (backup == null) throw Exception('No full backup was found in the Attendance folder.');
      final result = await DatabaseHelper.instance.restoreAllData(backup);
      if (!mounted) return;
      setState(() {
        restoring = false;
        driveStatus = 'Connected';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restore complete: ${result['courses']} courses, '
            '${result['students']} students, ${result['attendance']} attendance, '
            '${result['assessments']} assessments, ${result['marks']} marks added.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        restoring = false;
        driveStatus = 'Restore failed';
        errorText = e.toString();
      });
    }
  }

  Future<void> _connectDrive() async {
    if (connecting) return;
    setState(() {
      connecting = true;
      errorText = null;
      driveStatus = 'Connecting...';
      folderStatus = 'Creating/checking Attendance folder...';
    });

    try {
      final account = await GoogleDriveSyncService.instance.connect();
      final prefs = await SharedPreferences.getInstance();
      final folderId = prefs.getString('drive_root_folder_id');

      if (!mounted) return;
      setState(() {
        accountEmail = account.email;
        driveStatus = 'Connected';
        folderStatus = folderId != null
            ? 'Attendance folder created/ready ✓'
            : 'Connected, but folder ID was not saved';
        connecting = false;
      });

      // First connection creates/checks the Attendance folder and immediately
      // stores a full backup of the current local data.
      await _backupNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Drive connected. Attendance folder is ready.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        driveStatus = 'Connection failed';
        folderStatus = 'Attendance folder unavailable';
        errorText = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Drive connection failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _disconnectDrive() async {
    if (disconnecting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'This stops Drive synchronization on this device. '
          'Existing backups in Google Drive will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      disconnecting = true;
      errorText = null;
    });

    try {
      await GoogleDriveSyncService.instance.disconnect();
      if (!mounted) return;
      setState(() {
        accountEmail = null;
        driveStatus = 'Not connected';
        folderStatus = 'Attendance folder not checked';
        disconnecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        disconnecting = false;
        errorText = e.toString();
      });
    }
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: dark, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  color: Color(0xff718096), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _profileCard(ProfileData profile) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffDCE7F5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: _ProfileAvatar(path: profile.photoPath, size: 54),
        title: Text(
          profile.name.isEmpty ? 'Profile' : profile.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          profile.department.isEmpty
              ? (profile.institution.isEmpty ? 'Add your profile details' : profile.institution)
              : profile.department,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        ),
      ),
    );
  }

  Widget _driveCard() {
    final connected = driveStatus == 'Connected';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: connected
              ? const Color(0xffB7E4CF)
              : const Color(0xffDCE7F5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: connected
                        ? const Color(0xffE8F8EF)
                        : const Color(0xffEEF5FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.cloud_done_rounded,
                    color: connected
                        ? const Color(0xff059669)
                        : primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Google Drive Backup',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (loading || connecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    connected
                        ? Icons.check_circle_rounded
                        : Icons.cloud_off_rounded,
                    color: connected
                        ? const Color(0xff059669)
                        : const Color(0xff94A3B8),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            _statusRow(
              Icons.account_circle_outlined,
              'Account',
              accountEmail ?? 'Not connected',
            ),
            const SizedBox(height: 9),
            _statusRow(
              Icons.folder_rounded,
              'Drive folder',
              folderStatus,
            ),
            const SizedBox(height: 9),
            _statusRow(
              Icons.sync_rounded,
              'Sync status',
              driveStatus,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xffF7FAFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffDCE7F5)),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text(
                  'Auto Sync',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  connected
                      ? 'Automatically sync changed data every few minutes'
                      : 'Connect Google Drive to use Auto Sync',
                  style: const TextStyle(fontSize: 10, color: Color(0xff64748B)),
                ),
                value: autoSyncEnabled,
                onChanged: connected && !backingUp && !restoring
                    ? _setAutoSync
                    : null,
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffDC2626),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 9),
            _statusRow(Icons.schedule_rounded, 'Last backup', lastBackup),
            const SizedBox(height: 15),
            if (connected) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: backingUp || restoring ? null : _backupNow,
                      icon: const Icon(Icons.backup_rounded),
                      label: Text(backingUp ? 'Syncing...' : 'Sync now'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: backingUp || restoring ? null : _restoreNow,
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(restoring ? 'Restoring...' : 'Restore'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: disconnecting || backingUp || restoring ? null : _disconnectDrive,
                  icon: const Icon(Icons.link_off_rounded),
                  label: Text(disconnecting ? 'Disconnecting...' : 'Disconnect Google Drive'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: connecting ? null : _connectDrive,
                  icon: const Icon(Icons.add_link_rounded),
                  label: Text(connecting ? 'Connecting...' : 'Sync with Google Drive'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xff64748B)),
        const SizedBox(width: 9),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff475569),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: background,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDriveState,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 35),
          children: [
            _sectionTitle(
              'Profile',
              'Manage your academic profile',
            ),
            ValueListenableBuilder<ProfileData>(
              valueListenable: ProfileStore.instance.notifier,
              builder: (context, profile, _) => _profileCard(profile),
            ),
            _sectionTitle(
              'Backup & Recovery',
              'Keep your course data safe in your own Google Drive',
            ),
            _driveCard(),
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xffDCE7F5)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'When Google Drive is connected, Auto Sync can automatically upload changed data to an '
                        'Attendance folder for backup data. It checks for changes while the app is open. Existing backups '
                        'are not deleted when you disconnect.',
                        style: TextStyle(
                          color: Color(0xff475569),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  final institution = TextEditingController();
  final department = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  String photoPath = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ProfileStore.instance.load();
    name.text = p.name;
    institution.text = p.institution;
    department.text = p.department;
    email.text = p.email;
    phone.text = p.phone;
    if (mounted) setState(() => photoPath = p.photoPath);
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => photoPath = result.files.single.path!);
  }

  Future<void> _save() async {
    await ProfileStore.instance.save(ProfileData(
      name: name.text.trim(),
      institution: institution.text.trim(),
      department: department.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      photoPath: photoPath,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    institution.dispose();
    department.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: _ProfileAvatar(path: photoPath, size: 92),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Tap photo to change',
                style: TextStyle(color: Color(0xff718096), fontSize: 11)),
          ),
          const SizedBox(height: 20),
          TextField(controller: name, decoration: _dec('Name', Icons.person_outline)),
          const SizedBox(height: 12),
          TextField(controller: institution, decoration: _dec('Institution', Icons.account_balance_outlined)),
          const SizedBox(height: 12),
          TextField(controller: department, decoration: _dec('Department', Icons.school_outlined)),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email', Icons.email_outlined)),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone,
              decoration: _dec('Phone', Icons.phone_outlined)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MARKS ENTRY TABLE
// ============================================================

class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({
    super.key,
    required this.course,
    required this.assessment,
  });

  final Course course;
  final Map<String, dynamic> assessment;

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  static const Color primary = Color(0xff2563EB);
  static const Color purple = Color(0xff7C3AED);
  static const Color background = Color(0xffF5F7FB);
  static const Color textDark = Color(0xff172033);

  List<Map<String, dynamic>> students = [];
  final Map<int, String> status = {};
  final Map<int, TextEditingController> controllers = {};
  bool loading = true;
  bool saving = false;

  double get outOf =>
      (widget.assessment['out_of'] as num).toDouble();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loadedStudents = await DatabaseHelper.instance
          .getStudents(widget.course.id!);

      final saved = await DatabaseHelper.instance
          .getMarks(widget.assessment['id'] as int);

      final savedByStudent = {
        for (final m in saved) m['student_id'] as int: m
      };

      for (final s in loadedStudents) {
        final id = s['id'] as int;
        final old = savedByStudent[id];

        status[id] =
            old?['status']?.toString() == 'Absent'
                ? 'Absent'
                : 'Present';

        controllers[id] = TextEditingController(
          text: old == null || status[id] == 'Absent'
              ? ''
              : _formatNumber(
                  (old['marks'] as num).toDouble(),
                ),
        );
      }

      if (!mounted) return;
      setState(() {
        students = loadedStudents;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _formatNumber(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Color _rowColor(int index) {
    return index.isEven ? Colors.white : const Color(0xffF8FAFD);
  }

  Color _statusColor(String value) {
    return value == 'Absent'
        ? const Color(0xffDC2626)
        : const Color(0xff059669);
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;

    final entries = <Map<String, dynamic>>[];

    for (final s in students) {
      final id = s['id'] as int;
      final st = status[id] ?? 'Present';

      if (st == 'Absent') {
        entries.add({
          'student_id': id,
          'status': 'Absent',
          'marks': 0.0,
        });
        continue;
      }

      final raw = controllers[id]!.text.trim();

      if (raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter marks for ${s['name']} before saving.',
            ),
          ),
        );
        return;
      }

      final value = double.tryParse(raw);

      if (value == null || value < 0 || value > outOf) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid marks for ${s['name']}. '
              'Marks must be between 0 and ${_formatNumber(outOf)}.',
            ),
          ),
        );
        return;
      }

      entries.add({
        'student_id': id,
        'status': 'Present',
        'marks': value,
      });
    }

    setState(() => saving = true);

    final result = await DatabaseHelper.instance.saveMarksBulk(
      widget.assessment['id'] as int,
      entries,
    );

    if (!mounted) return;

    setState(() => saving = false);

    if (result == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marks saved successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xff059669),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save marks.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _infoHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x252563EB),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: .20),
              ),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.assessment['name'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.course.code} • ${widget.course.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffE7EEFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'OUT OF',
                  style: TextStyle(
                    color: Color(0xffE7EEFF),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatNumber(outOf),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          const Icon(
            Icons.touch_app_rounded,
            size: 15,
            color: Color(0xff64748B),
          ),
          const SizedBox(width: 5),
          const Expanded(
            child: Text(
              'Enter marks for Present students. Absent students receive 0.',
              style: TextStyle(
                color: Color(0xff64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xffE8F7F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${students.length} students',
              style: const TextStyle(
                color: Color(0xff047857),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusToggle(int id) {
    final isPresent = (status[id] ?? 'Present') == 'Present';

    return Semantics(
      label: isPresent ? 'Present' : 'Absent',
      button: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            status[id] = isPresent ? 'Absent' : 'Present';

            if (!isPresent) {
              // Absent -> Present: marks must be entered again.
              controllers[id]!.clear();
            } else {
              // Present -> Absent: default marks become 0.
              controllers[id]!.text = '0';
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isPresent
                ? const Color(0xffA8D9B0)
                : const Color(0xffD6DCE5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPresent
                  ? const Color(0xff8BC998)
                  : const Color(0xffC4CBD6),
              width: 1,
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: isPresent
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _marksField(int id) {
    final absent = status[id] == 'Absent';

    return Container(
      height: 36,
      width: double.infinity,
      decoration: BoxDecoration(
        color: absent
            ? const Color(0xffF1F3F6)
            : const Color(0xffF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: absent
              ? const Color(0xffD1D7E0)
              : const Color(0xffAFC5F5),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controllers[id],
        enabled: !absent,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: absent
              ? const Color(0xff64748B)
              : const Color(0xff172033),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: _formatNumber(outOf),
          hintStyle: const TextStyle(
            color: Color(0xffA0A9B8),
            fontSize: 10,
          ),
          suffixText: '/${_formatNumber(outOf)}',
          suffixStyle: const TextStyle(
            color: Color(0xff94A3B8),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _marksTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xffB8C7DD),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          defaultVerticalAlignment:
              TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: const BorderSide(
              color: Color(0xffDCE3ED),
              width: .8,
            ),
            verticalInside: const BorderSide(
              color: Color(0xffDCE3ED),
              width: .8,
            ),
          ),
          columnWidths: const {
            0: FixedColumnWidth(34),
            1: FlexColumnWidth(4.3),
            2: FixedColumnWidth(58),
            3: FixedColumnWidth(76),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, purple],
                ),
              ),
              children: const [
                _TableHeaderCell('#'),
                _TableHeaderCell('Student'),
                _TableHeaderCell('P/A'),
                _TableHeaderCell('Marks'),
              ],
            ),
            ...List.generate(students.length, (index) {
              final s = students[index];
              final id = s['id'] as int;

              return TableRow(
                decoration: BoxDecoration(
                  color: _rowColor(index),
                ),
                children: [
                  _TableBodyCell(
                    minHeight: 50,
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  _TableBodyCell(
                    minHeight: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: _StudentIdentity(
                          studentId: s['student_id'].toString(),
                          name: s['name'].toString(),
                          idFontSize: 14,
                          nameFontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
                  _TableBodyCell(
                    minHeight: 50,
                    child: Center(
                      child: _statusToggle(id),
                    ),
                  ),
                  _TableBodyCell(
                    minHeight: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                      ),
                      child: _marksField(id),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marks Entry',
              style: TextStyle(
                color: textDark,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Student-wise assessment table',
              style: TextStyle(
                color: Color(0xff64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xffE8F7F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Save Marks',
              onPressed: saving ? null : _save,
              color: const Color(0xff047857),
              icon: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
              ? const Center(
                  child: _EmptyMarksState(
                    icon: Icons.people_outline_rounded,
                    title: 'No students in this course',
                    subtitle:
                        'Add students to the course before entering marks.',
                    buttonText: '',
                    onPressed: null,
                  ),
                )
              : Column(
                  children: [
                    _infoHeader(),
                    _legend(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        child: _marksTable(),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          8,
                          14,
                          10,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: Color(0xffDDE5F1),
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: saving ? null : _save,
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_rounded,
                                  ),
                            label: Text(
                              saving
                                  ? 'Saving Marks...'
                                  : 'Save All Marks',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
      ),
    );
  }
}

class _TableBodyCell extends StatelessWidget {
  const _TableBodyCell({
    required this.child,
    this.minHeight = 50,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
