import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/app.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_local_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Almacenamiento local de los registros de revisión: se abre una vez aquí
  // para que el repositorio sea síncrono. Si falla no tumba la app: el
  // repositorio queda "no disponible" y el panel muestra el error.
  final reviewStorage = await ReviewLocalDatasource.open();

  runApp(
    ProviderScope(
      overrides: [reviewLocalStorageProvider.overrideWithValue(reviewStorage)],
      child: const WhatsAppMonitorApp(),
    ),
  );
}
