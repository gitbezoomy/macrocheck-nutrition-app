import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage the current bottom navigation index.
final navigationProvider = StateProvider<int>((ref) => 0);
