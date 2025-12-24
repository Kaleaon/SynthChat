import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/character_service.dart';
import 'services/chat_service.dart';
import 'services/room_service.dart';
import 'services/memory_branch_service.dart';
import 'services/document_parser_service.dart';
import 'services/personality_evolution_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/characters_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/character_edit_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/document_import_screen.dart';
import 'screens/personality_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  final dbService = DatabaseService();
  await dbService.init();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        ChangeNotifierProvider(create: (_) => AuthService(dbService)),
        ChangeNotifierProxyProvider<AuthService, CharacterService>(
          create: (context) => CharacterService(dbService),
          update: (context, auth, previous) {
            previous?.setUserId(auth.currentUser?.id);
            return previous ?? CharacterService(dbService);
          },
        ),
        ChangeNotifierProvider(create: (_) => ChatService(dbService)),
        // V2: Room service for collaborative interactions
        ChangeNotifierProvider(create: (_) => RoomService(dbService)),
        // V3: Memory branch service for conversation forking
        ChangeNotifierProvider(create: (_) => MemoryBranchService(dbService)),
        // V4: Document parser service for character creation
        ChangeNotifierProvider(create: (_) => DocumentParserService(dbService)),
        // V5: Personality evolution service
        ChangeNotifierProvider(create: (_) => PersonalityEvolutionService(dbService)),
      ],
      child: const SynthChatApp(),
    ),
  );
}

class SynthChatApp extends StatelessWidget {
  const SynthChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SynthChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/characters': (context) => const CharactersScreen(),
        '/chat': (context) => const ChatScreen(),
        '/character/edit': (context) => const CharacterEditScreen(),
        '/character/new': (context) => const CharacterEditScreen(isNew: true),
        // V2: Rooms for collaborative interactions
        '/rooms': (context) => const RoomsScreen(),
        // V4: Document import for character creation
        '/import': (context) => const DocumentImportScreen(),
        // V5: Personality evolution view
        '/personality': (context) => const PersonalityScreen(),
      },
    );
  }
}
