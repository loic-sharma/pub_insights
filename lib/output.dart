String duration(Stopwatch stopwatch) {
  final duration = stopwatch.elapsed;
  final seconds = duration.inSeconds;
  final minutes = duration.inMinutes;
  final hours = duration.inHours;

  if (seconds <= 60) {
    return '$seconds seconds';
  } else if (minutes <= 60) {
    return '$minutes minutes';
  } else {
    return '$hours hours';
  }
}
