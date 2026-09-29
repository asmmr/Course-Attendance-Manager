import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return instance;
  }

  static const String _coursesKey = 'courses_data';
  static const String _studentsKey = 'students_data';
  static const String _attendanceKey = 'attendance_data';

  // ============================================================
  // COURSE FUNCTIONS
  // ============================================================

  Future<int> insertCourse(Course course) async {
    final courses = await getCourses();

    int newId = 1;

    if (courses.isNotEmpty) {
      final ids = courses.where((c) => c.id != null).map((c) => c.id!).toList();

      if (ids.isNotEmpty) {
        newId = ids.reduce((a, b) => a > b ? a : b) + 1;
      }
    }

    final newCourse = Course(
      id: newId,
      code: course.code,
      name: course.name,
      semester: course.semester,
      section: course.section,
    );

    courses.add(newCourse);

    await _saveCourses(courses);

    return newId;
  }

  Future<List<Course>> getCourses() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_coursesKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);

      return decoded
          .map(
            (item) => Course.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (e) {
      print('Error loading courses: $e');
      return [];
    }
  }

  Future<Course?> getCourse(int id) async {
    final courses = await getCourses();

    try {
      return courses.firstWhere(
        (course) => course.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> updateCourse(Course course) async {
    if (course.id == null) {
      return 0;
    }

    final courses = await getCourses();

    final index = courses.indexWhere(
      (item) => item.id == course.id,
    );

    if (index == -1) {
      return 0;
    }

    courses[index] = course;

    await _saveCourses(courses);

    return 1;
  }

  Future<int> deleteCourse(int id) async {
    final courses = await getCourses();

    final oldLength = courses.length;

    courses.removeWhere(
      (course) => course.id == id,
    );

    if (courses.length == oldLength) {
      return 0;
    }

    await _saveCourses(courses);

    // Remove related students
    final students = await _getRawStudents();

    students.removeWhere(
      (student) => student['course_id'] == id,
    );

    await _saveRawStudents(students);

    // Remove related attendance
    final attendance = await _getRawAttendance();

    attendance.removeWhere(
      (item) => item['course_id'] == id,
    );

    await _saveRawAttendance(attendance);

    return 1;
  }

  Future<void> _saveCourses(
    List<Course> courses,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final data = courses.map((course) => course.toMap()).toList();

    await prefs.setString(
      _coursesKey,
      jsonEncode(data),
    );
  }

  // ============================================================
  // STUDENT FUNCTIONS
  // ============================================================

  /// Add a single student.
  ///
  /// Expected data:
  /// {
  ///   'student_id': 'CSE001',
  ///   'name': 'John Doe',
  ///   'course_id': 1
  /// }
  Future<int> insertStudent(
    Map<String, dynamic> student,
  ) async {
    final students = await _getRawStudents();

    final studentId = student['student_id']?.toString().trim() ?? '';

    final studentName = student['name']?.toString().trim() ?? '';

    if (studentId.isEmpty || studentName.isEmpty) {
      return 0;
    }

    final courseId = student['course_id'];

    // Duplicate check
    final duplicate = students.any(
      (item) {
        final sameStudentId =
            item['student_id']?.toString().trim().toLowerCase() ==
                studentId.toLowerCase();

        final sameCourse = item['course_id'] == courseId;

        return sameStudentId && sameCourse;
      },
    );

    if (duplicate) {
      return 0;
    }

    int newId = 1;

    if (students.isNotEmpty) {
      final ids = students
          .map(
            (e) => e['id'],
          )
          .whereType<int>()
          .toList();

      if (ids.isNotEmpty) {
        newId = ids.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;
      }
    }

    final newStudent = Map<String, dynamic>.from(student);

    newStudent['id'] = newId;
    newStudent['student_id'] = studentId;
    newStudent['name'] = studentName;

    students.add(newStudent);

    await _saveRawStudents(students);

    return newId;
  }

  // ------------------------------------------------------------
  // GET STUDENTS OF A COURSE
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getStudents(
    int courseId,
  ) async {
    final students = await _getRawStudents();

    final result = students
        .where(
          (student) => student['course_id'] == courseId,
        )
        .toList();

    result.sort(
      (a, b) => a['student_id'].toString().toLowerCase().compareTo(
            b['student_id'].toString().toLowerCase(),
          ),
    );

    return result;
  }

  // ------------------------------------------------------------
  // GET ALL STUDENTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final students = await _getRawStudents();

    students.sort(
      (a, b) => a['student_id'].toString().toLowerCase().compareTo(
            b['student_id'].toString().toLowerCase(),
          ),
    );

    return students;
  }

  // ------------------------------------------------------------
  // GET SINGLE STUDENT
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getStudent(
    int id,
  ) async {
    final students = await _getRawStudents();

    try {
      return students.firstWhere(
        (student) => student['id'] == id,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // UPDATE STUDENT
  // ------------------------------------------------------------

  Future<int> updateStudent(
    int id,
    Map<String, dynamic> student,
  ) async {
    final students = await _getRawStudents();

    final index = students.indexWhere(
      (item) => item['id'] == id,
    );

    if (index == -1) {
      return 0;
    }

    final studentId = student['student_id']?.toString().trim() ?? '';

    final studentName = student['name']?.toString().trim() ?? '';

    if (studentId.isEmpty || studentName.isEmpty) {
      return 0;
    }

    final courseId = student['course_id'];

    // Check duplicate student ID
    // except current student.
    final duplicate = students.any(
      (item) {
        if (item['id'] == id) {
          return false;
        }

        final sameStudentId =
            item['student_id']?.toString().trim().toLowerCase() ==
                studentId.toLowerCase();

        final sameCourse = item['course_id'] == courseId;

        return sameStudentId && sameCourse;
      },
    );

    if (duplicate) {
      return 0;
    }

    final updatedStudent = Map<String, dynamic>.from(student);

    updatedStudent['id'] = id;
    updatedStudent['student_id'] = studentId;
    updatedStudent['name'] = studentName;

    students[index] = updatedStudent;

    await _saveRawStudents(students);

    return 1;
  }

  // ------------------------------------------------------------
  // DELETE STUDENT
  // ------------------------------------------------------------

  Future<int> deleteStudent(int id) async {
    final students = await _getRawStudents();

    final oldLength = students.length;

    students.removeWhere(
      (student) => student['id'] == id,
    );

    if (students.length == oldLength) {
      return 0;
    }

    await _saveRawStudents(students);

    // Remove related attendance
    final attendance = await _getRawAttendance();

    attendance.removeWhere(
      (item) => item['student_id'] == id,
    );

    await _saveRawAttendance(attendance);

    return 1;
  }

  // ------------------------------------------------------------
  // SEARCH STUDENTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchStudents(
    String query, {
    int? courseId,
  }) async {
    final students =
        courseId == null ? await getAllStudents() : await getStudents(courseId);

    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return students;
    }

    return students.where(
      (student) {
        final studentId = student['student_id'].toString().toLowerCase();

        final name = student['name'].toString().toLowerCase();

        return studentId.contains(q) || name.contains(q);
      },
    ).toList();
  }

  // ------------------------------------------------------------
  // BULK INSERT STUDENTS
  // ------------------------------------------------------------

  Future<Map<String, int>> insertStudentsBulk(
    List<Map<String, dynamic>> newStudents,
  ) async {
    final students = await _getRawStudents();

    int added = 0;
    int skipped = 0;

    int nextId = 1;

    if (students.isNotEmpty) {
      final ids = students
          .map(
            (e) => e['id'],
          )
          .whereType<int>()
          .toList();

      if (ids.isNotEmpty) {
        nextId = ids.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;
      }
    }

    for (final item in newStudents) {
      final studentId = item['student_id']?.toString().trim() ?? '';

      final studentName = item['name']?.toString().trim() ?? '';

      if (studentId.isEmpty || studentName.isEmpty) {
        skipped++;
        continue;
      }

      final courseId = item['course_id'];

      // Duplicate check
      final duplicate = students.any(
        (existing) {
          final sameId =
              existing['student_id']?.toString().trim().toLowerCase() ==
                  studentId.toLowerCase();

          final sameCourse = existing['course_id'] == courseId;

          return sameId && sameCourse;
        },
      );

      if (duplicate) {
        skipped++;
        continue;
      }

      students.add({
        'id': nextId++,
        'student_id': studentId,
        'name': studentName,
        'course_id': courseId,
      });

      added++;
    }

    await _saveRawStudents(students);

    return {
      'added': added,
      'skipped': skipped,
    };
  }

  // ------------------------------------------------------------
  // STUDENT COUNT
  // ------------------------------------------------------------

  Future<int> getStudentCount({
    int? courseId,
  }) async {
    if (courseId == null) {
      final students = await getAllStudents();
      return students.length;
    }

    final students = await getStudents(courseId);
    return students.length;
  }

  // ------------------------------------------------------------
  // RAW STUDENT DATA
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getRawStudents() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_studentsKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);

      return decoded
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      print('Error loading students: $e');
      return [];
    }
  }

  Future<void> _saveRawStudents(
    List<Map<String, dynamic>> students,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _studentsKey,
      jsonEncode(students),
    );
  }

  // ============================================================
  // ATTENDANCE FUNCTIONS
  // ============================================================

  Future<int> insertAttendance(
    Map<String, dynamic> attendance,
  ) async {
    final records = await _getRawAttendance();

    int newId = 1;

    if (records.isNotEmpty) {
      final ids = records
          .map(
            (e) => e['id'],
          )
          .whereType<int>()
          .toList();

      if (ids.isNotEmpty) {
        newId = ids.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;
      }
    }

    final newRecord = Map<String, dynamic>.from(attendance);

    newRecord['id'] = newId;

    records.add(newRecord);

    await _saveRawAttendance(records);

    return newId;
  }

  Future<int> saveOrUpdateAttendance(
    Map<String, dynamic> attendance,
  ) async {
    final records = await _getRawAttendance();

    final courseId = attendance['course_id'];
    final studentId = attendance['student_id'];
    final date = attendance['date'];

    // Find existing attendance for:
    // Course + Student + Date
    final index = records.indexWhere(
      (record) =>
          record['course_id'] == courseId &&
          record['student_id'] == studentId &&
          record['date'] == date,
    );

    // ==========================================================
    // EXISTING RECORD FOUND -> OVERWRITE
    // ==========================================================

    if (index != -1) {
      final existingId = records[index]['id'];

      final updatedRecord = Map<String, dynamic>.from(attendance);

      updatedRecord['id'] = existingId;

      records[index] = updatedRecord;

      await _saveRawAttendance(records);

      return existingId is int ? existingId : 0;
    }

    // ==========================================================
    // NO EXISTING RECORD -> INSERT NEW
    // ==========================================================

    int newId = 1;

    if (records.isNotEmpty) {
      final ids = records.map((e) => e['id']).whereType<int>().toList();

      if (ids.isNotEmpty) {
        newId = ids.reduce(
              (a, b) => a > b ? a : b,
            ) +
            1;
      }
    }

    final newRecord = Map<String, dynamic>.from(attendance);

    newRecord['id'] = newId;

    records.add(newRecord);

    await _saveRawAttendance(records);

    return newId;
  }

  Future<List<Map<String, dynamic>>> getAttendance(
    int courseId,
  ) async {
    final records = await _getRawAttendance();

    return records
        .where(
          (item) => item['course_id'] == courseId,
        )
        .toList();
  }

  // ------------------------------------------------------------
  // GET ATTENDANCE FOR STUDENT
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getStudentAttendance(
    int studentId,
  ) async {
    final records = await _getRawAttendance();

    return records
        .where(
          (item) => item['student_id'] == studentId,
        )
        .toList();
  }

  // ------------------------------------------------------------
  // RAW ATTENDANCE
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getRawAttendance() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_attendanceKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);

      return decoded
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      print('Error loading attendance: $e');
      return [];
    }
  }

  Future<void> _saveRawAttendance(
    List<Map<String, dynamic>> attendance,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _attendanceKey,
      jsonEncode(attendance),
    );
  }

  // ============================================================
  // COUNTS
  // ============================================================

  Future<int> getCourseCount() async {
    final courses = await getCourses();
    return courses.length;
  }

  // ============================================================
  // CLEAR DATA
  // ============================================================

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_coursesKey);
    await prefs.remove(_studentsKey);
    await prefs.remove(_attendanceKey);
  }

  Future<void> clearStudents() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_studentsKey);
  }

  Future<void> clearAttendance() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_attendanceKey);
  }

  Future<void> clearCourses() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_coursesKey);
  }
}
