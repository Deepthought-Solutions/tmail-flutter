import 'package:equatable/equatable.dart';

class CalDavConflict with EquatableMixin {
  final String title;
  final DateTime start;
  final DateTime end;

  CalDavConflict({
    required this.title,
    required this.start,
    required this.end,
  });

  @override
  List<Object?> get props => [title, start, end];
}
