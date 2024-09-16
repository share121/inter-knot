import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _controller = QuillController.basic();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            configurations: const QuillSimpleToolbarConfigurations(),
          ),
          Expanded(
            child: QuillEditor.basic(
              controller: _controller,
              configurations: const QuillEditorConfigurations(),
            ),
          )
        ],
      ),
    );
  }
}
