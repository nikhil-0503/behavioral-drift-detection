import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBxr2JcAersonCQhC7w1VhoNAvbX-Cpc0Y',
    authDomain: 'behavioraldrift.firebaseapp.com',
    projectId: 'behavioraldrift',
    storageBucket: 'behavioraldrift.firebasestorage.app',
    messagingSenderId: '245668768285',
    appId: '1:245668768285:web:63ba6e9f19fe85e745f4f4',
  );
}
