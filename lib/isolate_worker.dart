import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:console_bars/console_bars.dart';

Future<void> launchWorkers<TWork>(
  Queue<TWork> work,
  Future<void> Function(TWork work) workProcessor,
) async {
  final statusBar = FillingBar(
    desc: 'Working',
    total: work.length,
  );

  List<Future> controllers = [];
  for (var i = 0; i < Platform.numberOfProcessors; i++) {
    controllers.add(launchController(statusBar, work, workProcessor));
  }

  await Future.wait(controllers);
  print('');
}

Future<void> launchController<TWork>(
  FillingBar statusBar,
  Queue<TWork> work,
  Future<void> Function(TWork work) workProcessor,
) async {
  final workerPort = ReceivePort();
  await Isolate.spawn(
    createWorkerIsolate(workProcessor),
    workerPort.sendPort,
  );

  final workerEvents = StreamQueue<dynamic>(workerPort);

  // Receive the port to submit work.
  final controllerPort = await workerEvents.next as SendPort;

  while (work.isNotEmpty) {
    // Submit work.
    controllerPort.send(work.removeFirst());

    // Receive result for work.
    await workerEvents.next;

    // Update status bar.
    statusBar.increment();
  }

  // Done. Signal the worker that it should exit and cleanup.
  controllerPort.send(null);
  await workerEvents.cancel();
}

Future<void> Function(SendPort) createWorkerIsolate<TWork>(
  Future<void> Function(TWork work) workProcessor,
) {
  return (SendPort resultPort) async {
    // Send the controller a port to submit work.
    final controllerPort = ReceivePort();
    resultPort.send(controllerPort.sendPort);

    // Process the controller's work.
    await for (final message in controllerPort) {
      if (message == null) break;

      if (message is TWork) {
        // Do work.
        await workProcessor(message);

        // Notify the controller of the result.
        resultPort.send(null);
      }
    }

    Isolate.exit();
  };
}
