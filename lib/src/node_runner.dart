import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class NodeRunnerError implements Exception {
  final String message;
  NodeRunnerError(this.message);
  @override
  String toString() => "NodeRunnerError: $message";
}

class NodeRunnerEmptyResponseError extends NodeRunnerError {
  NodeRunnerEmptyResponseError(super.message);
}

class NodeRunnerUndefinedResponseError extends NodeRunnerError {
  NodeRunnerUndefinedResponseError(super.message);
}

class NodeRunnerInvalidResponseError extends NodeRunnerError {
  NodeRunnerInvalidResponseError(super.message);
}

class NodeRunner {
  final String code;
  String? functionName;
  Process? _process;
  StreamSubscription? _stdoutSub;
  final List<Completer<String>> _completerQueue = [];

  NodeRunner(this.code);

  Future<void> init() async {
    await _startProcess();
  }

  bool get isRunning => _process != null;

  Future<void> _startProcess() async {
    final runnerPath = _findRunnerJsPath();
    final runnerFile = File(runnerPath);

    if (runnerFile.existsSync()) {
      try {
        final proc = await Process.start('node', [runnerPath]);
        _process = proc;
        _setupStdout();
        return;
      } catch (_) {
        close();
      }
    }

    throw NodeRunnerError("Local node runner unavailable.");
  }

  void _setupStdout() {
    if (_process == null) return;
    final lines = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    _stdoutSub = lines.listen((line) {
      if (_completerQueue.isNotEmpty) {
        final completer = _completerQueue.removeAt(0);
        completer.complete(line);
      }
    }, onError: (err) {
      if (_completerQueue.isNotEmpty) {
        final completer = _completerQueue.removeAt(0);
        completer.completeError(err);
      }
    }, onDone: () {
      if (_completerQueue.isNotEmpty) {
        final completer = _completerQueue.removeAt(0);
        completer.completeError(NodeRunnerEmptyResponseError("Node runner returned EOF"));
      }
    });
  }

  String _findRunnerJsPath() {
    try {
      final scriptFile = File(Platform.script.toFilePath());
      var dir = scriptFile.parent;
      while (dir.path != dir.parent.path) {
        final possible = File(p.join(dir.path, 'lib', 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possible.existsSync()) {
          return possible.path;
        }
        final possibleDirect = File(p.join(dir.path, 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possibleDirect.existsSync()) {
          return possibleDirect.path;
        }
        dir = dir.parent;
      }
    } catch (_) {}

    try {
      var dir = Directory.current;
      while (dir.path != dir.parent.path) {
        final possible = File(p.join(dir.path, 'lib', 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possible.existsSync()) {
          return possible.path;
        }
        final possibleDirect = File(p.join(dir.path, 'src', 'sig_nsig', 'vm', 'runner.js'));
        if (possibleDirect.existsSync()) {
          return possibleDirect.path;
        }
        dir = dir.parent;
      }
    } catch (_) {}

    return "lib/src/sig_nsig/vm/runner.js";
  }

  static String _exposed(String code, String funName) {
    final exposed = "_exposed['$funName']=$funName;})(_yt_player);";
    return code.replaceFirst("})(_yt_player);", exposed);
  }

  Future<void> restart() async {
    final name = functionName;
    close();
    await _startProcess();
    if (name != null) {
      await loadFunction(name);
    }
  }

  Future<dynamic> _send(Map<String, dynamic> data) async {
    if (_process == null) {
      await _startProcess();
    }

    final completer = Completer<String>();
    _completerQueue.add(completer);
    
    try {
      _process!.stdin.write(json.encode(data) + "\n");
      await _process!.stdin.flush();
    } catch (_) {
      _completerQueue.remove(completer);
      close();
      throw NodeRunnerError("Failed to write to node process");
    }
    
    try {
      final rawLine = await completer.future;
      final line = rawLine.trim();
      if (line.isEmpty) {
        throw NodeRunnerEmptyResponseError("Node runner returned a blank line");
      }
      if (line == "undefined") {
        throw NodeRunnerUndefinedResponseError("Node runner returned undefined");
      }
      
      try {
        return json.decode(line);
      } catch (e) {
        throw NodeRunnerInvalidResponseError("Node runner returned non-JSON output: $line");
      }
    } catch (e) {
      close();
      rethrow;
    }
  }

  Future<dynamic> loadFunction(String funcName) async {
    functionName = funcName;
    return _send({
      "type": "load",
      "code": _exposed(code, funcName)
    });
  }

  Future<dynamic> call(List<dynamic> args) async {
    return _send({
      "type": "call",
      "fun": functionName,
      "args": args
    });
  }

  void close() {
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _process?.kill();
    _process = null;
    for (final completer in _completerQueue) {
      if (!completer.isCompleted) {
        completer.completeError(NodeRunnerError("Process closed"));
      }
    }
    _completerQueue.clear();
  }
}
