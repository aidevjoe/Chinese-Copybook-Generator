import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'responsive_layout.dart';

import 'package:document_file_save_plus/document_file_save_plus.dart';

enum PracticeMode { article, tracing }

enum GridType { standard, field, rice }

class CopybookGeneratorPage extends StatefulWidget {
  const CopybookGeneratorPage({super.key});

  @override
  State<CopybookGeneratorPage> createState() => _CopybookGeneratorPageState();
}

class _CopybookGeneratorPageState extends State<CopybookGeneratorPage> {
  final TextEditingController _controller = TextEditingController();
  final CopybookSettings _settings = CopybookSettings();
  final List<Uint8List> _generatedImageBytes = [];
  final Map<String, ByteData> _customFonts = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _settings.updateGridSize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      appBar: AppBar(
        title: const Text("字帖生成器"),
        actions: [
          IconButton(
              onPressed: _printDoc, icon: const Icon(Icons.print_rounded))
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (ResponsiveLayout.isPhone(context)) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(),
            const SizedBox(height: 10),
            _buildSettingsCard(),
            const SizedBox(height: 10),
            _buildActionButtons(),
            const SizedBox(height: 10),
            _buildGeneratedImages(),
          ],
        ),
      );
    }
    return MultiSplitView(axis: Axis.horizontal, initialAreas: [
      Area(
        builder: (context, area) => SingleChildScrollView(
          padding: const EdgeInsets.all(15),
          child: _buildGeneratedImages(),
        ),
      ),
      Area(
        size: 350,
        builder: (context, area) => Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(),
              const SizedBox(height: 10),
              _buildSettingsCard(),
              const SizedBox(height: 10),
              _buildActionButtons(),
            ],
          ),
        ),
      )
    ]);
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(labelText: "输入要练习的汉字"),
      maxLines: 3,
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSlider("字体大小:", _settings.fontSize, 50, 200, (value) {
              setState(() => _settings.fontSize = value);
            }),
            const SizedBox(height: 10),
            _buildSlider("每行格子数:", _settings.gridsPerRow.toDouble(), 5, 20,
                (value) {
              setState(() {
                _settings.gridsPerRow = value.round();
                _settings.updateGridSize();
              });
            }),
            const SizedBox(height: 8),
            _buildGridTypeSelector(),
            const SizedBox(height: 8),
            // _buildColorPicker(
            //     "格子颜色:", _settings.gridColor, (color) {
            //   setState(() => _settings.gridColor = color);
            // }),
            const SizedBox(height: 8),
            _buildColorPicker("文字颜色:", _settings.textColor, (color) {
              setState(() => _settings.textColor = color);
            }),
            const SizedBox(height: 8),
            _buildFontSelection(),
            const SizedBox(height: 8),
            _buildPracticeModeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Slider(
              value: value,
              min: min,
              max: max,
              label: value.round().toString(),
              onChanged: onChanged,
            ),
            SizedBox(
                width: 27,
                child: Text(value.round().toStringAsFixed(0),
                    textAlign: TextAlign.end)),
          ],
        ),
      ],
    );
  }

  Widget _buildGridTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("格子类型}:", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: GridType.values.map((type) {
            return GestureDetector(
              onTap: () => setState(() => _settings.gridType = type),
              child: Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _settings.gridType == type
                        ? Colors.blue
                        : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: GridPainter(type, _settings.gridColor),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorPicker(
      String label, Color currentColor, ValueChanged<Color> onColorChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        // ColorPickerWidget(currentColor, onColorChanged: onColorChanged)
      ],
    );
  }

  Widget _buildFontSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("字体:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: DropdownButton<String?>(
            value: _settings.selectedFontFamily,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(10.0),
            padding: const EdgeInsets.only(left: 6),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text("默认"),
              ),
              ..._customFonts.keys.map((String fontFamily) {
                return DropdownMenuItem<String?>(
                  value: fontFamily,
                  child: Text(fontFamily),
                );
              }),
              const DropdownMenuItem<String?>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 3),
                    Text("自定义字体"),
                  ],
                ),
              ),
            ],
            onChanged: (String? newValue) async {
              if (newValue == 'import') {
                await _importFont();
              } else {
                setState(() {
                  _settings.selectedFontFamily = newValue;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("练习模式", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: DropdownButton<PracticeMode>(
            value: _settings.practiceMode,
            underline: const SizedBox.shrink(),
            alignment: AlignmentDirectional.center,
            borderRadius: BorderRadius.circular(10.0),
            padding: const EdgeInsets.only(left: 6),
            onChanged: (PracticeMode? newValue) {
              if (newValue != null) {
                setState(() {
                  _settings.practiceMode = newValue;
                });
              }
            },
            items: PracticeMode.values.map((PracticeMode mode) {
              return DropdownMenuItem<PracticeMode>(
                value: mode,
                child: Text(mode == PracticeMode.article ? "文章贴" : "描红贴"),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _controller.text.isEmpty ? null : _generatePracticeSheet,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(vertical: 16)),
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) =>
                      states.contains(WidgetState.disabled)
                          ? Theme.of(context).primaryColor.withOpacity(0.5)
                          : Theme.of(context).primaryColor),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: const Text("生成"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            onPressed: _controller.text.isEmpty ? null : _exportImage,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(vertical: 16)),
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) =>
                      states.contains(WidgetState.disabled)
                          ? Theme.of(context).primaryColor.withOpacity(0.5)
                          : Theme.of(context).primaryColor),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: const Text("导出"),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedImages() {
    return _isProcessing
        ? const SizedBox(
            height: 100,
            child: Center(
                child: CircularProgressIndicator(strokeCap: StrokeCap.round)),
          )
        : Column(
            children: _generatedImageBytes
                .map((bytes) => Container(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Image.memory(bytes),
                    ))
                .toList(),
          );
  }

  Future<void> _importFont() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      String fontFamily = file.name.split('.').first;

      final bytes = await File(file.path!).readAsBytes();
      ByteData fontData = ByteData.view(bytes.buffer);

      setState(() {
        _customFonts[fontFamily] = fontData;
        _settings.selectedFontFamily = fontFamily;
      });

      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(fontData));
      await fontLoader.load();
    }
  }

  Future _generatePracticeSheet() async {
    setState(() {
      _isProcessing = true;
    });
    _generatedImageBytes.clear();
    final characters = _controller.text.trim().split('');
    int charIndex = 0;

    while (charIndex < characters.length) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(_settings.a4Width, _settings.a4Height);
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      double x = _settings.pageMargin;
      double y = _settings.pageMargin;

      while (y + _settings.gridSize <= size.height - _settings.pageMargin &&
          charIndex < characters.length) {
        if (_settings.practiceMode == PracticeMode.tracing) {
          _drawTracingModeRow(canvas, characters[charIndex], x, y);
          y += _settings.gridSize;
          charIndex++;
        } else {
          _drawCharacterGrid(canvas, characters[charIndex], x, y,
              opacity: _settings.transparencyLevel);
          charIndex++;
          x += _settings.gridSize;
          if (x + _settings.gridSize > size.width - _settings.pageMargin) {
            x = _settings.pageMargin;
            y += _settings.gridSize;
          }
        }
      }

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (!mounted) return;
      if (pngBytes != null) {
        setState(() {
          _generatedImageBytes.add(pngBytes);
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('生成失败'),
        ));
      }
    }
  }

  void _drawTracingModeRow(
      Canvas canvas, String character, double x, double y) {
    for (int i = 0; i < _settings.gridsPerRow; i++) {
      _drawCharacterGrid(canvas, character, x + i * _settings.gridSize, y,
          opacity: i == 0 ? 1.0 : _settings.transparencyLevel);
    }
  }

  void _drawCharacterGrid(Canvas canvas, String character, double x, double y,
      {double opacity = 1.0}) {
    final paint = Paint()
      ..color = _settings.gridColor
      ..style = PaintingStyle.stroke;

    // Draw grid
    canvas.drawRect(
        Rect.fromLTWH(x, y, _settings.gridSize, _settings.gridSize), paint);

    // Draw grid lines based on grid type
    _drawGridLines(canvas, x, y);

    // Draw character
    final textPainter = TextPainter(
      text: TextSpan(
          text: character,
          style: TextStyle(
            fontSize: _settings.fontSize,
            color: _settings.textColor.withOpacity(opacity),
            fontFamily: _settings.selectedFontFamily,
          )),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(x + (_settings.gridSize - textPainter.width) / 2,
            y + (_settings.gridSize - textPainter.height) / 2));
  }

  void _drawGridLines(Canvas canvas, double x, double y) {
    final dashedPaint = Paint()
      ..color = _settings.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    void drawDashedLine(
        Offset start, Offset end, double dashLength, double gapLength) {
      final path = Path();
      final vector = end - start;
      final distance = vector.distance;
      final unitVector = vector / distance;
      double drawn = 0.0;
      path.moveTo(start.dx, start.dy);
      while (drawn < distance) {
        final dashEnd =
            drawn + dashLength < distance ? drawn + dashLength : distance;
        path.lineTo(start.dx + unitVector.dx * dashEnd,
            start.dy + unitVector.dy * dashEnd);
        drawn = dashEnd + gapLength;
        if (drawn < distance) {
          path.moveTo(start.dx + unitVector.dx * drawn,
              start.dy + unitVector.dy * drawn);
        }
      }
      canvas.drawPath(path, dashedPaint);
    }

    switch (_settings.gridType) {
      case GridType.standard:
        drawDashedLine(Offset(x + _settings.gridSize / 2, y),
            Offset(x + _settings.gridSize / 2, y + _settings.gridSize), 5, 5);
        drawDashedLine(Offset(x, y + _settings.gridSize / 2),
            Offset(x + _settings.gridSize, y + _settings.gridSize / 2), 5, 5);
        break;
      case GridType.field:
        drawDashedLine(Offset(x + _settings.gridSize / 2, y),
            Offset(x + _settings.gridSize / 2, y + _settings.gridSize), 5, 5);
        drawDashedLine(Offset(x, y + _settings.gridSize / 2),
            Offset(x + _settings.gridSize, y + _settings.gridSize / 2), 5, 5);
        drawDashedLine(Offset(x, y),
            Offset(x + _settings.gridSize, y + _settings.gridSize), 5, 5);
        drawDashedLine(Offset(x + _settings.gridSize, y),
            Offset(x, y + _settings.gridSize), 5, 5);
        break;
      case GridType.rice:
        drawDashedLine(Offset(x, y),
            Offset(x + _settings.gridSize, y + _settings.gridSize), 5, 5);
        drawDashedLine(Offset(x + _settings.gridSize, y),
            Offset(x, y + _settings.gridSize), 5, 5);
        break;
    }
  }

  void _exportImage() async {
    if (_generatedImageBytes.isEmpty) {
      await _generatePracticeSheet();
    }
    final bytes = await compute(_generatePdf, _generatedImageBytes);
    if (!mounted) return;
    await DocumentFileSavePlus().saveFile(bytes, "practice_sheet.pdf", "application/pdf");
  }

  static Future<Uint8List> _generatePdf(List<Uint8List> imageBytes) async {
    final doc = pw.Document(
        author: "Snibox",
        producer: "Snibox",
        creator: "Snibox",
        title: "Chinese Copybook Maker");
    for (var i = 0; i < imageBytes.length; i++) {
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero, // 设置页边距为零
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pw.MemoryImage(imageBytes[i])));
          })); // Page
    }
    return await doc.save();
  }

  void _printDoc() async {
    if (_generatedImageBytes.isEmpty) {
      await _generatePracticeSheet();
    }
    final bytes = await compute(_generatePdf, _generatedImageBytes);
    if (!mounted) return;
    final isOK = await Printing.layoutPdf(onLayout: (_) => bytes);
    if (!mounted) return;
    if (!isOK) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("操作失败"),
      ));
    }
  }
}

class CopybookSettings {
  double fontSize = 140;
  double gridSize = 100;
  int gridsPerRow = 10;
  GridType gridType = GridType.standard;
  Color gridColor = const Color(0xff11A45E);
  Color textColor = Colors.red;
  PracticeMode practiceMode = PracticeMode.tracing;
  String? selectedFontFamily;

  final double transparencyLevel = 0.3;
  final double a4Width = 2479;
  final double a4Height = 3508;
  final double pageMargin = 100;

  void updateGridSize() {
    gridSize = (a4Width - 2 * pageMargin) / gridsPerRow;
  }
}

class GridPainter extends CustomPainter {
  final GridType gridType;
  final Color gridColor;

  GridPainter(this.gridType, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    void drawDashedLine(
        Offset start, Offset end, double dashLength, double gapLength) {
      final path = Path();
      final vector = end - start;
      final distance = vector.distance;
      final unitVector = vector / distance;
      double drawn = 0.0;
      path.moveTo(start.dx, start.dy);
      while (drawn < distance) {
        final dashEnd =
            drawn + dashLength < distance ? drawn + dashLength : distance;
        path.lineTo(start.dx + unitVector.dx * dashEnd,
            start.dy + unitVector.dy * dashEnd);
        drawn = dashEnd + gapLength;
        if (drawn < distance) {
          path.moveTo(start.dx + unitVector.dx * drawn,
              start.dy + unitVector.dy * drawn);
        }
      }
      canvas.drawPath(path, paint);
    }

    switch (gridType) {
      case GridType.standard:
        drawDashedLine(Offset(size.width / 2, 0),
            Offset(size.width / 2, size.height), 2, 2);
        drawDashedLine(Offset(0, size.height / 2),
            Offset(size.width, size.height / 2), 2, 2);
        break;
      case GridType.field:
        drawDashedLine(Offset(size.width / 2, 0),
            Offset(size.width / 2, size.height), 2, 2);
        drawDashedLine(Offset(0, size.height / 2),
            Offset(size.width, size.height / 2), 2, 2);
        drawDashedLine(
            const Offset(0, 0), Offset(size.width, size.height), 2, 2);
        drawDashedLine(Offset(size.width, 0), Offset(0, size.height), 2, 2);
        break;
      case GridType.rice:
        drawDashedLine(
            const Offset(0, 0), Offset(size.width, size.height), 2, 2);
        drawDashedLine(Offset(size.width, 0), Offset(0, size.height), 2, 2);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
