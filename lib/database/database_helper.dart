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
  static const String _assessmentsKey = 'assessments_data';
  static const String _marksKey = 'marks_data';

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
      createdAt: DateTime.now(),
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

      final courses = <Course>[];
      var migrated = false;

      for (var index = 0; index < decoded.length; index++) {
        final raw = Map<String, dynamic>.from(decoded[index]);
        if (raw['created_at'] == null ||
            raw['created_at'].toString().trim().isEmpty) {
          // Older course records did not store creation time. Preserve their
          // existing insertion order while assigning a stable legacy date.
          raw['created_at'] = DateTime(2000, 1, 1)
              .add(Duration(seconds: index))
              .toIso8601String();
          migrated = true;
        }
        courses.add(Course.fromMap(raw));
      }

      // Newest-created course first throughout the application.
      courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (migrated) {
        await _saveCourses(courses);
      }

      return courses;
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

    // Remove related assessments and their marks
    final prefs = await SharedPreferences.getInstance();
    final assessmentData = prefs.getString(_assessmentsKey);
    if (assessmentData != null && assessmentData.isNotEmpty) {
      final assessments = (jsonDecode(assessmentData) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final deletedAssessmentIds = assessments
          .where((a) => a['course_id'] == id)
          .map((a) => a['id'])
          .toSet();
      assessments.removeWhere((a) => a['course_id'] == id);
      await prefs.setString(_assessmentsKey, jsonEncode(assessments));

      final marksData = prefs.getString(_marksKey);
      if (marksData != null && marksData.isNotEmpty) {
        final marks = (jsonDecode(marksData) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .where((m) => !deletedAssessmentIds.contains(m['assessment_id']))
            .toList();
        await prefs.setString(_marksKey, jsonEncode(marks));
      }
    }

    // Remove course-specific assessment conversion settings as well.
    final conversionData = prefs.getString(_assessmentConversionsKey);
    if (conversionData != null && conversionData.isNotEmpty) {
      try {
        final conversions =
            Map<String, dynamic>.from(jsonDecode(conversionData) as Map);
        conversions.remove(id.toString());
        await prefs.setString(
            _assessmentConversionsKey, jsonEncode(conversions));
      } catch (_) {
        // Ignore malformed legacy conversion data.
      }
    }

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

    result.sort(_compareStudentRolls);

    return result;
  }


  // Numeric student IDs/rolls are ordered numerically. For IDs that contain
  // letters, a case-insensitive lexical order is used as a safe fallback.
  int _compareStudentRolls(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aText = a['student_id']?.toString().trim() ?? '';
    final bText = b['student_id']?.toString().trim() ?? '';

    final aNumber = int.tryParse(aText);
    final bNumber = int.tryParse(bText);

    if (aNumber != null && bNumber != null) {
      return aNumber.compareTo(bNumber);
    }

    return aText.toLowerCase().compareTo(bText.toLowerCase());
  }

  // ------------------------------------------------------------
  // GET ALL STUDENTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final students = await _getRawStudents();

    students.sort(_compareStudentRolls);

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
  // MARKS / ASSESSMENT FUNCTIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAssessments(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_assessmentsKey);
    if (data == null || data.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(data);
      final result = decoded
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['course_id'] == courseId)
          .toList();

      result.sort((a, b) =>
          (a['id'] as int? ?? 0).compareTo(b['id'] as int? ?? 0));
      return result;
    } catch (e) {
      print('Error loading assessments: $e');
      return [];
    }
  }

  Future<int> insertAssessment(Map<String, dynamic> assessment) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_assessmentsKey);
    final List<Map<String, dynamic>> items = data == null || data.isEmpty
        ? []
        : (jsonDecode(data) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final courseId = assessment['course_id'];
    final name = assessment['name']?.toString().trim() ?? '';
    final type = assessment['type']?.toString().trim() ?? '';
    final outOf = (assessment['out_of'] as num?)?.toDouble();

    if (courseId == null || name.isEmpty || type.isEmpty || outOf == null || outOf < 0) {
      return 0;
    }

    final duplicate = items.any((e) =>
        e['course_id'] == courseId &&
        e['name'].toString().trim().toLowerCase() == name.toLowerCase());
    if (duplicate) return 0;

    int nextId = 1;
    if (items.isNotEmpty) {
      final ids = items.map((e) => e['id']).whereType<int>().toList();
      if (ids.isNotEmpty) nextId = ids.reduce((a, b) => a > b ? a : b) + 1;
    }

    items.add({
      'id': nextId,
      'course_id': courseId,
      'type': type,
      'name': name,
      'out_of': outOf,
    });
    await prefs.setString(_assessmentsKey, jsonEncode(items));
    return nextId;
  }

  Future<int> updateAssessment(Map<String, dynamic> assessment) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_assessmentsKey);
    if (data == null || data.isEmpty) return 0;

    final items = (jsonDecode(data) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final id = assessment['id'];
    final index = items.indexWhere((e) => e['id'] == id);
    if (index == -1) return 0;

    final outOf = (assessment['out_of'] as num?)?.toDouble();
    if (outOf == null || outOf < 0) return 0;

    final duplicate = items.any((e) =>
        e['id'] != id &&
        e['course_id'] == assessment['course_id'] &&
        e['name'].toString().trim().toLowerCase() ==
            assessment['name'].toString().trim().toLowerCase());
    if (duplicate) return 0;

    // Do not allow lowering Out Of below an existing mark.
    final marks = await getMarks(id as int);
    final hasInvalid = marks.any((m) {
      final value = (m['marks'] as num?)?.toDouble() ?? 0;
      return value > outOf;
    });
    if (hasInvalid) return -1;

    items[index] = {
      'id': id,
      'course_id': assessment['course_id'],
      'type': assessment['type'],
      'name': assessment['name'],
      'out_of': outOf,
    };
    await prefs.setString(_assessmentsKey, jsonEncode(items));
    return 1;
  }

  Future<int> deleteAssessment(int assessmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_assessmentsKey);
    if (data == null || data.isEmpty) return 0;

    final items = (jsonDecode(data) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final oldLength = items.length;
    items.removeWhere((e) => e['id'] == assessmentId);
    if (items.length == oldLength) return 0;

    await prefs.setString(_assessmentsKey, jsonEncode(items));

    final marksData = prefs.getString(_marksKey);
    if (marksData != null && marksData.isNotEmpty) {
      final marks = (jsonDecode(marksData) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['assessment_id'] != assessmentId)
          .toList();
      await prefs.setString(_marksKey, jsonEncode(marks));
    }
    return 1;
  }

  Future<List<Map<String, dynamic>>> getMarks(int assessmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_marksKey);
    if (data == null || data.isEmpty) return [];

    try {
      return (jsonDecode(data) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['assessment_id'] == assessmentId)
          .toList();
    } catch (e) {
      print('Error loading marks: $e');
      return [];
    }
  }

  Future<int> saveMarksBulk(
      int assessmentId, List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();

    // Validate against the assessment's Out Of value at the data layer too.
    // The UI performs the same validation, but keeping this check here prevents
    // invalid marks from being stored by any other caller.
    final assessmentData = prefs.getString(_assessmentsKey);
    if (assessmentData == null || assessmentData.isEmpty) return 0;

    final assessmentItems = (jsonDecode(assessmentData) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final assessmentIndex =
        assessmentItems.indexWhere((e) => e['id'] == assessmentId);
    if (assessmentIndex == -1) return 0;

    final outOf = (assessmentItems[assessmentIndex]['out_of'] as num?)?.toDouble();
    if (outOf == null || outOf <= 0) return 0;

    final data = prefs.getString(_marksKey);
    final marks = data == null || data.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(data) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    // Validate the complete batch before modifying any existing record.
    for (final entry in entries) {
      final studentId = entry['student_id'];
      final status = entry['status'] == 'Absent' ? 'Absent' : 'Present';
      final value = status == 'Absent'
          ? 0.0
          : (entry['marks'] as num?)?.toDouble();

      if (studentId == null || value == null || value < 0 || value > outOf) {
        return 0;
      }
    }

    for (final entry in entries) {
      final studentId = entry['student_id'];
      final status = entry['status'] == 'Absent' ? 'Absent' : 'Present';
      final value = status == 'Absent'
          ? 0.0
          : (entry['marks'] as num?)?.toDouble();

      if (studentId == null || value == null) return 0;

      final index = marks.indexWhere((m) =>
          m['assessment_id'] == assessmentId &&
          m['student_id'] == studentId);

      final record = {
        'assessment_id': assessmentId,
        'student_id': studentId,
        'status': status,
        'marks': value,
      };

      if (index == -1) {
        marks.add(record);
      } else {
        marks[index] = record;
      }
    }

    await prefs.setString(_marksKey, jsonEncode(marks));
    return 1;
  }


  // ============================================================
  // ASSESSMENT CONVERSION SETTINGS
  // ============================================================

  static const String _assessmentConversionsKey =
      'assessment_conversions_data';

  Future<Map<String, double>> getAssessmentConversions(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_assessmentConversionsKey);
    if (data == null || data.isEmpty) return {};

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final courseData = decoded[courseId.toString()];
      if (courseData is! Map) return {};

      final result = <String, double>{};
      courseData.forEach((key, value) {
        final number = value is num
            ? value.toDouble()
            : double.tryParse(value.toString());
        if (number != null && number > 0) {
          result[key.toString()] = number;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAssessmentConversions(
      int courseId, Map<String, double> conversions) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_assessmentConversionsKey);

    Map<String, dynamic> all = {};
    if (data != null && data.isNotEmpty) {
      try {
        all = Map<String, dynamic>.from(jsonDecode(data) as Map);
      } catch (_) {
        all = {};
      }
    }

    all[courseId.toString()] = conversions;
    await prefs.setString(_assessmentConversionsKey, jsonEncode(all));
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
    await prefs.remove(_assessmentsKey);
    await prefs.remove(_marksKey);
    await prefs.remove(_assessmentConversionsKey);
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
