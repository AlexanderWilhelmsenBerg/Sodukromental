import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'library_digest.dart';
import 'library_models.dart';
import 'library_store.dart';

/// A manual worksheet over the setter's original image. The player supplies the
/// grid boundaries. Printed digits and variant clues stay in the artwork.
class LibraryDiagramSheet extends StatefulWidget {
  const LibraryDiagramSheet({
    super.key,
    required this.store,
    required this.puzzle,
  });

  final LibraryStore store;
  final LibraryDownload puzzle;
  static final _ids = Expando<String>('diagram fingerprint');

  static String _imageId(LibraryDownload puzzle) =>
      _ids[puzzle] ??= librarySha256(puzzle.diagram!);

  static bool hasDraft(LibraryStore store, LibraryDownload puzzle) {
    final saved = store.getDiagramSheet(puzzle.entry.id, puzzle.entry.revision);
    final images = saved?['images'];
    return puzzle.diagram != null &&
        images is Map &&
        images.containsKey(_imageId(puzzle));
  }

  @override
  State<LibraryDiagramSheet> createState() => _LibraryDiagramSheetState();
}

class _LibraryDiagramSheetState extends State<LibraryDiagramSheet> {
  late final String _imageId;
  late final Map<String, dynamic> _editions;
  late final Future<Size> _dimensions;
  late Uint8List _bytes;
  late int _size;
  Rect? _bounds;
  Offset? _first, _last;
  int _proposedSize = 9;
  bool _editFirst = true;
  bool _aligning = true;
  bool _finished = false;
  int? _selected;
  final _marks = <int, int>{};
  final _locked = <int>{};

  @override
  void initState() {
    super.initState();
    final puzzle = widget.puzzle;
    final source = puzzle.diagram ?? '';
    _imageId = LibraryDiagramSheet._imageId(puzzle);
    _dimensions = _readDimensions(source);
    final saved = widget.store.getDiagramSheet(
      puzzle.entry.id,
      puzzle.entry.revision,
    );
    _editions = Map<String, dynamic>.from(saved?['images'] as Map? ?? {});
    final state = _editions[_imageId] as Map?;
    _size = (state?['size'] as int? ?? puzzle.entry.size ?? 9).clamp(4, 16);
    final corners = state?['bounds'] as List?;
    if (corners != null && corners.length == 4) {
      _bounds = Rect.fromLTRB(
        (corners[0] as num).toDouble(),
        (corners[1] as num).toDouble(),
        (corners[2] as num).toDouble(),
        (corners[3] as num).toDouble(),
      );
      _aligning = false;
    }
    for (final entry in (state?['marks'] as Map? ?? {}).entries) {
      _marks[int.parse(entry.key as String)] = entry.value as int;
    }
    _locked.addAll((state?['locked'] as List? ?? []).cast<int>());
    _finished = state?['finished'] == true;
    _startAlignment();
  }

  Future<Size> _readDimensions(String source) async {
    _bytes = base64Decode(source);
    final buffer = await ui.ImmutableBuffer.fromUint8List(_bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  void _startAlignment() {
    _proposedSize = _size;
    _first = _bounds?.topLeft;
    _last = _bounds?.bottomRight;
    _editFirst = true;
  }

  Rect? get _proposed {
    final a = _first, b = _last;
    if (a == null || b == null || b.dx - a.dx < .02 || b.dy - a.dy < .02)
      return null;
    return Rect.fromLTRB(a.dx, a.dy, b.dx, b.dy);
  }

  void _save() {
    final b = _bounds!;
    _editions[_imageId] = {
      'size': _size,
      'bounds': [b.left, b.top, b.right, b.bottom],
      'marks': {for (final e in _marks.entries) '${e.key}': e.value},
      'locked': _locked.toList(),
      'finished': _finished,
    };
    final entry = widget.puzzle.entry;
    unawaited(
      widget.store
          .saveDiagramSheet(entry.id, entry.revision, {
            'version': 1,
            'images': Map.of(_editions),
          })
          .catchError((Object _) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Could not save the worksheet on this device.',
                  ),
                  action: SnackBarAction(label: 'Retry', onPressed: _save),
                ),
              );
            }
          }),
    );
  }

  Future<void> _applyAlignment() async {
    final b = _proposed;
    if (b == null) return;
    final resized = _proposedSize != _size;
    if (resized && (_marks.isNotEmpty || _locked.isNotEmpty)) {
      final erase = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change grid size?'),
          content: const Text(
            'Changing the number of rows clears your entries and printed-cell locks.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change size'),
            ),
          ],
        ),
      );
      if (erase != true || !mounted) return;
    }
    setState(() {
      if (resized) {
        _marks.clear();
        _locked.clear();
      }
      _size = _proposedSize;
      _bounds = b;
      _aligning = false;
      _finished = false;
      _selected = null;
    });
    _save();
  }

  void _setCorner(Offset point, {bool advance = true}) {
    setState(() {
      if (_editFirst) {
        _first = point;
        if (advance) _editFirst = false;
      } else {
        _last = point;
      }
    });
  }

  void _write(int? value) {
    final cell = _selected;
    if (_finished || cell == null || _locked.contains(cell)) return;
    setState(() {
      if (value == null) {
        _marks.remove(cell);
      } else {
        _marks[cell] = value;
      }
    });
    _save();
  }

  Widget _image(Size source, double screenWidth) {
    final dimensions = applyBoxFit(
      BoxFit.contain,
      source,
      Size(
        math.min(620, screenWidth),
        math.min(640, MediaQuery.sizeOf(context).height * .62),
      ),
    ).destination;
    final b = _aligning ? _proposed : _bounds;
    final rect = b == null
        ? null
        : Rect.fromLTRB(
            b.left * dimensions.width,
            b.top * dimensions.height,
            b.right * dimensions.width,
            b.bottom * dimensions.height,
          );
    return Align(
      child: SizedBox.fromSize(
        size: dimensions,
        child: Stack(
          key: const ValueKey('worksheet-image'),
          children: [
            Positioned.fill(
              child: Image.memory(
                _bytes,
                fit: BoxFit.fill,
                semanticLabel:
                    'Original puzzle diagram by ${widget.puzzle.entry.author}',
              ),
            ),
            if (rect != null)
              Positioned.fromRect(
                rect: rect,
                child: GridView.count(
                  padding: EdgeInsets.zero,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: _aligning ? _proposedSize : _size,
                  childAspectRatio: rect.width / rect.height,
                  children: [
                    for (
                      var i = 0;
                      i <
                          (_aligning
                              ? _proposedSize * _proposedSize
                              : _size * _size);
                      i++
                    )
                      if (_aligning)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.teal.shade700.withValues(
                                alpha: .64,
                              ),
                              width: .6,
                            ),
                          ),
                        )
                      else
                        _cell(i),
                  ],
                ),
              ),
            if (_aligning)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('worksheet-align-tap'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (tap) => _setCorner(
                    Offset(
                      (tap.localPosition.dx / dimensions.width).clamp(0, 1),
                      (tap.localPosition.dy / dimensions.height).clamp(0, 1),
                    ),
                  ),
                  child: CustomPaint(painter: _Corners(_first, _last)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final selected = i == _selected;
    final value = _marks[i];
    final locked = _locked.contains(i);
    return Semantics(
      button: true,
      selected: selected,
      label: _cellLabel(i),
      child: InkWell(
        key: ValueKey('worksheet-cell-$i'),
        onTap: () => setState(() => _selected = i),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Stack(
            children: [
              if (value != null)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontSize: 21,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (locked)
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.lock, size: 9, color: Colors.teal),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _cellLabel(int index) {
    final value = _marks[index];
    final state = _locked.contains(index)
        ? 'printed cell locked'
        : value == null
        ? 'unmarked'
        : 'your entry $value';
    return 'Row ${index ~/ _size + 1}, column ${index % _size + 1}, $state';
  }

  Future<void> _chooseCell() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView.builder(
        itemCount: _size * _size,
        itemBuilder: (context, index) => ListTile(
          title: Text(_cellLabel(index)),
          selected: index == _selected,
          onTap: () => Navigator.pop(context, index),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selected = picked);
  }

  Widget _alignmentTools() {
    final point =
        (_editFirst ? _first : _last) ??
        (_editFirst ? Offset.zero : const Offset(1, 1));
    Widget control(String label, double value, ValueChanged<double> change) =>
        Row(
          children: [
            Text(label),
            Expanded(
              child: Slider(
                value: value,
                divisions: 200,
                semanticFormatterCallback: (value) =>
                    '$label ${(100 * value).round()} percent',
                onChanged: change,
              ),
            ),
            Text('${(100 * value).round()}%'),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<int>(
          value: _proposedSize,
          isExpanded: true,
          items: [
            for (var i = 4; i <= 16; i++)
              DropdownMenuItem(value: i, child: Text('$i rows × $i columns')),
          ],
          onChanged: (value) => setState(() => _proposedSize = value!),
        ),
        Text(
          _editFirst
              ? 'Tap the top-left corner of the printed grid.'
              : 'Tap the bottom-right corner of the printed grid.',
        ),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Top left'),
              selected: _editFirst,
              onSelected: (_) => setState(() => _editFirst = true),
            ),
            ChoiceChip(
              label: const Text('Bottom right'),
              selected: !_editFirst,
              onSelected: (_) => setState(() => _editFirst = false),
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Adjust corner position'),
          children: [
            control(
              'Across',
              point.dx,
              (v) => _setCorner(Offset(v, point.dy), advance: false),
            ),
            control(
              'Down',
              point.dy,
              (v) => _setCorner(Offset(point.dx, v), advance: false),
            ),
            TextButton(
              onPressed: () => _setCorner(point, advance: false),
              child: const Text('Use this corner'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _proposed == null ? null : _applyAlignment,
              child: const Text('Use aligned grid'),
            ),
            if (_bounds != null)
              TextButton(
                onPressed: () => setState(() => _aligning = false),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _finish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark this worksheet complete?'),
        content: const Text(
          'Check your entries against the setter’s rules. This diagram has no answer checker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep solving'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _finished = true);
      _save();
    }
  }

  Widget _playTools() {
    final cell = _selected;
    final locked = cell != null && _locked.contains(cell);
    if (_finished) {
      return Row(
        children: [
          const Expanded(child: Text('Manually completed')),
          TextButton(
            onPressed: () {
              setState(() => _finished = false);
              _save();
            },
            child: const Text('Continue editing'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cell == null
              ? 'Select a cell in the diagram.'
              : 'Row ${cell ~/ _size + 1}, column ${cell % _size + 1}${locked ? ' · Printed cell locked' : ''}',
        ),
        GridView.count(
          crossAxisCount: _size <= 9 ? 3 : 4,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisExtent: math.max(
            48,
            MediaQuery.textScalerOf(context).scale(22) + 12,
          ),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var value = 1; value <= _size; value++)
              FilledButton.tonal(
                key: ValueKey('worksheet-digit-$value'),
                onPressed: cell == null || locked ? null : () => _write(value),
                child: Text('$value'),
              ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            TextButton(
              onPressed: _chooseCell,
              child: const Text('Choose cell'),
            ),
            TextButton(
              onPressed: cell == null || locked ? null : () => _write(null),
              child: const Text('Erase entry'),
            ),
            TextButton(
              onPressed: cell == null || _marks.containsKey(cell)
                  ? null
                  : () {
                      setState(() {
                        if (locked) {
                          _locked.remove(cell);
                        } else {
                          _locked.add(cell);
                        }
                      });
                      _save();
                    },
              child: Text(locked ? 'Unlock printed cell' : 'Lock printed cell'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _startAlignment();
                _aligning = true;
              }),
              child: const Text('Adjust grid'),
            ),
            TextButton(
              onPressed: _marks.isEmpty ? null : _finish,
              child: const Text('Finish manually'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Diagram worksheet')),
    body: SafeArea(
      child: FutureBuilder<Size>(
        future: _dimensions,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(
              child: Text('This saved diagram could not be opened.'),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 660),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.puzzle.entry.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('By ${widget.puzzle.entry.author}'),
                    if (_aligning)
                      const Text(
                        'Use one square grid with digits from 1 to its size. Set both corners and check the overlay.',
                      ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          _image(snapshot.requireData, constraints.maxWidth),
                    ),
                    const SizedBox(height: 8),
                    if (_aligning) _alignmentTools() else _playTools(),
                    if (widget.puzzle.entry.rules.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Setter’s rules'),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(widget.puzzle.entry.rules),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Corners extends CustomPainter {
  const _Corners(this.first, this.last);
  final Offset? first, last;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.shade800
      ..strokeWidth = 3;
    for (final point in [first, last].nonNulls) {
      final p = Offset(point.dx * size.width, point.dy * size.height);
      canvas.drawCircle(p, 4, paint);
    }
  }

  @override
  bool shouldRepaint(_Corners old) => first != old.first || last != old.last;
}
