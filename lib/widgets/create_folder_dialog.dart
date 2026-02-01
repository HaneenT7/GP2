import 'package:flutter/material.dart';

class CreateFolderDialog extends StatefulWidget {
  final Future<void> Function(String name, String color) onFolderCreated;
  final List<String> folderColors;

  const CreateFolderDialog({
    super.key,
    required this.onFolderCreated,
    required this.folderColors,
  });

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = Color(int.parse(widget.folderColors[_selectedColorIndex].replaceFirst('#', '0xFF')));
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.8; // Use 80% of screen height max

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: MediaQuery.of(context).size.height * 0.05,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: maxDialogHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top bar with X button and title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Expanded(
                      child: Text(
                        'Create New Course Folder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the X button on the left
                  ],
                ),
              ),
              // Scrollable main content area
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Folder icon with selected color
                      Container(
                        width: 80,
                        height: 65,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: selectedColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.folder,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Folder name input
                      TextField(
                        controller: _nameController,
                        maxLength: 20,
                        onChanged: (value) {
                          // Clear error when user types
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Folder Name',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          counterText: '', // Hide character counter
                          errorText: _errorMessage,
                          errorStyle: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                          errorMaxLines: 3,
                        ),
                        textAlign: TextAlign.center,
                        autofocus: true,
                      ),
                      const SizedBox(height: 20),
                      // Color selection
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: List.generate(
                          widget.folderColors.length,
                          (index) => GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColorIndex = index;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(int.parse(widget.folderColors[index].replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColorIndex == index
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Create button
                      ElevatedButton(
                        onPressed: _createFolder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B46C1),
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                        ),
                        child: const Text(
                          'Create',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createFolder() async {
    final name = _nameController.text.trim();
    
    // Validate and show error under text field
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Folder name must contain at least 1 character';
      });
      return;
    }

    if (name.length > 20) {
      setState(() {
        _errorMessage = 'Folder name must be 20 characters or less';
      });
      return;
    }

    // Clear any previous error
    setState(() {
      _errorMessage = null;
    });

    // Call the callback - handle errors here
    try {
      await widget.onFolderCreated(name, widget.folderColors[_selectedColorIndex]);
    } catch (e) {
      // Show error under text field
      setState(() {
        final errorStr = e.toString();
        if (errorStr.contains('already exists')) {
          _errorMessage = 'A folder with this name already exists';
        } else {
          _errorMessage = errorStr.replaceFirst('Exception: ', '');
        }
      });
    }
  }
}

