import 'dart:typed_data';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';

import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database_helper.dart';
import 'models/course.dart';
import 'services/google_drive_sync_service.dart';


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

  ProfileData copyWith({
    String? name,
    String? institution,
    String? department,
    String? email,
    String? phone,
    String? photoPath,
  }) {
    return ProfileData(
      name: name ?? this.name,
      institution: institution ?? this.institution,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
    );
  }
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ProfileStore.instance.load();
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DriveSettingsPage(),
      ),
    );
  }

  List<Widget> get pages => [
        Dashboard(
          onSettings: _openSettings,
          onCourse: () => setState(() => currentIndex = 1),
          onStudent: () => setState(() => currentIndex = 2),
          onAttendance: () => setState(() => currentIndex = 3),
          onReport: () => setState(() => currentIndex = 4),
        ),
        const CoursePage(),
        const StudentPage(),
        const AttendancePage(),
        const ReportPage(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F9FF),
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xffD7E8FF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x160B5ED7),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: currentIndex,
            indicatorColor: const Color(0xffE4F0FF),
            onDestinationSelected: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: "Home",
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: "Courses",
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: "Students",
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: "Attendance",
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics_rounded),
                label: "Reports",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    this.onSettings,
    this.onCourse,
    this.onStudent,
    this.onAttendance,
    this.onReport,
  });

  final VoidCallback? onSettings;
  final VoidCallback? onCourse;
  final VoidCallback? onStudent;
  final VoidCallback? onAttendance;
  final VoidCallback? onReport;

  static const Color primary = Color(0xff0B6EDC);
  static const Color dark = Color(0xff14213D);
  static const Color background = Color(0xffF5F9FF);

  Widget _statCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffC8E0FF),
          width: 1.2,
        ),
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
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: primary,
                  size: 23,
                ),
              ),
              const Spacer(),
              Icon(
                icon,
                color: const Color(0xff9ABBE2),
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            value,
            style: const TextStyle(
              color: primary,
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: dark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xff718096),
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
            border: Border.all(
              color: const Color(0xffC8E0FF),
            ),
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
                child: Icon(
                  icon,
                  color: primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: dark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xff718096),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xff7EA9D7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: dark,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xff718096),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _attendanceOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff0B6EDC),
            Color(0xff1488E8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x250B6EDC),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
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
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attendance Overview",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Keep track of classroom participation",
                      style: TextStyle(
                        color: Color(0xffDCEEFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.insights_rounded,
                color: Color(0xffBFE0FF),
              ),
            ],
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "87%",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: Color(0xffD7F8E7),
                      size: 17,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "Overall Attendance",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: .87,
              minHeight: 8,
              backgroundColor: Color(0x35FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xffD4E7FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xffEAF4FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xff718096),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashboardGridPainter(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
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
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x180B6EDC),
                              blurRadius: 14,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "COURSE ATTENDANCE MANAGER",
                              style: TextStyle(
                                color: primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Academic Attendance Hub",
                              style: TextStyle(
                                color: dark,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<ProfileData>(
                        valueListenable: ProfileStore.instance.notifier,
                        builder: (context, profile, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: onSettings,
                                child: _ProfileAvatar(
                                  path: profile.photoPath,
                                  size: 46,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onSettings,
                                  borderRadius: BorderRadius.circular(15),
                                  child: Ink(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: const Color(0xffC8E0FF),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.settings_outlined,
                                      color: dark,
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 21),
                  ValueListenableBuilder<ProfileData>(
                    valueListenable: ProfileStore.instance.notifier,
                    builder: (context, profile, _) {
                      final displayName = profile.name.trim().isEmpty
                          ? "Welcome back"
                          : "Welcome back, ${profile.name.trim()}";

                      return Container(
                        padding: const EdgeInsets.fromLTRB(19, 17, 19, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xffC8E0FF),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.waving_hand_rounded,
                              color: Color(0xffF59E0B),
                              size: 24,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: dark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Manage your courses, students and attendance in one place.",
                                    style: TextStyle(
                                      color: Color(0xff718096),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 17),
                  _attendanceOverview(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    "At a Glance",
                    "Your academic workspace",
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 11,
                    childAspectRatio: 1.03,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _statCard(
                        value: "12",
                        title: "Courses",
                        subtitle: "Active courses",
                        icon: Icons.menu_book_rounded,
                      ),
                      _statCard(
                        value: "350",
                        title: "Students",
                        subtitle: "Across all courses",
                        icon: Icons.people_alt_rounded,
                      ),
                      _statCard(
                        value: "24",
                        title: "Sessions",
                        subtitle: "Attendance records",
                        icon: Icons.calendar_month_rounded,
                      ),
                      _statCard(
                        value: "87%",
                        title: "Attendance",
                        subtitle: "Overall rate",
                        icon: Icons.percent_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _sectionTitle(
                    "Quick Actions",
                    "Start your next task",
                  ),
                  const SizedBox(height: 12),
                  _quickAction(
                    title: "Add Course",
                    subtitle: "Create a new course",
                    icon: Icons.add_box_rounded,
                    onTap: onCourse,
                  ),
                  const SizedBox(height: 9),
                  _quickAction(
                    title: "Manage Students",
                    subtitle: "Add or update student records",
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: onStudent,
                  ),
                  const SizedBox(height: 9),
                  _quickAction(
                    title: "Take Attendance",
                    subtitle: "Record today's attendance",
                    icon: Icons.fact_check_rounded,
                    onTap: onAttendance,
                  ),
                  const SizedBox(height: 9),
                  _quickAction(
                    title: "View Reports",
                    subtitle: "Review attendance analytics",
                    icon: Icons.analytics_rounded,
                    onTap: onReport,
                  ),
                  const SizedBox(height: 25),
                  _sectionTitle(
                    "Student Insights",
                    "A quick view of academic records",
                  ),
                  const SizedBox(height: 12),
                  _insightCard(
                    value: "360°",
                    title: "Student Progress",
                    description: "Complete attendance context",
                    icon: Icons.track_changes_rounded,
                  ),
                  const SizedBox(height: 9),
                  _insightCard(
                    value: "24",
                    title: "Attendance Sessions",
                    description: "Recorded classroom sessions",
                    icon: Icons.timeline_rounded,
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 17,
                    ),
                    decoration: BoxDecoration(
                      color: dark,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xffBFDFFF),
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            "Your attendance data stays locally stored. Google Drive can be used as a backup and recovery layer when sync is enabled.",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
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
                  color: Dashboard.primary,
                  size: 25,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                color: Dashboard.primary,
                size: 25,
              ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final institutionController = TextEditingController();
  final departmentController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String photoPath = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileStore.instance.load();

    nameController.text = profile.name;
    institutionController.text = profile.institution;
    departmentController.text = profile.department;
    emailController.text = profile.email;
    phoneController.text = profile.phone;

    if (!mounted) return;
    setState(() {
      photoPath = profile.photoPath;
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 900,
      maxHeight: 900,
    );

    if (image == null) return;

    if (!mounted) return;
    setState(() {
      photoPath = image.path;
    });
  }

  Future<void> _saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      _message('Please enter your name.', error: true);
      return;
    }

    setState(() {
      saving = true;
    });

    await ProfileStore.instance.save(
      ProfileData(
        name: nameController.text.trim(),
        institution: institutionController.text.trim(),
        department: departmentController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        photoPath: photoPath,
      ),
    );

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    _message('Profile saved successfully.');

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xffC8E0FF),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xffC8E0FF),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    institutionController.dispose();
    departmentController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F9FF),
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                _ProfileAvatar(
                  path: photoPath,
                  size: 112,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Change Photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _field(
            controller: nameController,
            label: 'Name *',
            icon: Icons.person_outline,
          ),
          _field(
            controller: institutionController,
            label: 'Institution',
            icon: Icons.account_balance_outlined,
          ),
          _field(
            controller: departmentController,
            label: 'Department',
            icon: Icons.school_outlined,
          ),
          _field(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          _field(
            controller: phoneController,
            label: 'Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: saving ? null : _saveProfile,
              icon: saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class DriveSettingsPage extends StatefulWidget {
  const DriveSettingsPage({super.key});

  @override
  State<DriveSettingsPage> createState() => _DriveSettingsPageState();
}

class _DriveSettingsPageState extends State<DriveSettingsPage> {
  final GoogleDriveSyncService drive =
      GoogleDriveSyncService.instance;

  bool syncOn = false;
  bool busy = false;
  String status = 'Sync is OFF';

  @override
  void initState() {
    super.initState();
    _loadDriveState();
  }

  Future<void> _loadDriveState() async {
    try {
      await drive.initialize();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      syncOn = drive.isConnected;
      status = drive.isConnected
          ? 'Connected: ${drive.accountEmail ?? ''}'
          : 'Sync is OFF';
    });
  }

  Future<void> _setSync(bool value) async {
    if (busy) return;

    if (!value) {
      await drive.disconnect();

      if (!mounted) return;

      setState(() {
        syncOn = false;
        status = 'Sync is OFF';
      });
      return;
    }

    setState(() {
      busy = true;
      status = 'Connecting to Google...';
    });

    try {
      final account = await drive.connect();

      if (!mounted) return;

      setState(() {
        syncOn = true;
        busy = false;
        status = 'Connected: ${account.email}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Drive connected. Attendance folder is ready.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        syncOn = false;
        busy = false;
        status = 'Connection failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Drive connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ValueListenableBuilder<ProfileData>(
            valueListenable: ProfileStore.instance.notifier,
            builder: (context, profile, _) {
              return Card(
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  leading: _ProfileAvatar(
                    path: profile.photoPath,
                    size: 54,
                  ),
                  title: Text(
                    profile.name.trim().isEmpty
                        ? 'Set up your profile'
                        : profile.name.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    profile.department.trim().isEmpty
                        ? 'Add your profile information'
                        : profile.department.trim(),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfilePage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: SwitchListTile(
              secondary: const Icon(Icons.cloud_sync),
              title: const Text('Sync with Google Drive'),
              subtitle: Text(status),
              value: syncOn,
              onChanged: busy ? null : _setSync,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Data storage'),
              subtitle: const Text(
                'Local storage remains the primary storage. '
                'Google Drive is used for backup and recovery.',
              ),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  List<Course> courses = [];

  @override
  void initState() {
    super.initState();

    loadCourses();
  }

  Future<void> loadCourses() async {
    final data = await DatabaseHelper.instance.getCourses();

    print("TOTAL COURSE: ${data.length}");

    setState(() {
      courses = data;
    });
  }

  void addCourseDialog() {
    final codeController = TextEditingController();

    final nameController = TextEditingController();

    final semesterController = TextEditingController();

    final sectionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            "Add New Course",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: "Course Code",
                    prefixIcon: Icon(Icons.book),
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Course Name",
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                TextField(
                  controller: semesterController,
                  decoration: const InputDecoration(
                    labelText: "Semester",
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                ),
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
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                print("SAVE CLICKED");

                try {
                  final course = Course(
                    code: codeController.text.trim(),
                    name: nameController.text.trim(),
                    semester: semesterController.text.trim(),
                    section: sectionController.text.trim(),
                  );

                  print("COURSE DATA: ${course.toMap()}");

                  final id = await DatabaseHelper.instance.insertCourse(course);

                  print("INSERTED ID: $id");

                  Navigator.of(context).pop();

                  await loadCourses();

                  print("COURSE LOADED");
                } catch (e, s) {
                  print("ERROR: $e");

                  print(s);
                }
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
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
            child: courses.isEmpty
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(18),
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
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withValues(alpha: .15),
                            child: const Icon(
                              Icons.book,
                              color: Colors.blue,
                            ),
                          ),
                          title: Text(
                            course.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            "${course.name}\n${course.semester} | ${course.section}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              await DatabaseHelper.instance
                                  .deleteCourse(course.id!);

                              loadCourses();
                            },
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

Widget courseContextBanner({
  required Course? course,
  required int studentCount,
  required String title,
  required String subtitle,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff0B6EDC), Color(0xff1488E8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x220B6EDC),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.menu_book_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                course == null ? subtitle : '${course.code} • ${course.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffDCEEFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (course != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: Text(
              '$studentCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    ),
  );
}

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

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
        } else {
          if (selectedCourse != null) {
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
          content: Text(
            "${student['name']}\n"
            "${student['student_id']}",
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
                Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${t("ID", "আইডি")}: $studentId",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
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
                          courseContextBanner(
                            course: selectedCourse,
                            studentCount: students.length,
                            title: t("Students for selected course", "নির্বাচিত কোর্সের শিক্ষার্থী"),
                            subtitle: t("Select a course below to manage its roster.", "নিচে কোর্স নির্বাচন করে সেই কোর্সের শিক্ষার্থী পরিচালনা করুন।"),
                          ),

                          const SizedBox(height: 12),

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
                Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  "${t("ID", "আইডি")}: "
                  "$studentId",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
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

                          courseContextBanner(
                            course: selectedCourse,
                            studentCount: students.length,
                            title: t("Attendance for selected course", "নির্বাচিত কোর্সের উপস্থিতি"),
                            subtitle: t("Only students enrolled in this course are shown.", "শুধু এই কোর্সে থাকা শিক্ষার্থীরাই এখানে দেখানো হবে।"),
                          ),

                          const SizedBox(height: 12),

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
  // ============================================================
  // DATA
  // ============================================================

  List<Course> courses = [];

  Course? selectedCourse;

  List<Map<String, dynamic>> students = [];

  List<Map<String, dynamic>> attendanceRecords = [];

  bool loading = true;

  bool bangla = false;

  bool exportingPdf = false;

  bool exportingExcel = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadReport();
  }

  // ============================================================
  // LANGUAGE
  // ============================================================

  String t(String english, String banglaText) {
    return bangla ? banglaText : english;
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> loadReport() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      final courseData = await DatabaseHelper.instance.getCourses();

      if (!mounted) return;

      Course? course;

      if (courseData.isNotEmpty) {
        if (selectedCourse != null) {
          try {
            course = courseData.firstWhere(
              (item) => item.id == selectedCourse!.id,
            );
          } catch (_) {
            course = courseData.first;
          }
        } else {
          course = courseData.first;
        }
      }

      setState(() {
        courses = courseData;
        selectedCourse = course;
      });

      await loadCourseReport();

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        "${t(
          "Failed to load report",
          "রিপোর্ট লোড করা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // LOAD SELECTED COURSE REPORT
  // ============================================================

  Future<void> loadCourseReport() async {
    if (selectedCourse == null || selectedCourse!.id == null) {
      if (!mounted) return;

      setState(() {
        students = [];
        attendanceRecords = [];
      });

      return;
    }

    try {
      final studentData = await DatabaseHelper.instance.getStudents(
        selectedCourse!.id!,
      );

      final attendanceData = await DatabaseHelper.instance.getAttendance(
        selectedCourse!.id!,
      );

      if (!mounted) return;

      setState(() {
        students = studentData;
        attendanceRecords = attendanceData;
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        "${t(
          "Failed to load attendance data",
          "উপস্থিতির তথ্য লোড করা যায়নি",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // COURSE CHANGE
  // ============================================================

  Future<void> changeCourse(Course? course) async {
    if (course == null) return;

    setState(() {
      selectedCourse = course;

      students = [];

      attendanceRecords = [];

      loading = true;
    });

    await loadCourseReport();

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  // ============================================================
  // CHECK PRESENT STATUS
  //
  // Supports:
  // status: "present"
  // status: "absent"
  //
  // and:
  // present: true
  // present: false
  // ============================================================

  bool isPresent(Map<String, dynamic> record) {
    final status = record['status'];

    if (status != null) {
      final value = status.toString().trim().toLowerCase();

      if (value == 'present' || value == 'p' || value == 'true') {
        return true;
      }

      if (value == 'absent' || value == 'a' || value == 'false') {
        return false;
      }
    }

    final presentValue = record['present'];

    if (presentValue is bool) {
      return presentValue;
    }

    if (presentValue != null) {
      return presentValue.toString().trim().toLowerCase() == 'true';
    }

    return false;
  }

  // ============================================================
  // STUDENT DATABASE ID
  // ============================================================

  int? studentDatabaseId(
    Map<String, dynamic> student,
  ) {
    final value = student['id'];

    if (value is int) {
      return value;
    }

    if (value != null) {
      return int.tryParse(
        value.toString(),
      );
    }

    return null;
  }

  // ============================================================
  // STUDENT TOTAL CLASSES
  // ============================================================

  int studentTotalClasses(
    int studentId,
  ) {
    return attendanceRecords.where((record) {
      return record['student_id'] == studentId ||
          record['student_id']?.toString() == studentId.toString();
    }).length;
  }

  // ============================================================
  // PRESENT COUNT
  // ============================================================

  int studentPresentCount(
    int studentId,
  ) {
    return attendanceRecords.where((record) {
      final sameStudent = record['student_id'] == studentId ||
          record['student_id']?.toString() == studentId.toString();

      return sameStudent && isPresent(record);
    }).length;
  }

  // ============================================================
  // ABSENT COUNT
  // ============================================================

  int studentAbsentCount(
    int studentId,
  ) {
    return attendanceRecords.where((record) {
      final sameStudent = record['student_id'] == studentId ||
          record['student_id']?.toString() == studentId.toString();

      return sameStudent && !isPresent(record);
    }).length;
  }

  // ============================================================
  // STUDENT PERCENTAGE
  // ============================================================

  double studentPercentage(
    int studentId,
  ) {
    final total = studentTotalClasses(studentId);

    if (total == 0) {
      return 0;
    }

    final present = studentPresentCount(studentId);

    return (present / total) * 100;
  }

  // ============================================================
  // OVERALL PRESENT
  // ============================================================

  int get overallPresent {
    return attendanceRecords
        .where(
          (record) => isPresent(record),
        )
        .length;
  }

  // ============================================================
  // OVERALL ABSENT
  // ============================================================

  int get overallAbsent {
    return attendanceRecords
        .where(
          (record) => !isPresent(record),
        )
        .length;
  }

  // ============================================================
  // OVERALL PERCENTAGE
  // ============================================================

  double get overallPercentage {
    final total = overallPresent + overallAbsent;

    if (total == 0) {
      return 0;
    }

    return (overallPresent / total) * 100;
  }

  // ============================================================
  // TOTAL CLASS DATES
  // ============================================================

  int get totalClasses {
    final dates = <String>{};

    for (final record in attendanceRecords) {
      final date = record['date'];

      if (date != null && date.toString().trim().isNotEmpty) {
        dates.add(
          date.toString().trim(),
        );
      }
    }

    if (dates.isNotEmpty) {
      return dates.length;
    }

    /*
      Fallback:
      যদি attendance record-এ date field না থাকে,
      তাহলে distinct attendance sessions-এর বদলে
      student attendance records থেকে approximate
      class count বের করা হবে।
    */

    if (students.isEmpty) {
      return 0;
    }

    int maximum = 0;

    for (final student in students) {
      final id = studentDatabaseId(student);

      if (id == null) continue;

      final total = studentTotalClasses(id);

      if (total > maximum) {
        maximum = total;
      }
    }

    return maximum;
  }

  // ============================================================
  // PERCENTAGE TEXT
  // ============================================================

  String percentageText(
    double value,
  ) {
    return "${value.toStringAsFixed(1)}%";
  }

  // ============================================================
  // PERCENTAGE COLOR
  // ============================================================

  Color percentageColor(
    double value,
  ) {
    if (value >= 80) {
      return Colors.green;
    }

    if (value >= 60) {
      return Colors.orange;
    }

    return Colors.red;
  }

  // ============================================================
  // SHOW MESSAGE
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
        width: double.infinity,
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
          items: courses.map((course) {
            return DropdownMenuItem<Course>(
              value: course,
              child: Text(
                "${course.code} • ${course.name}",
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: changeCourse,
        ),
      ),
    );
  }

  // ============================================================
  // OVERALL CARD
  // ============================================================

  Widget overallCard() {
    final percentage = overallPercentage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff2563EB),
            Color(0xff06B6D4),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Text(
            t(
              "Overall Attendance",
              "সামগ্রিক উপস্থিতি",
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            percentageText(
              percentage,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 45,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                "${t("Present", "উপস্থিত")}: "
                "$overallPresent",
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              Text(
                "${t("Absent", "অনুপস্থিত")}: "
                "$overallAbsent",
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              Text(
                "${t("Classes", "ক্লাস")}: "
                "$totalClasses",
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT REPORT
  // ============================================================

  Widget studentReport(
    Map<String, dynamic> student,
  ) {
    final id = studentDatabaseId(student);

    if (id == null) {
      return const SizedBox.shrink();
    }

    final name = student['name']?.toString() ?? '';

    final studentId = student['student_id']?.toString() ?? '';

    final present = studentPresentCount(id);

    final absent = studentAbsentCount(id);

    final total = studentTotalClasses(id);

    final percentage = studentPercentage(id);

    final color = percentageColor(
      percentage,
    );

    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: color.withValues(alpha: .25),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .10),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: .15),
                child: Icon(
                  Icons.person,
                  color: color,
                ),
              ),
              const SizedBox(
                width: 15,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${t("ID", "আইডি")}: "
                      "$studentId",
                    ),
                  ],
                ),
              ),
              Text(
                percentageText(
                  percentage,
                ),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(
              10,
            ),
            color: color,
            backgroundColor: color.withValues(alpha: .15),
          ),
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              Expanded(
                child: reportCount(
                  t(
                    "Present",
                    "উপস্থিত",
                  ),
                  present,
                  Colors.green,
                ),
              ),
              Expanded(
                child: reportCount(
                  t(
                    "Absent",
                    "অনুপস্থিত",
                  ),
                  absent,
                  Colors.red,
                ),
              ),
              Expanded(
                child: reportCount(
                  t(
                    "Total",
                    "মোট",
                  ),
                  total,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPORT COUNT
  // ============================================================

  Widget reportCount(
    String title,
    int value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY REPORT
  // ============================================================

  Widget emptyReport() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.analytics_outlined,
            size: 60,
            color: Color(0xff94A3B8),
          ),
          const SizedBox(
            height: 15,
          ),
          Text(
            t(
              "No attendance data available.",
              "কোনো উপস্থিতির তথ্য পাওয়া যায়নি।",
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            t(
              "Save attendance first to generate reports.",
              "রিপোর্ট তৈরি করতে প্রথমে উপস্থিতি সংরক্ষণ করুন।",
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILE DATE
  // ============================================================

  String fileDate() {
    final now = DateTime.now();

    return "${now.year}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // SAFE FILE NAME
  // ============================================================

  String safeFileName(
    String value,
  ) {
    return value.replaceAll(
      RegExp(
        r'[\\/:*?"<>| ]',
      ),
      '_',
    );
  }

  // ============================================================
  // WEB DOWNLOAD
  //
  // IMPORTANT:
  // No path_provider.
  // No dart:io.
  // Works in FlutLab Web Emulator.
  // ============================================================
Future<void> downloadFile(
  List<int> bytes,
  String fileName,
  String mimeType,
) async {
  try {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      '${directory.path}/$fileName',
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: mimeType,
        ),
      ],
      text: fileName,
    );
  } catch (e) {
    debugPrint('Download/Share error: $e');
    throw Exception(
      'Could not save file: $e',
    );
  }
}
  // ============================================================
  // EXCEL EXPORT
  // ============================================================

  Future<void> exportExcel() async {
    if (selectedCourse == null) {
      showMessage(
        t(
          "Please select a course first.",
          "প্রথমে একটি কোর্স নির্বাচন করুন।",
        ),
        isError: true,
      );

      return;
    }

    if (students.isEmpty) {
      showMessage(
        t(
          "No student data available.",
          "কোনো শিক্ষার্থী তথ্য পাওয়া যায়নি।",
        ),
        isError: true,
      );

      return;
    }

    try {
      setState(() {
        exportingExcel = true;
      });

      final excel = Excel.createExcel();

      final sheet = excel['Attendance Report'];

      // --------------------------------------------------------
      // TITLE
      // --------------------------------------------------------

      sheet.merge(
        CellIndex.indexByString(
          'A1',
        ),
        CellIndex.indexByString(
          'F1',
        ),
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'A1',
            ),
          )
          .value = TextCellValue(
        'Attendance Report',
      );

      // --------------------------------------------------------
      // COURSE
      // --------------------------------------------------------

      sheet.merge(
        CellIndex.indexByString(
          'A2',
        ),
        CellIndex.indexByString(
          'F2',
        ),
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'A2',
            ),
          )
          .value = TextCellValue(
        "${selectedCourse!.code} - "
        "${selectedCourse!.name}",
      );

      // --------------------------------------------------------
      // SUMMARY
      // --------------------------------------------------------

      sheet
          .cell(
            CellIndex.indexByString(
              'A3',
            ),
          )
          .value = TextCellValue(
        'Overall Attendance',
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'B3',
            ),
          )
          .value = TextCellValue(
        percentageText(
          overallPercentage,
        ),
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'C3',
            ),
          )
          .value = TextCellValue(
        'Present',
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'D3',
            ),
          )
          .value = IntCellValue(
        overallPresent,
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'E3',
            ),
          )
          .value = TextCellValue(
        'Absent',
      );

      sheet
          .cell(
            CellIndex.indexByString(
              'F3',
            ),
          )
          .value = IntCellValue(
        overallAbsent,
      );

      // --------------------------------------------------------
      // HEADER
      // --------------------------------------------------------

      final headers = [
        'Student ID',
        'Student Name',
        'Present',
        'Absent',
        'Total Classes',
        'Attendance %',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: i,
                rowIndex: 4,
              ),
            )
            .value = TextCellValue(
          headers[i],
        );
      }

      // --------------------------------------------------------
      // STUDENT DATA
      // --------------------------------------------------------

      for (int i = 0; i < students.length; i++) {
        final student = students[i];

        final id = studentDatabaseId(
          student,
        );

        if (id == null) {
          continue;
        }

        final studentId = student['student_id']?.toString() ?? '';

        final name = student['name']?.toString() ?? '';

        final present = studentPresentCount(id);

        final absent = studentAbsentCount(id);

        final total = studentTotalClasses(id);

        final percentage = studentPercentage(id);

        final row = i + 5;

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: row,
              ),
            )
            .value = TextCellValue(
          studentId,
        );

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: row,
              ),
            )
            .value = TextCellValue(
          name,
        );

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 2,
                rowIndex: row,
              ),
            )
            .value = IntCellValue(
          present,
        );

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 3,
                rowIndex: row,
              ),
            )
            .value = IntCellValue(
          absent,
        );

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 4,
                rowIndex: row,
              ),
            )
            .value = IntCellValue(
          total,
        );

        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 5,
                rowIndex: row,
              ),
            )
            .value = TextCellValue(
          percentageText(
            percentage,
          ),
        );
      }

      // --------------------------------------------------------
      // ENCODE
      // --------------------------------------------------------

      final fileBytes = excel.encode();

      if (fileBytes == null) {
        throw Exception(
          'Could not generate Excel file.',
        );
      }

      // --------------------------------------------------------
      // DOWNLOAD
      // --------------------------------------------------------

      final courseCode = safeFileName(
        selectedCourse!.code,
      );

      final fileName = "Attendance_${courseCode}_${fileDate()}.xlsx";

      downloadFile(
        fileBytes,
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;

      setState(() {
        exportingExcel = false;
      });

      showMessage(
        t(
          "Excel report downloaded successfully.",
          "Excel রিপোর্ট সফলভাবে download হয়েছে।",
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        exportingExcel = false;
      });

      showMessage(
        "${t(
          "Excel export failed",
          "Excel export ব্যর্থ হয়েছে",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  Future<void> exportPdf() async {
    if (selectedCourse == null) {
      showMessage(
        t(
          "Please select a course first.",
          "প্রথমে একটি কোর্স নির্বাচন করুন।",
        ),
        isError: true,
      );

      return;
    }

    if (students.isEmpty) {
      showMessage(
        t(
          "No student data available.",
          "কোনো শিক্ষার্থী তথ্য পাওয়া যায়নি।",
        ),
        isError: true,
      );

      return;
    }

    try {
      setState(() {
        exportingPdf = true;
      });

      final pdf = pw.Document();

      final tableData = <List<String>>[
        [
          'Student ID',
          'Student Name',
          'Present',
          'Absent',
          'Total',
          'Attendance',
        ],
      ];

      for (final student in students) {
        final id = studentDatabaseId(
          student,
        );

        if (id == null) {
          continue;
        }

        final studentId = student['student_id']?.toString() ?? '';

        final name = student['name']?.toString() ?? '';

        final present = studentPresentCount(id);

        final absent = studentAbsentCount(id);

        final total = studentTotalClasses(id);

        final percentage = studentPercentage(id);

        tableData.add([
          studentId,
          name,
          present.toString(),
          absent.toString(),
          total.toString(),
          percentageText(
            percentage,
          ),
        ]);
      }

      // --------------------------------------------------------
      // PDF PAGE
      // --------------------------------------------------------

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(
            30,
          ),
          build: (context) {
            return [
              pw.Text(
                'Attendance Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(
                height: 8,
              ),

              pw.Text(
                "${selectedCourse!.code} - "
                "${selectedCourse!.name}",
                style: const pw.TextStyle(
                  fontSize: 14,
                ),
              ),

              pw.SizedBox(
                height: 20,
              ),

              // ------------------------------------------------
              // SUMMARY
              // ------------------------------------------------

              pw.Container(
                padding: const pw.EdgeInsets.all(
                  12,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey400,
                  ),
                  borderRadius: pw.BorderRadius.circular(
                    8,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Overall',
                        ),
                        pw.SizedBox(
                          height: 5,
                        ),
                        pw.Text(
                          percentageText(
                            overallPercentage,
                          ),
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Present',
                        ),
                        pw.SizedBox(
                          height: 5,
                        ),
                        pw.Text(
                          overallPresent.toString(),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Absent',
                        ),
                        pw.SizedBox(
                          height: 5,
                        ),
                        pw.Text(
                          overallAbsent.toString(),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Classes',
                        ),
                        pw.SizedBox(
                          height: 5,
                        ),
                        pw.Text(
                          totalClasses.toString(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(
                height: 20,
              ),

              // ------------------------------------------------
              // TABLE
              // ------------------------------------------------

              pw.TableHelper.fromTextArray(
                headers: tableData.first,
                data: tableData.skip(1).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 9,
                ),
                cellAlignment: pw.Alignment.center,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                ),
                cellPadding: const pw.EdgeInsets.all(
                  6,
                ),
              ),

              pw.SizedBox(
                height: 20,
              ),

              pw.Text(
                'Generated by Course Attendance Manager',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey,
                ),
              ),
            ];
          },
        ),
      );

      // --------------------------------------------------------
      // CREATE PDF
      // --------------------------------------------------------

      final bytes = await pdf.save();

      final courseCode = safeFileName(
        selectedCourse!.code,
      );

      final fileName = "Attendance_${courseCode}_${fileDate()}.pdf";

      // --------------------------------------------------------
      // WEB DOWNLOAD
      // --------------------------------------------------------

      downloadFile(
        bytes,
        fileName,
        'application/pdf',
      );

      if (!mounted) return;

      setState(() {
        exportingPdf = false;
      });

      showMessage(
        t(
          "PDF report downloaded successfully.",
          "PDF রিপোর্ট সফলভাবে download হয়েছে।",
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        exportingPdf = false;
      });

      showMessage(
        "${t(
          "PDF export failed",
          "PDF export ব্যর্থ হয়েছে",
        )}: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
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
                    Color(0xff7C3AED),
                    Color(0xffC026D3),
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
                            "Reports 📊",
                            "রিপোর্ট 📊",
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
                          t(
                            "Attendance analytics",
                            "উপস্থিতির বিশ্লেষণ",
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // LANGUAGE BUTTON

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
                        color: Colors.white.withValues(alpha: .18),
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
                      onRefresh: loadReport,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        children: [
                          // ====================================
                          // COURSE
                          // ====================================

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

                          courseContextBanner(
                            course: selectedCourse,
                            studentCount: students.length,
                            title: t("Report for selected course", "নির্বাচিত কোর্সের রিপোর্ট"),
                            subtitle: t("Attendance analytics are limited to this course.", "উপস্থিতির বিশ্লেষণ শুধু এই কোর্সের জন্য।"),
                          ),

                          const SizedBox(height: 12),

                          courseSelector(),

                          const SizedBox(
                            height: 20,
                          ),

                          // ====================================
                          // OVERALL
                          // ====================================

                          if (selectedCourse != null) overallCard(),

                          const SizedBox(
                            height: 25,
                          ),

                          // ====================================
                          // STUDENT PERFORMANCE
                          // ====================================

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t(
                                "Student Performance",
                                "শিক্ষার্থীদের পারফরম্যান্স",
                              ),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          if (students.isEmpty)
                            emptyReport()
                          else
                            ...students.map(
                              (
                                student,
                              ) {
                                return studentReport(
                                  student,
                                );
                              },
                            ),

                          const SizedBox(
                            height: 20,
                          ),

                          // ====================================
                          // EXPORT BUTTONS
                          // ====================================

                          Row(
                            children: [
                              // PDF

                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(
                                      15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        18,
                                      ),
                                    ),
                                  ),
                                  icon: exportingPdf
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.picture_as_pdf,
                                        ),
                                  label: Text(
                                    exportingPdf
                                        ? t(
                                            "Creating...",
                                            "তৈরি হচ্ছে...",
                                          )
                                        : "PDF",
                                  ),
                                  onPressed: exportingPdf || exportingExcel
                                      ? null
                                      : exportPdf,
                                ),
                              ),

                              const SizedBox(
                                width: 15,
                              ),

                              // EXCEL

                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(
                                      15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        18,
                                      ),
                                    ),
                                  ),
                                  icon: exportingExcel
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.table_chart,
                                        ),
                                  label: Text(
                                    exportingExcel
                                        ? t(
                                            "Creating...",
                                            "তৈরি হচ্ছে...",
                                          )
                                        : "Excel",
                                  ),
                                  onPressed: exportingPdf || exportingExcel
                                      ? null
                                      : exportExcel,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 20,
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
