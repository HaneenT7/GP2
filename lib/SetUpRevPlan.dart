import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SetUpRevPlan extends StatefulWidget {
  final VoidCallback onClose;
  const SetUpRevPlan({super.key, required this.onClose});

  @override
  State<StatefulWidget> createState() => _SetUpRevPlanState();
}

class _SetUpRevPlanState extends State<SetUpRevPlan> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String? _selectedFolderId;
  List<String> _selectedFileIds = [];
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Header --
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Create new Revision Plan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Expanded(
  child: ListView(
    padding: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 20),
    children: [
      // 1. Select course folder
      _buildSectionTitle('Select course folder'),
      const SizedBox(height: 10),

      // FOLDER SELECTOR STREAM
      StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('courseFolders')
            .where('userId', isEqualTo: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('Error: ${snapshot.error}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
          }

          final folders = snapshot.data?.docs ?? [];

          if (folders.isEmpty) {
            return Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text("No folders found. Create one first!")),
            );
          }

          return SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index].data() as Map<String, dynamic>;
                final folderId = folders[index].id;
                final isSelected = _selectedFolderId == folderId;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFolderId = folderId;
                      _selectedFileIds.clear(); // Reset files when folder changes
                    });
                  },
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF423066).withOpacity(0.05) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF423066) : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_rounded,
                          size: 40,
                          color: isSelected ? const Color(0xFF423066) : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            folder['name'] ?? 'Untitled',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF423066) : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),

      const SizedBox(height: 30),

      // 2. Select exam materials (Files)
      _buildSectionTitle('Select exam materials'),
      const SizedBox(height: 10),
      _buildFileSelector(),

      const SizedBox(height: 30),

      // 3. Select exam date
      _buildSectionTitle('Select exam date'),
      const SizedBox(height: 10),
      _buildDatePicker(),
      
      const SizedBox(height: 120), 
    ],
  ),
),
          ],
        ),
        
        // -- Generate Button --
        Positioned(
          right: 32,
          bottom: 32,
          child: _buildGenerateButton(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500));
  }

  // Fetch Folders where userId matches current user
  Widget _buildFolderSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('courseFolders')
          .where('userId', isEqualTo: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        var folders = snapshot.data!.docs;

        return Container(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              var folder = folders[index];
              bool isSelected = _selectedFolderId == folder.id;

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedFolderId = folder.id;
                  _selectedFileIds.clear(); // Clear files when folder changes
                }),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF423066).withOpacity(0.1) : Colors.white,
                    border: Border.all(color: isSelected ? const Color(0xFF423066) : Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder, color: isSelected ? const Color(0xFF423066) : Colors.grey),
                      const SizedBox(height: 8),
                      Text(folder['name']
                      , style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Fetch Files belonging to the selected folder
  Widget _buildFileSelector() {
    if (_selectedFolderId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
        child: const Text("Select a folder first to see materials"),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('folderFiles')
          .where('folderId', isEqualTo: _selectedFolderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        var files = snapshot.data!.docs;

        if (files.isEmpty) return const Text("No files in this folder.");

        return Wrap(
          spacing: 10,
          children: files.map((file) {
            bool isSelected = _selectedFileIds.contains(file.id);
            return FilterChip(
              label: Text(file['name']),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  val ? _selectedFileIds.add(file.id) : _selectedFileIds.remove(file.id);
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 650, height: 350,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          onDateChanged: (date) => setState(() => _selectedDate = date),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    bool canGenerate = _selectedFolderId != null && _selectedFileIds.isNotEmpty;

    return ElevatedButton.icon(
      onPressed: canGenerate ? () {
        // Logic to trigger AI plan generation
        print("Generating plan for folder $_selectedFolderId with files $_selectedFileIds");
      } : null,
      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 23),
      label: const Text('Generate Revision Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF423066),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}