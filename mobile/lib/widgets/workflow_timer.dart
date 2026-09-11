import 'dart:async';

import 'package:flutter/material.dart';

class WorkflowTimer extends StatefulWidget {
  const WorkflowTimer({
    required this.duration,
    required this.onCompleted,
    this.onStarted,
    super.key,
  });

  final Duration duration;
  final VoidCallback onCompleted;
  final VoidCallback? onStarted;

  @override
  State<WorkflowTimer> createState() => _WorkflowTimerState();
}

class _WorkflowTimerState extends State<WorkflowTimer> {
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _remaining = Duration.zero;
  bool _hasStarted = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
  }

  @override
  void didUpdateWidget(covariant WorkflowTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration && !_hasStarted) {
      setState(() => _remaining = widget.duration);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (_hasStarted || _isComplete) {
      return;
    }

    _hasStarted = true;
    _startedAt = DateTime.now();
    widget.onStarted?.call();
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final startedAt = _startedAt;
    if (startedAt == null || _isComplete) {
      return;
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = widget.duration - elapsed;
    if (remaining <= Duration.zero) {
      _ticker?.cancel();
      setState(() {
        _remaining = Duration.zero;
        _isComplete = true;
      });
      widget.onCompleted();
      return;
    }

    if (mounted) {
      setState(() => _remaining = remaining);
    }
  }

  String _formatRemaining(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 999999);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          label: _isComplete
              ? 'Step complete'
              : 'Time remaining ${_formatRemaining(_remaining)}',
          child: Text(
            _isComplete ? 'Step complete' : _formatRemaining(_remaining),
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 12),
        if (!_hasStarted && !_isComplete)
          FilledButton(
            onPressed: _start,
            child: const Text('Start Timer'),
          )
        else if (!_isComplete)
          const Text('Timer running'),
      ],
    );
  }
}
