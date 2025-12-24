import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Memory branch model for V3: private conversation forking
class MemoryBranch {
  final int id;
  final int characterId;
  final int? parentBranchId;
  final String name;
  final bool isPrivate;
  final DateTime createdAt;

  MemoryBranch({
    required this.id,
    required this.characterId,
    this.parentBranchId,
    required this.name,
    this.isPrivate = true,
    required this.createdAt,
  });

  factory MemoryBranch.fromMap(Map<String, dynamic> map) {
    return MemoryBranch(
      id: map['id'] as int,
      characterId: map['character_id'] as int,
      parentBranchId: map['parent_branch_id'] as int?,
      name: map['name'] as String,
      isPrivate: (map['is_private'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'character_id': characterId,
      'parent_branch_id': parentBranchId,
      'name': name,
      'is_private': isPrivate ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Service for managing memory branches (V3: memory forking)
class MemoryBranchService extends ChangeNotifier {
  final DatabaseService _db;
  List<MemoryBranch> _branches = [];
  MemoryBranch? _currentBranch;
  bool _isLoading = false;

  MemoryBranchService(this._db);

  List<MemoryBranch> get branches => _branches;
  MemoryBranch? get currentBranch => _currentBranch;
  bool get isLoading => _isLoading;

  /// Load all memory branches for a character
  Future<void> loadBranches(int characterId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final branchMaps = await _db.getCharacterMemoryBranches(characterId);
      _branches = branchMaps.map((m) => MemoryBranch.fromMap(m)).toList();
    } catch (e) {
      print('Error loading memory branches: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new memory branch (fork from main or another branch)
  Future<MemoryBranch?> createBranch({
    required int characterId,
    required String name,
    int? parentBranchId,
    bool isPrivate = true,
  }) async {
    try {
      final branchMap = await _db.createMemoryBranch(
        characterId: characterId,
        name: name,
        parentBranchId: parentBranchId,
        isPrivate: isPrivate,
      );

      if (branchMap != null) {
        final branch = MemoryBranch.fromMap(branchMap);
        _branches.insert(0, branch);
        notifyListeners();
        return branch;
      }
    } catch (e) {
      print('Error creating memory branch: $e');
    }
    return null;
  }

  /// Merge a branch back to main (share memory)
  Future<bool> mergeBranch(int branchId) async {
    try {
      final success = await _db.mergeMemoryBranch(branchId);

      if (success) {
        // Update local branch list
        final index = _branches.indexWhere((b) => b.id == branchId);
        if (index >= 0) {
          final oldBranch = _branches[index];
          _branches[index] = MemoryBranch(
            id: oldBranch.id,
            characterId: oldBranch.characterId,
            parentBranchId: oldBranch.parentBranchId,
            name: oldBranch.name,
            isPrivate: false,
            createdAt: oldBranch.createdAt,
          );
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      print('Error merging memory branch: $e');
      return false;
    }
  }

  /// Set current active branch
  void setCurrentBranch(MemoryBranch? branch) {
    _currentBranch = branch;
    notifyListeners();
  }

  /// Get branch hierarchy (for visualization)
  /// Get branch hierarchy with cycle detection
  List<MemoryBranch> getBranchHierarchy(int branchId) {
    final hierarchy = <MemoryBranch>[];
    final visited = <int>{};
    var currentId = branchId;

    while (true) {
      // Detect circular references to prevent infinite loop
      if (visited.contains(currentId)) {
        break;
      }
      visited.add(currentId);

      // Safe lookup without throwing
      final matches = _branches.where((b) => b.id == currentId);
      if (matches.isEmpty) break;
      final branch = matches.first;

      hierarchy.insert(0, branch);

      if (branch.parentBranchId == null) break;
      currentId = branch.parentBranchId!;
    }

    return hierarchy;
  }
}
