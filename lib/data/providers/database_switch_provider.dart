import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prevents watched queries from reconnecting while the dataset is switching.
final databaseSwitchProvider = NotifierProvider<DatabaseSwitch, bool>(
  DatabaseSwitch.new,
);

class DatabaseSwitch extends Notifier<bool> {
  @override
  bool build() => false;

  void begin() => state = true;
  void complete() => state = false;
}
