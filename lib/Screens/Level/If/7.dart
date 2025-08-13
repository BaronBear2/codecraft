import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

DateTime? _levelEnterTime;
enum BlockType { move, moveBack, moveDown, moveUp, repeat, ifBlock, ifElseBlock, stop }
enum _ExecResult { continueProgram, breakLoop, stopProgram }

class Block {
  final BlockType type;
  int repeatCount;
  String condition;
  List<Block> children;
  List<Block> elseChildren;

  Block({
    required this.type,
    this.repeatCount = 2,
    this.condition = '',
    List<Block>? children,
    List<Block>? elseChildren,
  })  : children = children ?? [],
        elseChildren = elseChildren ?? [];
}

class LevelSevenScreen extends StatefulWidget {
  const LevelSevenScreen({super.key});

  @override
  State<LevelSevenScreen> createState() => _LevelSevenScreenState();
}

class _LevelSevenScreenState extends State<LevelSevenScreen> with TickerProviderStateMixin {
  static const int maxProgramBlocks = 20;
  static const int goalBlockCount = 9;

  List<Block> program = [];
  int penguinRow = 4;
  int penguinCol = 0;
  bool isRunning = false;
  bool showFail = false;
  bool showSuccess = false;
  bool trashActive = false;
  bool showTutorial = true;
  bool showHint = false;
  List<int>? runningBlockPath;

  late AnimationController _controller;
  late Animation<double> _penguinScale;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  final int signRow = 2;
  final int signCol = 4;

  final Set<List<int>> activeTiles = {
    [0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5],
    [1, 4],
    [2, 5], [2, 4], [2, 3], [2, 2],
    [3, 2], [3, 1], [3, 0],
    [4, 0],
  };

  Future<void> _updateProgress(int level) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('user_progress').doc(user.uid);
      final snapshot = await doc.get();
      final currentLevel = snapshot.exists ? (snapshot.data()?['highestLevel'] ?? 1) : 1;
      if (level > currentLevel) {
        await doc.set({'highestLevel': level}, SetOptions(merge: true));
      }
    }
  }

  Future<void> _incrementAttempt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('user_progress').doc(user.uid);
      await doc.set({'totalAttempt': FieldValue.increment(1)}, SetOptions(merge: true));
    }
  }

  Future<void> _addTimeSpent(int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('user_progress').doc(user.uid);
      await doc.set({'totalTimeSpent': FieldValue.increment(seconds)}, SetOptions(merge: true));
    }
  }

  Future<void> _saveLevelTimeSpent() async {
    if (_levelEnterTime != null) {
      final secondsSpent = DateTime.now().difference(_levelEnterTime!).inSeconds;
      await _addTimeSpent(secondsSpent);
    }
  }

  @override
  void initState() {
    super.initState();
    isRunning = false;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.9,
      upperBound: 1.1,
    );
    _penguinScale = Tween<double>(begin: 1, end: 1.1).animate(_controller);
    _levelEnterTime = DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _saveLevelTimeSpent();
    super.dispose();
  }

  void runProgram() async {
    if (isRunning) return;
    await _incrementAttempt();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() {
      isRunning = true;
      showFail = false;
      showSuccess = false;
      penguinRow = 4;
      penguinCol = 0;
    });
    await _execute(program);
    setState(() {
      isRunning = false;
      if (penguinRow == 0 && penguinCol == 0 && _countBlocks(program) <= goalBlockCount) {
        showSuccess = true;
      } else {
        showFail = true;
      }
    });
  }

  Future<_ExecResult> _execute(List<Block> blocks, {bool inLoop = false, List<int> parentPath = const []}) async {
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final currentPath = [...parentPath, i];
      setState(() {
        runningBlockPath = currentPath;
      });
      await Future.delayed(const Duration(milliseconds: 200));

      if (block.type == BlockType.move) {
        if (penguinCol < 5 && activeTiles.any((pos) => pos[0] == penguinRow && pos[1] == penguinCol + 1)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinCol++);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.moveBack) {
        if (penguinCol > 0 && activeTiles.any((pos) => pos[0] == penguinRow && pos[1] == penguinCol - 1)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinCol--);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.moveDown) {
        if (penguinRow < 4 && activeTiles.any((pos) => pos[0] == penguinRow + 1 && pos[1] == penguinCol)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinRow++);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.moveUp) {
        if (penguinRow > 0 && activeTiles.any((pos) => pos[0] == penguinRow - 1 && pos[1] == penguinCol)) {
          await _controller.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          await _controller.reverse();
          setState(() => penguinRow--);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } else if (block.type == BlockType.repeat) {
        for (int j = 0; j < block.repeatCount; j++) {
          final result = await _execute(block.children, inLoop: true, parentPath: currentPath);
          if (result == _ExecResult.breakLoop) break;
          if (result == _ExecResult.stopProgram) return _ExecResult.stopProgram;
        }
      } else if (block.type == BlockType.ifBlock || block.type == BlockType.ifElseBlock) {
        bool conditionMet = false;
        if (block.condition == "atSign") {
          conditionMet = penguinRow == signRow && penguinCol == signCol;
        } else if (block.condition == "notAtSign") {
          conditionMet = !(penguinRow == signRow && penguinCol == signCol);
        } else if (block.condition == "atFish") {
          conditionMet = penguinRow == 0 && penguinCol == 0;
        } else if (block.condition == "notAtFish") {
          conditionMet = !(penguinRow == 0 && penguinCol == 0);
        }
        if (conditionMet) {
          final result = await _execute(block.children, inLoop: inLoop, parentPath: currentPath);
          if (result != _ExecResult.continueProgram) return result;
        } else if (block.type == BlockType.ifElseBlock) {
          final result = await _execute(block.elseChildren, inLoop: inLoop, parentPath: currentPath);
          if (result != _ExecResult.continueProgram) return result;
        }
      } else if (block.type == BlockType.stop) {
        if (inLoop) {
          return _ExecResult.breakLoop;
        } else {
          return _ExecResult.stopProgram;
        }
      }
    }
    setState(() {
      runningBlockPath = null;
    });
    return _ExecResult.continueProgram;
  }

  void _showLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maksimum jumlah blok tercapai!')),
    );
  }

  int _countBlocks(List<Block> blocks) {
    int count = 0;
    for (var block in blocks) {
      count++;
      if (block.type == BlockType.repeat || block.type == BlockType.ifBlock || block.type == BlockType.ifElseBlock) {
        count += _countBlocks(block.children);
        count += _countBlocks(block.elseChildren);
      }
    }
    return count;
  }

  Block _getBlockByPath(List<Block> root, List<int> path) {
    Block current = root[path[0]];
    for (int i = 1; i < path.length; i++) {
      if (path[i] >= 1000) {
        current = current.elseChildren[path[i] - 1000];
      } else {
        current = current.children[path[i]];
      }
    }
    return current;
  }

  void _removeBlockByPath(List<Block> root, List<int> path) {
    if (path.length == 1) {
      root.removeAt(path[0]);
    } else {
      List<int> parentPath = path.sublist(0, path.length - 1);
      Block parent = _getBlockByPath(root, parentPath);
      int idx = path.last;
      if (idx >= 1000) {
        parent.elseChildren.removeAt(idx - 1000);
      } else {
        parent.children.removeAt(idx);
      }
    }
  }

  void _insertBlockByPath(List<Block> root, List<int> path, int insertAt, Block block) {
    if (path.isEmpty) {
      root.insert(insertAt, block);
    } else {
      Block parent = _getBlockByPath(root, path);
      if (insertAt >= 1000) {
        parent.elseChildren.insert(insertAt - 1000, block);
      } else {
        parent.children.insert(insertAt, block);
      }
    }
  }

  bool _isDescendant(List<int> ancestor, List<int> descendant) {
    if (ancestor.length >= descendant.length) return false;
    for (int i = 0; i < ancestor.length; i++) {
      if (ancestor[i] != descendant[i]) return false;
    }
    return true;
  }

  Widget buildBlock(Block block, List<int> path, {int indent = 0}) {
    final isRunning = runningBlockPath != null && runningBlockPath!.join(',') == path.join(',');
    final isLoopActive = runningBlockPath != null &&
        runningBlockPath!.length > path.length &&
        List.generate(path.length, (i) => runningBlockPath![i] == path[i]).every((e) => e);

    Widget dragWrap(Widget child) => LongPressDraggable<List<int>>(
          data: path,
          delay: const Duration(milliseconds: 100),
          feedback: Material(
            color: Colors.transparent,
            child: _blockChip(block, dragging: true, highlight: isRunning),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: _blockChip(block, highlight: isRunning)),
          child: DragTarget<List<int>>(
            onWillAccept: (fromPath) {
              if (fromPath == null) return false;
              if (fromPath.toString() == path.toString()) return false;
              if (_isDescendant(fromPath, path)) return false;
              return true;
            },
            onAccept: (fromPath) {
              setState(() {
                Block moved = _getBlockByPath(program, fromPath);
                _removeBlockByPath(program, fromPath);
                _insertBlockByPath(program, path.sublist(0, path.length - 1), path.last, moved);
              });
            },
            builder: (context, candidateData, rejectedData) {
              return child;
            },
          ),
        );

    // IF...ELSE block
    if (block.type == BlockType.ifElseBlock) {
      return Padding(
        padding: EdgeInsets.only(left: indent * 20.0, bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isLoopActive ? Colors.deepPurple[200] : Colors.deepPurple[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  dragWrap(_blockChip(block, highlight: isRunning)),
                  DropdownButton<String>(
                    value: block.condition.isEmpty ? null : block.condition,
                    hint: const Text("Condition", style: TextStyle(fontFamily: 'Jua', fontSize: 13)),
                    items: const [
                      DropdownMenuItem(value: "atSign", child: Text("at Sign")),
                      DropdownMenuItem(value: "notAtSign", child: Text("not at Sign")),
                      DropdownMenuItem(value: "atFish", child: Text("at Fish")),
                      DropdownMenuItem(value: "notAtFish", child: Text("not at Fish")),
                    ],
                    onChanged: isRunning
                        ? null
                        : (v) {
                            setState(() {
                              block.condition = v ?? "";
                            });
                          },
                    underline: const SizedBox(),
                    style: const TextStyle(fontFamily: 'Jua', fontSize: 13, color: Colors.black),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 8.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("IF:", style: TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold)),
                    for (int i = 0; i < block.children.length; i++)
                      buildBlock(block.children[i], [...path, i], indent: indent + 1),
                    DragTarget<List<int>>(
                      onWillAccept: (fromPath) {
                        if (fromPath == null) return false;
                        if (_isDescendant(fromPath, [...path, block.children.length])) return false;
                        return true;
                      },
                      onAccept: (fromPath) {
                        setState(() {
                          Block moved = _getBlockByPath(program, fromPath);
                          _removeBlockByPath(program, fromPath);
                          block.children.add(moved);
                        });
                      },
                      builder: (context, candidateData, rejectedData) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty ? Colors.deepPurple[100] : Colors.deepPurple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidateData.isNotEmpty ? Colors.deepPurple : Colors.deepPurple[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.deepPurple, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "Drop block here (IF)",
                              style: TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 12,
                                color: Colors.deepPurple[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Text("ELSE:", style: TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold)),
                    for (int i = 0; i < block.elseChildren.length; i++)
                      buildBlock(block.elseChildren[i], [...path, 1000 + i], indent: indent + 1),
                    DragTarget<List<int>>(
                      onWillAccept: (fromPath) {
                        if (fromPath == null) return false;
                        if (_isDescendant(fromPath, [...path, 1000 + block.elseChildren.length])) return false;
                        return true;
                      },
                      onAccept: (fromPath) {
                        setState(() {
                          Block moved = _getBlockByPath(program, fromPath);
                          _removeBlockByPath(program, fromPath);
                          block.elseChildren.add(moved);
                        });
                      },
                      builder: (context, candidateData, rejectedData) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty ? Colors.deepPurple[100] : Colors.deepPurple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidateData.isNotEmpty ? Colors.deepPurple : Colors.deepPurple[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.deepPurple, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "Drop block here (ELSE)",
                              style: TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 12,
                                color: Colors.deepPurple[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // IF block
    if (block.type == BlockType.ifBlock) {
      return Padding(
        padding: EdgeInsets.only(left: indent * 20.0, bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isLoopActive ? Colors.purple[200] : Colors.purple[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  dragWrap(_blockChip(block, highlight: isRunning)),
                  DropdownButton<String>(
                    value: block.condition.isEmpty ? null : block.condition,
                    hint: const Text("Condition", style: TextStyle(fontFamily: 'Jua', fontSize: 13)),
                    items: const [
                      DropdownMenuItem(value: "atSign", child: Text("at Sign")),
                      DropdownMenuItem(value: "notAtSign", child: Text("not at Sign")),
                      DropdownMenuItem(value: "atFish", child: Text("at Fish")),
                      DropdownMenuItem(value: "notAtFish", child: Text("not at Fish")),
                    ],
                    onChanged: isRunning
                        ? null
                        : (v) {
                            setState(() {
                              block.condition = v ?? "";
                            });
                          },
                    underline: const SizedBox(),
                    style: const TextStyle(fontFamily: 'Jua', fontSize: 13, color: Colors.black),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 8.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < block.children.length; i++)
                      buildBlock(block.children[i], [...path, i], indent: indent + 1),
                    DragTarget<List<int>>(
                      onWillAccept: (fromPath) {
                        if (fromPath == null) return false;
                        if (_isDescendant(fromPath, [...path, block.children.length])) return false;
                        return true;
                      },
                      onAccept: (fromPath) {
                        setState(() {
                          Block moved = _getBlockByPath(program, fromPath);
                          _removeBlockByPath(program, fromPath);
                          block.children.add(moved);
                        });
                      },
                      builder: (context, candidateData, rejectedData) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty ? Colors.purple[100] : Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidateData.isNotEmpty ? Colors.purple : Colors.purple[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.purple, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "Drop block here",
                              style: TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 12,
                                color: Colors.purple[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // LOOP block
    if (block.type == BlockType.repeat) {
      return Padding(
        padding: EdgeInsets.only(left: indent * 20.0, bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isLoopActive ? Colors.green[200] : Colors.green[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  dragWrap(_blockChip(block, highlight: isRunning)),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: !isRunning && block.repeatCount > 2
                        ? () => setState(() => block.repeatCount--)
                        : null,
                  ),
                  Text('x${block.repeatCount}', style: const TextStyle(fontFamily: 'Jua')),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: !isRunning
                        ? () => setState(() => block.repeatCount++)
                        : null,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 8.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < block.children.length; i++)
                      buildBlock(block.children[i], [...path, i], indent: indent + 1),
                    DragTarget<List<int>>(
                      onWillAccept: (fromPath) {
                        if (fromPath == null) return false;
                        if (_isDescendant(fromPath, [...path, block.children.length])) return false;
                        return true;
                      },
                      onAccept: (fromPath) {
                        setState(() {
                          Block moved = _getBlockByPath(program, fromPath);
                          _removeBlockByPath(program, fromPath);
                          block.children.add(moved);
                        });
                      },
                      builder: (context, candidateData, rejectedData) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty ? Colors.green[100] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: candidateData.isNotEmpty ? Colors.green : Colors.green[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "Drop block here",
                              style: TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default: simple block
    return Padding(
      padding: EdgeInsets.only(left: indent * 20.0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dragWrap(_blockChip(block, highlight: isRunning)),
        ],
      ),
    );
  }

  Widget _blockChip(Block block, {bool dragging = false, bool highlight = false}) {
    Color? chipColor;
    if (block.type == BlockType.move) {
      chipColor = highlight ? Colors.blue[300] : (dragging ? Colors.blue[200] : Colors.blue[100]);
      return Chip(
        label: const Text("Move", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.arrow_forward, color: Colors.blue),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else if (block.type == BlockType.moveBack) {
      chipColor = highlight ? Colors.purple[300] : (dragging ? Colors.purple[200] : Colors.purple[100]);
      return Chip(
        label: const Text("Move Back", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.arrow_back, color: Colors.purple),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else if (block.type == BlockType.moveDown) {
      chipColor = highlight ? Colors.orange[300] : (dragging ? Colors.orange[200] : Colors.orange[100]);
      return Chip(
        label: const Text("Move Down", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.arrow_downward, color: Colors.orange),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else if (block.type == BlockType.moveUp) {
      chipColor = highlight ? Colors.teal[300] : (dragging ? Colors.teal[200] : Colors.teal[100]);
      return Chip(
        label: const Text("Move Up", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.arrow_upward, color: Colors.teal),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else if (block.type == BlockType.ifBlock) {
      chipColor = highlight ? Colors.purple[400] : (dragging ? Colors.purple[200] : Colors.purple[100]);
      String label = "If ";
      if (block.condition == "atSign") {
        label += "at Sign";
      } else if (block.condition == "notAtSign") {
        label += "not at Sign";
      } else if (block.condition == "atFish") {
        label += "at Fish";
      } else if (block.condition == "notAtFish") {
        label += "not at Fish";
      } else {
        label += " ";
      }
      return Chip(
        label: Text(label, style: const TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.device_hub, color: Colors.purple),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else if (block.type == BlockType.ifElseBlock) {
      chipColor = highlight ? Colors.deepPurple[400] : (dragging ? Colors.deepPurple[200] : Colors.deepPurple[100]);
      String label = "If...Else ";
      if (block.condition == "atSign") {
        label += "at Sign";
      } else if (block.condition == "notAtSign") {
        label += "not at Sign";
      } else if (block.condition == "atFish") {
        label += "at Fish";
      } else if (block.condition == "notAtFish") {
        label += "not at Fish";
      } else {
        label += " ";
      }
      return Chip(
        label: Text(label, style: const TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.device_hub, color: Colors.deepPurple),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else if (block.type == BlockType.stop) {
      chipColor = highlight ? Colors.red[400] : (dragging ? Colors.red[200] : Colors.red[100]);
      return Chip(
        label: const Text("Stop", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.stop, color: Colors.red),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    } else {
      chipColor = highlight ? Colors.green[400] : (dragging ? Colors.green[200] : Colors.green[100]);
      return Chip(
        label: Text("Loop x${block.repeatCount}", style: const TextStyle(fontFamily: 'Jua', fontSize: 16)),
        backgroundColor: chipColor,
        avatar: const Icon(Icons.repeat, color: Colors.green),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      children: [
        // Page 0: Main game
        Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/igloo3.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Row(
                  children: [
                    const Text("Level 7", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
                    const SizedBox(width: 100),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          showHint = true;
                        });
                      },
                      icon: const Icon(Icons.lightbulb, color: Colors.amber, size: 22),
                      label: const Text("Hint", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[200],
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontFamily: 'Jua', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black),
              ),
              body: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 32, bottom: 4),
                    child: Text(
                      "Level 7: IF & Looping!\nArahkan penguin ke ikan",
                      style: TextStyle(
                        fontFamily: 'Jua',
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Goal: Raih ikan dengan maksimum $goalBlockCount blok!",
                      style: const TextStyle(
                        fontFamily: 'Jua',
                        fontSize: 14,
                        color: Color.fromRGBO(204, 0, 0, 1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 30,
                        itemBuilder: (context, index) {
                          int row = index ~/ 6;
                          int col = index % 6;

                          bool isActive = activeTiles.any((pos) => pos[0] == row && pos[1] == col);
                          if (!isActive) {
                            return const SizedBox.shrink();
                          }

                          if (row == penguinRow && col == penguinCol) {
                            return ScaleTransition(
                              scale: _penguinScale,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.blueAccent, width: 2),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/penguin2.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            );
                          } else if (row == 0 && col == 0) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.blue, width: 2),
                              ),
                              child: Image.asset(
                                'assets/fish.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            );
                          } else if (row == signRow && col == signCol) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.yellow[50],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Center(
                                child: Icon(Icons.signpost, color: Colors.orange, size: 40),
                              ),
                            );
                          } else {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: ElevatedButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              1,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(186, 252, 255, 1),
                            foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            elevation: 0,
                            minimumSize: const Size(100, 30),
                          ),
                          child: const Text(
                            "Program Area",
                            style: TextStyle(fontFamily: 'Jua', fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Overlays (showFail, showSuccess, showTutorial, showHint) can be copied from 3.dart or 5.dart
            if (showFail)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/penguin_sad.png',
                              width: 120,
                              height: 120,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Program kamu salah",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 20, color: Color.fromARGB(255, 54, 158, 244)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  penguinRow = 4;
                                  penguinCol = 0;
                                  showFail = false;
                                  isRunning = false;
                                });
                              },
                              child: const Text("Coba Lagi", style: TextStyle(fontFamily: 'Jua')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showSuccess)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/penguin1.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Program kamu berhasil!",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 28, color: Colors.green),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                await _updateProgress(7);
                                Navigator.pushReplacementNamed(context, '/level8');
                              },
                              child: const Text("Next Level", style: TextStyle(fontFamily: 'Jua')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showTutorial)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => showTutorial = false),
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        color: Colors.white,
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/penguin2.png',
                                width: 100,
                                height: 100,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Level 7",
                                style: TextStyle(
                                  fontFamily: 'Jua',
                                  fontSize: 24,
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "1. Buka area program di bawah!\n"
                                "2. Klik tombol Move, Move Back, Move Down, Move Up, Loop, IF, dan Stop!\n"
                                "3. Susun blok agar penguin bisa ke bawah, ke kanan, ke atas, atau mundur!\n"
                                "4. Jalankan program untuk menggerakkan penguin ke arah ikan!\n"
                                "5. Coba gunakan Loop dan IF untuk lebih efisien!",
                                style: TextStyle(
                                  fontFamily: 'Jua',
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Tap di mana saja untuk mulai!",
                                style: TextStyle(
                                  fontFamily: 'Jua',
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showHint)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb, color: Colors.amber, size: 60),
                            const SizedBox(height: 16),
                            const Text(
                              "Hint",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 24, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Gunakan IF untuk memeriksa posisi penguin!\nCoba gunakan Loop dan Stop untuk efisiensi.",
                              style: TextStyle(fontFamily: 'Jua', fontSize: 18, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  showHint = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Tutup", style: TextStyle(fontFamily: 'Jua')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Page 1: Program area (terminal)
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
            title: const Text("Your Program", style: TextStyle(fontFamily: 'Jua', color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),
              const Opacity(
                opacity: 0.5,
                child: Text(
                  "Tekan, tahan, dan geser",
                  style: TextStyle(fontFamily: 'Jua', fontSize: 13, color: Color.fromARGB(255, 255, 53, 53)),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 600),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                            program.length,
                            (i) => buildBlock(program[i], [i]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: isRunning
                          ? null
                          : () {
                              setState(() {
                                program.clear();
                              });
                            },
                      icon: const Icon(Icons.refresh, color: Colors.blue, size: 20),
                      label: const Text("Reset", style: TextStyle(fontFamily: 'Jua', fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[900],
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(80, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontFamily: 'Jua'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: DragTarget<List<int>>(
                      onWillAccept: (fromPath) => true,
                      onMove: (_) => setState(() => trashActive = true),
                      onLeave: (_) => setState(() => trashActive = false),
                      onAccept: (fromPath) {
                        setState(() {
                          _removeBlockByPath(program, fromPath);
                          trashActive = false;
                        });
                      },
                      builder: (context, candidateData, rejectedData) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.ease,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: trashActive || candidateData.isNotEmpty
                              ? Colors.red[200]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red[300]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete,
                              size: 22,
                              color: trashActive || candidateData.isNotEmpty
                                  ? Colors.red[800]
                                  : Colors.red[400],
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Trash",
                              style: TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 14,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.move)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_forward, color: Colors.blue, size: 22),
                        label: const Text("Move", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.moveBack)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_back, color: Colors.purple, size: 22),
                        label: const Text("Move Back", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[100],
                          foregroundColor: Colors.purple[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.moveDown)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_downward, color: Colors.orange, size: 22),
                        label: const Text("Move Down", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[100],
                          foregroundColor: Colors.orange[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.moveUp)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.arrow_upward, color: Colors.teal, size: 22),
                        label: const Text("Move Up", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[100],
                          foregroundColor: Colors.teal[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.repeat)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.repeat, color: Colors.green, size: 22),
                        label: const Text("Loop", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.ifBlock)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.device_hub, color: Colors.purple, size: 22),
                        label: const Text("IF", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[100],
                          foregroundColor: Colors.purple[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.ifElseBlock)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.device_hub, color: Colors.deepPurple, size: 22),
                        label: const Text("IF...ELSE", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple[100],
                          foregroundColor: Colors.deepPurple[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? null
                            : _countBlocks(program) < maxProgramBlocks
                                ? () => setState(() => program.add(Block(type: BlockType.stop)))
                                : _showLimitMessage,
                        icon: const Icon(Icons.stop, color: Colors.red, size: 22),
                        label: const Text("Stop", style: TextStyle(fontFamily: 'Jua', fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isRunning ? null : runProgram,
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                  label: const Text("Run", style: TextStyle(fontFamily: 'Jua', fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}