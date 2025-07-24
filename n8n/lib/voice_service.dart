import 'package:speech_to_text/speech_to_text.dart' as stt;

class AppLangConfig {
  static const ttsLocale = 'id-ID';
  static const sttLocale = 'id_ID';
}

class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  Future<void> initialize() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        print("🎙️ STT status: $status");
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
      onError: (error) {
        print('❌ STT Error: $error');
      },
    );

    _isAvailable = available;

    final locales = await _speech.locales();
    print("🎙️ Bahasa STT tersedia: ${locales.map((e) => e.localeId).toList()}");

    if (_isAvailable) {
      print("✅ STT siap digunakan dengan bahasa ${AppLangConfig.sttLocale}");
    } else {
      print("❌ STT tidak tersedia di perangkat ini.");
    }
  }

  void startListening({required Function(String) onResult}) {
    if (!_isAvailable || _isListening) return;

    _isListening = true;
    print("🎙️ STT Mulai mendengarkan... (${AppLangConfig.sttLocale})");
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          print("🎤 STT Hasil: ${result.recognizedWords}");
          onResult(result.recognizedWords);
        }
      },
      localeId: AppLangConfig.sttLocale,
    );
  }

  Future<void> stopListening() async {
    if (_isListening) {
      print("🛑 STT Berhenti mendengarkan");
      await _speech.stop();
      _isListening = false;
    }
  }

  void dispose() {
    _speech.stop();
  }
}
