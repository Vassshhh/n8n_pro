import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class PengaduanPage extends StatefulWidget {
  const PengaduanPage({Key? key}) : super(key: key);

  @override
  State<PengaduanPage> createState() => _PengaduanPageState();
}

class _PengaduanPageState extends State<PengaduanPage> {
  final TextEditingController _pengaduanController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
      });
    }
  }

  Future<void> _submitPengaduan() async {
    final text = _pengaduanController.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);

    final uri = Uri.parse('https://bot.kediritechnopark.com/webhook/pengaduan');
    final request = http.MultipartRequest('POST', uri);

    request.fields['pengaduan'] = text;

    if (_imageBytes != null && _imageName != null) {
      final mimeType = lookupMimeType(_imageName!) ?? 'image/png';
      final mimeSplit = mimeType.split('/');

      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          _imageBytes!,
          filename: _imageName,
          contentType: MediaType(mimeSplit[0], mimeSplit[1]),
        ),
      );
    }

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaduan berhasil dikirim')),
        );
        _pengaduanController.clear();
        setState(() {
          _imageBytes = null;
          _imageName = null;
        });
      } else {
        throw Exception("Status: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pengaduan: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form Pengaduan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tulis Pengaduan Anda:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pengaduanController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ketik pengaduan Anda di sini...',
              ),
            ),
            const SizedBox(height: 12),

            // Tombol Kamera & Galeri di bawah input
            Row(
              children: [
                IconButton(
                  onPressed: _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Ambil Foto',
                ),
                IconButton(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  tooltip: 'Ambil dari Galeri',
                ),
              ],
            ),

            if (_imageBytes != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_imageBytes!, height: 150),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() {
                                _imageBytes = null;
                                _imageName = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _imageName ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      // Tombol di bawah layar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submitPengaduan,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Kirim Pengaduan'),
          ),
        ),
      ),
    );
  }
}
