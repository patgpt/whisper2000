import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'features/home/ui/home_page.dart';
import 'features/recordings/ui/recordings_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'features/settings/viewmodel/settings_viewmodel.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables
  await dotenv.load(fileName: ".env");
  logger.info('.env file loaded.');

  // Initialize Hive
  await Hive.initFlutter();
  // Register TypeAdapter (available via recordings_page.dart)
  Hive.registerAdapter(RecordingAdapter());
  // Open Hive box for recordings
  await Hive.openBox<Recording>('recordings');

  // Wrap the entire app in a ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the FutureProvider defined in settings_viewmodel.dart
    final sharedPreferencesAsyncValue = ref.watch(sharedPreferencesProvider);

    // Handle loading/error states for SharedPreferences
    return sharedPreferencesAsyncValue.when(
      loading:
          () => const CupertinoApp(
            home: CupertinoPageScaffold(
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ),
      error:
          (err, stack) => CupertinoApp(
            home: CupertinoPageScaffold(
              child: Center(child: Text('Error loading settings: $err')),
            ),
          ),
      data: (_) {
        // Watch the auto-generated SettingsViewModel provider
        final isDarkMode = ref.watch(
          settingsViewModelProvider.select((s) => s.isDarkMode),
        );

        return CupertinoApp(
          title: 'EchoGhost',
          theme: isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: const MainAppScaffold(),
        );
      },
    );
  }
}

class MainAppScaffold extends StatelessWidget {
  const MainAppScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'Recordings',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        CupertinoTabView? returnValue;
        switch (index) {
          case 0:
            returnValue = CupertinoTabView(
              builder: (context) {
                return const CupertinoPageScaffold(child: HomePage());
              },
            );
            break;
          case 1:
            returnValue = CupertinoTabView(
              builder: (context) {
                return CupertinoPageScaffold(child: RecordingsPage());
              },
            );
            break;
          case 2:
            returnValue = CupertinoTabView(
              builder: (context) {
                return const CupertinoPageScaffold(child: SettingsPage());
              },
            );
            break;
        }
        // Default case or error handling could be added here
        return returnValue ??
            CupertinoTabView(
              builder: (context) {
                // Return a default view or handle error
                return const CupertinoPageScaffold(
                  child: Center(child: Text('Error')),
                );
              },
            );
      },
    );
  }
}
