import 'package:flutter_test/flutter_test.dart';
import 'package:mailmind/core/config/app_env.dart';
import 'package:mailmind/features/auth/controllers/auth_controller.dart';
import 'package:mailmind/main.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MailMindApp renders LoginScreen with branding', (WidgetTester tester) async {
    await AppEnv.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
        ],
        child: const MailMindApp(),
      ),
    );

    // Verify Mail Chat logo/text is displayed
    expect(find.text('Mail Chat'), findsWidgets);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
