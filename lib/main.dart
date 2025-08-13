import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:codecraft_project/models/user.dart';
import 'package:codecraft_project/services/auth.dart';
import 'package:codecraft_project/Screens/Menu/splash_screen.dart';
import 'package:codecraft_project/Screens/Menu/level_selection.dart';
import 'package:codecraft_project/Screens/Menu/level_selection2.dart';
import 'package:codecraft_project/Screens/Menu/change_password.dart';
import 'package:codecraft_project/Screens/Menu/you.dart';
import 'package:codecraft_project/Screens/Menu/menu.dart';
import 'package:codecraft_project/Screens/Menu/sertifikat_selection.dart';
import 'package:codecraft_project/Screens/Level/Sertifikat/2025/sertifikat_download.dart';
import 'package:codecraft_project/Screens/Level/Sertifikat/2025/1.dart';
import 'package:codecraft_project/Screens/Menu/laporan_progress.dart';
import 'package:codecraft_project/Screens/Level/Looping/1.dart';
import 'package:codecraft_project/Screens/Level/Looping/2.dart';
import 'package:codecraft_project/Screens/Level/Looping/3.dart';
import 'package:codecraft_project/Screens/Level/Looping/4.dart';
import 'package:codecraft_project/Screens/Level/Looping/5.dart';
import 'package:codecraft_project/Screens/Level/If/6.dart';
import 'package:codecraft_project/Screens/Level/If/7.dart';
import 'package:codecraft_project/Screens/Level/If/8.dart';
import 'package:codecraft_project/Screens/Level/If/9.dart';
import 'package:codecraft_project/Screens/Level/If/10.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (e) {
    print('Error  $e');
  }

  await Firebase.initializeApp();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<AppUser?>.value(
      value: AuthService().user,
      initialData: null,
      catchError: (_, __) => null,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/level_selection': (context) => const LevelSelectorScreen(),
          '/level1': (context) => LevelOneScreen(), 
          '/level2': (context) => LevelTwoScreen(),
          '/level3': (context) => LevelThreeScreen(),
          '/level4': (context) => LevelFourScreen(),
          '/level5': (context) => LevelFiveScreen(),
          '/level6': (context) => LevelSixScreen(),
          '/level7': (context) => LevelSevenScreen(),
          '/level8': (context) => LevelEightScreen(),
          '/level9': (context) => LevelNineScreen(),
          '/level10': (context) => LevelTenScreen(),
          '/sertif_download': (context) => SertifikatDownloadScreen(),
          '/sertifikat2025_1': (context) => const SertifikatScreen(),
          '/menu' : (context) => WelcomeScreen(),
          '/you': (context) => const ProfileScreen(),
          '/change_password': (context) => const ChangePasswordScreen(),
          '/level_selection2': (context) => const LevelSelectorScreen2(),
          '/sertifikat_selection': (context) => const SertifikatSelectionScreen(),
          '/laporan_progress': (context) => const LaporanProgressScreen(),

        },
      ),
    );
  }
}
