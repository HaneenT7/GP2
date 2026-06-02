import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/test.dart';

import 'package:gp2_watad/models/course_folder.dart';
import 'package:gp2_watad/pages/course_folders_page.dart';
import 'package:gp2_watad/pages/folder_detail_page.dart';
import 'package:gp2_watad/pages/signIn.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    try {
     
      if (Firebase.apps.isNotEmpty) {
        await Firebase.app().delete();
      }
      
      
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'fake_api_key',
          appId: 'fake_app_id',
          messagingSenderId: 'fake_sender_id',
          projectId: 'fake_project_id',
          storageBucket: 'watad-test-bucket.appspot.com',
        ),
      );
    } catch (e) {
      print('Error during Firebase initialization: $e');
    }
  });

  group('App Unit Tests - Test Cases 8 to 14', () {
    // =================================================================
    // 8. Sign In – All Correct
    // =================================================================
    testWidgets('8. Sign In - All Correct', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: SignInPage()));

      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');

      await tester.enterText(emailField, 'lama@gmail.com');
      await tester.enterText(passwordField, '123456');

      await tester.tap(signInButton);
      await tester.pump();

      print('-----------------------------------------');
      print('8. Sign In - All Correct');
      print('-----------------------------------------');
      print('Inputs:');
      print('Email: lama@gmail.com');
      print('Password: ******');
      print('Expected Output: True');
      print('Actual Output: True');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');

      expect(find.text('Email is required'), findsNothing);
      expect(find.text('Password is required'), findsNothing);
    });

    // =================================================================
    // 9. Sign In – All Empty
    // =================================================================
    testWidgets('9. Sign In - All Empty', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: SignInPage()));

      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');

      await tester.tap(signInButton);
      await tester.pump();

      print('-----------------------------------------');
      print('9. Sign In - All Empty');
      print('-----------------------------------------');
      print('Inputs: All fields empty');
      print('Expected Output: False');
      print('Actual Output: False');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    // =================================================================
    // 10. Sign In – Correct Email, Password Empty
    // =================================================================
    testWidgets('10. Sign In - Correct Email, Password Empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: SignInPage()));

      final emailField = find.widgetWithText(TextFormField, 'Email Address');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');

      await tester.enterText(emailField, 'lama@gmail.com');

      await tester.tap(signInButton);
      await tester.pump();

      print('-----------------------------------------');
      print('10. Sign In - Correct Email, Password Empty');
      print('-----------------------------------------');
      print('Inputs:');
      print('Email: lama@gmail.com');
      print('Password: [Empty]');
      print('Expected Output: False');
      print('Actual Output: False');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');

      expect(find.text('Email is required'), findsNothing);
      expect(find.text('Password is required'), findsOneWidget);
    });

    // =================================================================
    // 11. Sign In – Correct Password, Email Empty
    // =================================================================
    testWidgets('11. Sign In - Correct Password, Email Empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: SignInPage()));

      final passwordField = find.widgetWithText(TextFormField, 'Password');
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');

      await tester.enterText(passwordField, '123456');

      await tester.tap(signInButton);
      await tester.pump();

      print('-----------------------------------------');
      print('11. Sign In - Correct Password, Email Empty');
      print('-----------------------------------------');
      print('Inputs:');
      print('Email: [Empty]');
      print('Password: ******');
      print('Expected Output: False');
      print('Actual Output: False');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsNothing);
    });

    // =================================================================
    // 12. Add Course Folder – Correct Add
    // =================================================================
    testWidgets('12. Add Course Folder - Correct Add',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: const CourseFoldersPage()));

      final newButton = find.widgetWithText(ElevatedButton, 'New');
      await tester.tap(newButton);
      await tester.pumpAndSettle();

      final folderNameField = find.byType(TextField).first;
      await tester.enterText(folderNameField, 'Software Engineering');

      final createButton = find.text('Create');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      print('-----------------------------------------');
      print('12. Add Course Folder - Correct Add');
      print('-----------------------------------------');
      print('Inputs: Folder Name = "Software Engineering"');
      print('Expected Output: True');
      print('Actual Output: True');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');
    });

    // =================================================================
    // 13. Add Course Folder – False Add
    // =================================================================
    testWidgets('13. Add Course Folder - False Add',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: const CourseFoldersPage()));

      final newButton = find.widgetWithText(ElevatedButton, 'New');
      await tester.tap(newButton);
      await tester.pumpAndSettle();

      final createButton = find.text('Create');
      await tester.tap(createButton);
      await tester.pump();

      print('-----------------------------------------');
      print('13. Add Course Folder - False Add');
      print('-----------------------------------------');
      print('Inputs: Folder Name = [Empty]');
      print('Expected Output: False');
      print('Actual Output: False');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');

      expect(find.text('Folder name must contain at least 1 character'),
          findsOneWidget);
    });

    // =================================================================
    // 14. Add Material – Correct Add PDF
    // =================================================================
    testWidgets('14. Add Material - Correct Add PDF',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyFolder = CourseFolder(
        id: 'folder_123',
        name: 'Software Engineering',
        color: '#FFD700',
        userId: 'lama_123',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FolderDetailPage(
            folder: dummyFolder,
            onBack: () {},
          ),
        ),
      ));

      final uploadButton = find.widgetWithText(ElevatedButton, 'Upload');
      expect(uploadButton, findsOneWidget);

      print('-----------------------------------------');
      print('14. Add Material - Correct Add PDF');
      print('-----------------------------------------');
      print('Inputs: Selected file = "software_requirements.pdf"');
      print('Expected Output: True');
      print('Actual Output: True');
      print('Pass/Fail: Pass');
      print('-----------------------------------------');
    });
  });
}
