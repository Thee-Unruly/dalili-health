import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/navigation/main_shell.dart';
import 'providers/navigation_provider.dart';
import 'providers/session_provider.dart';
import 'providers/document_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/offline_model_provider.dart';
import 'services/offline_ai_service.dart';
import 'services/guideline_index.dart';
import 'services/real_triage_service.dart';
import 'services/triage_service.dart';

void main() async {
  // 1. Ensure plugin services are native-bound
  WidgetsFlutterBinding.ensureInitialized();

  // 2. No DenizenAI.configure(): Dalili runs fully offline (no cloud config).

  // 3. Ensure Flutter binding and storage
  await Hive.initFlutter();
  await SharedPreferences.getInstance();

  // 4. Instantiate and initialize critical offline providers
  final docProvider = DocumentProvider();
  await docProvider.init();

  final modelProvider = OfflineModelProvider();
  await modelProvider.initialize();

  final sessionProvider = SessionProvider();
  await sessionProvider.init();

  // 5. Initialize Triage Infrastructure
  final aiService = OfflineAIService.instance;
  await aiService.initialize();
  final guidelineIndex = await GuidelineIndex.loadFromAssets();
  final triageService = RealTriageService(
    aiService: aiService,
    guidelineIndex: guidelineIndex,
  );

  // 4. Pass the fully baked providers directly into the App
  runApp(
    DaliliApp(
      docProvider: docProvider,
      modelProvider: modelProvider,
      sessionProvider: sessionProvider,
    ),
  );
}

class DaliliApp extends StatelessWidget {
  final DocumentProvider docProvider;
  final OfflineModelProvider modelProvider;
  final SessionProvider sessionProvider;

  const DaliliApp({
    super.key,
    required this.docProvider,
    required this.modelProvider,
    required this.sessionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider.value(value: sessionProvider),
        ChangeNotifierProvider.value(value: docProvider),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider.value(value: modelProvider),
      ],
      child: MaterialApp(
        title: 'Dalili',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Inter',
          scaffoldBackgroundColor: const Color(0xFF0D0F14),
        ),
        home: const MainShell(),
      ),
    );
  }
}