import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'add_notes_page.dart'; // Pastikan ini sesuai path file kamu

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Liburan',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: NotesPage(),
    );
  }
}

class NotesPage extends StatelessWidget {
  final CollectionReference notes = FirebaseFirestore.instance.collection(
    'notes',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Catatan Liburan"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: "Tambah Catatan",
            onPressed: () {
              // Pastikan AddNotePage sudah terdefinisi dengan benar
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddNotePage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notes.orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Belum ada catatan."));
          }
          return ListView(
            children:
                snapshot.data!.docs.map((DocumentSnapshot document) {
                  final data = document.data()! as Map<String, dynamic>;
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(data['title'] ?? '-'),
                      subtitle: Text(data['content'] ?? ''),
                      trailing:
                          data['synced'] == true
                              ? Icon(Icons.cloud_done, color: Colors.green)
                              : Icon(Icons.cloud_off, color: Colors.grey),
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
