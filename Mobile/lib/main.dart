import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

const imgurClientId = "2553f5c0795ba3f";

void main() {
  runApp(const FahrradAdminApp());
}

class FahrradAdminApp extends StatelessWidget {
  const FahrradAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fahrrad Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const BikeListPage(), const AddBikePage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Liste'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Hinzufügen'),
        ],
      ),
    );
  }
}

class BikeListPage extends StatefulWidget {
  const BikeListPage({super.key});

  @override
  State<BikeListPage> createState() => _BikeListPageState();
}

class _BikeListPageState extends State<BikeListPage> {
  List bikes = [];
  bool loading = false;

  Future<void> fetchBikes() async {
    setState(() => loading = true);
    final response = await http.get(Uri.parse("https://falks-fahrradshop.web.app/gallery.json"));
    if (response.statusCode == 200) {
      final allBikes = jsonDecode(response.body);
      setState(() {
        bikes = allBikes;
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> deleteBike(String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Löschen bestätigen"),
        content: const Text("Möchten Sie diesen Eintrag wirklich löschen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Abbrechen")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Löschen")),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await http.post(
      Uri.parse("https://falks-fahrradshop.web.app/delete.php"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"image_url": imageUrl}),
    );

    if (response.statusCode == 200 && response.body.contains("success")) {
      fetchBikes();
    }
  }

  Future<void> toggleVisibility(String imageUrl, bool isVisible) async {
    final response = await http.post(
      Uri.parse("https://falks-fahrradshop.web.app/toggle_visibility.php"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "image_url": imageUrl,
        "visible": isVisible,
      }),
    );
    if (response.statusCode == 200) {
      fetchBikes();
    }
  }

  @override
  void initState() {
    super.initState();
    fetchBikes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fahrrad Liste"),
        actions: [
          IconButton(onPressed: fetchBikes, icon: const Icon(Icons.refresh))
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: bikes.length,
              itemBuilder: (context, index) {
                final bike = bikes[index];
                final isVisible = bike["visible"] != false;
                return ListTile(
                  leading: Image.network(bike["image"].startsWith("http") ? bike["image"] : "https://falks-fahrradshop.web.app/${bike["image"]}", width: 50),
                  title: Text(bike["title"]),
                  subtitle: Text(isVisible ? "Sichtbar" : "Versteckt"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => toggleVisibility(bike["image"], !isVisible),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteBike(bike["image"]),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AddBikePage extends StatefulWidget {
  const AddBikePage({super.key});

  @override
  State<AddBikePage> createState() => _AddBikePageState();
}

class _AddBikePageState extends State<AddBikePage> {
  final TextEditingController _titleController = TextEditingController();
  File? _selectedImage;
  bool isLoading = false;
  String status = '';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<String?> uploadToImgur(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse("https://api.imgur.com/3/image"),
      headers: {
        "Authorization": "Client-ID $imgurClientId",
      },
      body: {
        "image": base64Image,
        "type": "base64",
      },
    );

    final data = jsonDecode(response.body);
    if (data["success"] == true) {
      return data["data"]["link"];
    } else {
      throw Exception("Imgur upload failed: ${data["data"]["error"]}");
    }
  }

  Future<void> _submit() async {
    if (_selectedImage == null || _titleController.text.trim().isEmpty) {
      setState(() => status = "❌ Titel oder Bild fehlt.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final imgurUrl = await uploadToImgur(_selectedImage!);

      final addRes = await http.post(
        Uri.parse("https://falks-fahrradshop.web.app/add.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "title": _titleController.text.trim(),
          "image_url": imgurUrl,
          "visible": true,
        }),
      );

      if (addRes.statusCode == 200 && addRes.body.contains("success")) {
        setState(() {
          status = "✅ Erfolgreich hinzugefügt!";
          _titleController.clear();
          _selectedImage = null;
        });
      } else {
        throw Exception("Eintrag fehlgeschlagen");
      }
    } catch (e) {
      setState(() => status = "❌ Fehler: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _imagePreview() {
    if (_selectedImage == null) return const Text("Kein Bild ausgewählt.");
    return Image.file(_selectedImage!, height: 200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fahrrad hinzufügen")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Titel"),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Bild auswählen"),
            ),
            const SizedBox(height: 12),
            _imagePreview(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Eintrag hochladen"),
            ),
            const SizedBox(height: 16),
            if (status.isNotEmpty)
              Text(
                status,
                style: TextStyle(
                  color: status.startsWith("✅") ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}