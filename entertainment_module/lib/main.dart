import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/video_screen/user_data_cubit.dart'; 
import 'navigation_menu.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );
  };

  runApp(const IslamicApp());
}

class IslamicApp extends StatelessWidget {
  const IslamicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers:[
        BlocProvider<UserDataCubit>(
          create: (context) => UserDataCubit(),
        ),
      ],
      child: MaterialApp(
        title: 'Modern Islamic App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: const Color(0xFF1B5E20),
          scaffoldBackgroundColor: const Color(0xFFF1F8E9),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            primary: const Color(0xFF1B5E20),
            surface: Colors.white,
          ),
          textTheme: GoogleFonts.nunitoTextTheme(),
        ),
        home: const NavigationMenu(), 
      ),
    );
  }
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:[
            Color(0xFFFFFFFF), 
            Color(0xFFF1F8E9), 
          ],
        ),
      ),
      child: child,
    );
  }
}