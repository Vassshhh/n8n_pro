// Import library yang digunakan
import 'dart:ui'; // Untuk efek blur
import 'voice_service.dart'; // Layanan TTS & STT kustom
import 'package:flutter/material.dart'; // UI framework utama
import 'package:http/http.dart' as http; // Untuk HTTP request
import 'dart:convert'; // Untuk encode/decode JSON
import 'package:path_provider/path_provider.dart'; // Akses direktori
import 'package:audioplayers/audioplayers.dart'; // Untuk memutar audio
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'pengaduan_page.dart';
import 'package:uuid/uuid.dart';

// Fungsi utama aplikasi Flutter
void main() {
  runApp(const MyApp());
}

// Widget utama yang menjalankan MaterialApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'n8n AI Chat Pro',
      debugShowCheckedModeBanner: false, // Menghilangkan banner debug
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color.fromARGB(255, 255, 255, 255),
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        fontFamily: 'Poppins', // Mengatur font global
      ),
      home: const N8nChatPage(), // Halaman utama chat
    );
  }
}

// Halaman utama chat
class N8nChatPage extends StatefulWidget {
  const N8nChatPage({super.key});

  @override
  State<N8nChatPage> createState() => _N8nChatPageState();
}

// State untuk menangani logika dan UI halaman chat
class _N8nChatPageState extends State<N8nChatPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController(); // Untuk input teks
  final ScrollController _scrollController = ScrollController(); // Scroll list chat
  final SttService _sttService = SttService(); // Service untuk speech-to-text
  final List<_ChatMessage> _messages = []; // Daftar pesan
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = false; // Status loading saat request
  bool _isRecording = false; // Status mic merekam
  bool _showFloatingMenu = false;
  List<String> _recommendations = []; // Rekomendasi pertanyaan
  late String _sessionId;
  Uint8List? _lastImageBytes; // Menyimpan gambar terakhir yang dikirim

  final String webhookUrl = 'https://bot.kediritechnopark.com/webhook/base';

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4(); // Gunakan UUID package, atau custom string
    _sttService.initialize(); // Inisialisasi STT
    _controller.addListener(() => setState(() {}));
    _audioPlayer = AudioPlayer();

    final greetingMessage = _ChatMessage(
  text: 'Halo, saya Mbak Wali 👩🏻‍💼.\n'
      'Silakan tanya apa saja seputar Kota Kediri — mulai dari UMKM, wisata, sampai layanan untuk masyarakat. Saya akan bantu semampu saya.',
  isUser: false,
  controller: _createAnimationController(),
  quickReplies: [
    'Wisata apa yang wajib dikunjungi di Kediri?',
    'Ada berapa jumlah keseluruhan umkm yang ada di Kediri?',
    'Apa destinasi kuliner terkenal di Kediri?',
  ],
);


setState(() {
  _messages.add(greetingMessage);
});

    // Listener perubahan status pemutar audio
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.playing) {
        print('Audio started playing');
      } else if (state == PlayerState.completed) {
        print('Audio completed');
      } else if (state == PlayerState.stopped) {
        print('Audio stopped');
      }
    });
  }

  @override
  void dispose() {
    // Hentikan semua resource saat widget dihancurkan
    _audioPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _sttService.dispose();
    super.dispose();
  }

  void _handleQuickReply(String reply) {
  _askQuestion(reply);
}


  // Fungsi untuk mengirim pertanyaan ke webhook dan menangani respons
  Future<void> _askQuestion(String question) async {
  if (question.trim().isEmpty) return;

  void _handleQuickReply(String reply) {
  _askQuestion(reply);
}


  setState(() {
    _loading = true;
    _messages.add(
      _ChatMessage(
        text: question,
        isUser: true,
        controller: _createAnimationController(),
      ),
    );
  });

  _controller.clear();
  _scrollToBottom();

  final body = {
  'pertanyaan': question,
  'sessionId': _sessionId, // Tambahkan sessionId
};


  // Jika ada gambar sebelumnya, sertakan
  if (_lastImageBytes != null) {
    final base64Image = base64Encode(_lastImageBytes!);
    body['foto'] = 'data:image/png;base64,$base64Image';
    _lastImageBytes = null; // Reset agar tidak dikirim terus-menerus
  }


  try {
    final res = await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      final answerText = data['textPict'] ?? data['text'] ?? 'Tidak ada jawaban.';
      final audioBase64 = data['audioBase64'];
      final rawRecommendation = data['AskRecommendation'];

      List<String> recommendations = [];
      if (rawRecommendation != null && rawRecommendation is String) {
        recommendations = rawRecommendation
            .split('\n')
            .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: answerText,
            isUser: false,
            controller: _createAnimationController(),
          ),
        );
      });

      if (audioBase64 != null &&
          audioBase64 != 'NO_AUDIO_FOUND' &&
          audioBase64.isNotEmpty &&
          audioBase64.startsWith('data:audio/')) {
        final base64Str = audioBase64.split(',').last;
        final bytes = base64Decode(base64Str);
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(bytes), volume: 1.0);
      }
    } else {
      print('Server error: ${res.statusCode}');
    }
  } catch (e) {
    print('Request error: $e');
  } finally {
    setState(() {
      _loading = false;
    });
    _scrollToBottom();
  }
}

  // Membuat controller animasi pesan masuk
  AnimationController _createAnimationController() {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    controller.forward();
    return controller;
  }

  // Scroll otomatis ke bawah
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  

// Memilih gambar dari kamera atau galeri
Future<void> _showImageSourceDialog() async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
  leading: const Icon(Icons.report_problem, color: Color.fromARGB(255, 0, 0, 0)),
  title: const Text('Pengaduan'),
  onTap: () {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PengaduanPage()),
    );
  },
),
          ],
        ),
      );
    },
  );
}

Future<void> _pickImageFromSource(ImageSource source) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: source);

  if (pickedFile != null) {
    try {
      final bytes = await pickedFile.readAsBytes();
      _lastImageBytes = bytes;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: '',
            isUser: true,
            controller: _createAnimationController(),
            imageBytes: bytes,
          ),
        );
      });

      print("Gambar berhasil dipilih, tunggu perintah user...");
    } catch (e) {
      print("Error saat membaca gambar: $e");
    }
  }
}
  // Reset semua chat & animasi
  void _resetChat() {
    setState(() {
      for (var m in _messages) {
        m.controller.dispose();
      }
      _messages.clear();
      _controller.clear();
      _recommendations.clear();
    });
  }

  // Widget individual pesan chat
 Widget _buildMessage(_ChatMessage message) {
  final isUser = message.isUser;

  return FadeTransition(
    opacity: message.controller.drive(
      Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
    ),
    child: SlideTransition(
      position: message.controller.drive(
        Tween<Offset>(
          begin: isUser ? const Offset(1, 0) : const Offset(-1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment:
                isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(18),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              decoration: BoxDecoration(
                color: isUser ? const Color.fromARGB(255, 255, 255, 255) : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 90, 90, 90)
                        .withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: message.imageBytes != null
                  ? Image.memory(
                      message.imageBytes!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    )
                  : Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: isUser ? const Color.fromARGB(255, 0, 0, 0) : Colors.black87,
                        height: 1.3,
                      ),
                    ),
            ),
          ),

          // Tambahkan ini untuk quick replies (jika ada)
          if (message.quickReplies != null &&
              message.quickReplies!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: message.quickReplies!.map((reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: () => _handleQuickReply(reply),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          foregroundColor: const Color.fromARGB(255, 0, 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(reply),
      ),
    );
  }).toList(),
)

            ),
        ],
      ),
    ),
  );
}

Widget _buildFloatingMenu() {
  return Positioned(
    bottom: 80,
    left: 24, // ⬅️ Posisi di kiri bawah
    child: Row(
      children: [
        // Tombol utama (ikon >)
        FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          elevation: 3,
          onPressed: () {
            setState(() {
              _showFloatingMenu = !_showFloatingMenu;
            });
          },
          child: Icon(
            Icons.chevron_right, // ⬅️ Ikon >
            color: Colors.black87,
          ),
        ),

        // Menu horizontal muncul saat _showFloatingMenu = true
        if (_showFloatingMenu)
          const SizedBox(width: 12), // Jarak antar tombol
        if (_showFloatingMenu)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.report_problem, color: Colors.black),
                  tooltip: 'Pengaduan',
                  onPressed: () {
                    setState(() => _showFloatingMenu = false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PengaduanPage()),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    ),
  );
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    key: _scaffoldKey,
    drawer: _buildSidebar(),
    body: SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_showFloatingMenu) {
            setState(() {
              _showFloatingMenu = false;
            });
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeaderCustom(),
                Expanded(child: _buildBody()),
              ],
            ),

            // Floating menu kiri bawah
            Positioned(
              bottom: 80,
              left: 24,
              child: Row(
                children: [
                  // Tombol ikon >
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    elevation: 3,
                    onPressed: () {
                      setState(() {
                        _showFloatingMenu = !_showFloatingMenu;
                      });
                    },
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.black87,
                    ),
                  ),

                  if (_showFloatingMenu) const SizedBox(width: 12),

                  // Menu horizontal muncul ke kanan
                  if (_showFloatingMenu)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.report_problem, color: Colors.black),
                            tooltip: 'Pengaduan',
                            onPressed: () {
                              setState(() => _showFloatingMenu = false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PengaduanPage()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


// === HEADER ===
@override
Widget _buildHeaderCustom() {
  return Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tombol hamburger
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),

        // Judul di tengah (gunakan Expanded untuk rata tengah)
        const Expanded(
          child: Center(
            child: Text(
              "Mbak Wali",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Tombol reset di kanan
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reset Chat',
          onPressed: _loading ? null : _resetChat,
        ),
      ],
    ),
  );
}

Widget _buildSidebar() {
  return Drawer(
    child: Column(
      children: const [
        DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue),
          child: Center(
            child: Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
        // Kosongan dulu
        ListTile(
          title: Text('Fitur akan datang...'),
          leading: Icon(Icons.hourglass_empty),
        ),
      ],
    ),
  );
}


Widget _buildBody() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF003466), // Biru tua
          Color(0xFF005A99), // Warna transisi
          Color(0xFF00ADEF), // Biru cerah
        ],
      ),
    ),
    child: Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Tanyakan sesuatu ke AI...',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70, // Disesuaikan agar kontras
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _buildMessage(_messages[index]),
                ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 3),
          ),

        // === FOOTER ===
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 75, 75, 75).withOpacity(0.5),
                blurRadius: 2,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _isRecording
                    ? const Text('Merekam...',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ))
                    : TextField(
                        controller: _controller,
                        onSubmitted: (value) {
                          if (!_loading && value.trim().isNotEmpty) {
                            _askQuestion(value.trim());
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Tanyakan sesuatu...',
                          border: InputBorder.none,
                        ),
                      ),
              ),
              if (_isRecording)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () async {
                    await _sttService.stopListening();
                    setState(() => _isRecording = false);
                  },
                )
              else ...[
                GestureDetector(
                  onLongPressStart: (_) async {
                    if (!_isRecording) {
                      setState(() => _isRecording = true);
                      _sttService.startListening(
                        onResult: (text) {
                          if (text.trim().isNotEmpty) {
                            _sttService.stopListening();
                            setState(() => _isRecording = false);
                            _askQuestion(text.trim());
                          }
                        },
                      );
                    }
                  },
                  onLongPressEnd: (_) async {
                    if (_isRecording) {
                      await _sttService.stopListening();
                      setState(() => _isRecording = false);
                    }
                  },
                  child: Icon(
                    _isRecording ? Icons.mic_off : Icons.mic,
                    color: _isRecording ? Colors.redAccent : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: _controller.text.trim().isEmpty
                        ? Colors.grey
                        : Colors.black87,
                  ),
                  onPressed: _loading || _controller.text.trim().isEmpty
                      ? null
                      : () {
                          _askQuestion(_controller.text.trim());
                        },
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
}

// Model untuk pesan chat
class _ChatMessage {
  final String text;
  final bool isUser;
  final AnimationController controller;
  final Uint8List? imageBytes;
  final List<String>? quickReplies;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.controller,
    this.imageBytes,
    this.quickReplies,
  });
}
