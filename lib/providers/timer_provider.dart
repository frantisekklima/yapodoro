import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/session.dart';

enum AppTimerMode { classic, dynamicMode }

enum AppTimerState { idle, working, breakTime, paused }

class TimerProvider extends ChangeNotifier {
  // Singleton instance
  static final TimerProvider instance = TimerProvider();

  // Timer States
  AppTimerMode _mode = AppTimerMode.classic;
  AppTimerState _state = AppTimerState.idle;
  AppTimerState _pausedState = AppTimerState.idle; // Stores which state was paused

  AppTimerMode get mode => _mode;
  AppTimerState get state => _state;
  AppTimerState get pausedState => _pausedState;

  // Settings (Classic)
  int _classicWorkMinutes = 25;
  int _classicShortBreakMinutes = 5;
  int _classicLongBreakMinutes = 15;
  int _classicLongBreakInterval = 4; // Every 4th break is long

  int get classicWorkMinutes => _classicWorkMinutes;
  int get classicShortBreakMinutes => _classicShortBreakMinutes;
  int get classicLongBreakMinutes => _classicLongBreakMinutes;
  int get classicLongBreakInterval => _classicLongBreakInterval;

  // Settings (Dynamic)
  double _dynamicDivisor = 4.0;
  int _carryOverBreakSeconds = 0;

  double get dynamicDivisor => _dynamicDivisor;
  int get carryOverBreakSeconds => _carryOverBreakSeconds;

  // Active Timer Counters
  int _elapsedSeconds = 0; // Counts up in dynamic work
  int _remainingSeconds = 0; // Counts down in classic work, and both breaks
  int _totalDurationForCurrentSegment = 0; // To compute percentage/progress
  int _currentFlowSessionIndex = 0; // Tracks the focus/break count of the current continuous flow

  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;
  int get totalDurationForCurrentSegment => _totalDurationForCurrentSegment;
  int get currentFlowSessionIndex => _currentFlowSessionIndex;

  // Stats
  List<WorkSession> _sessions = [];
  List<WorkSession> get sessions => _sessions;

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Ticking variables
  Timer? _ticker;
  DateTime? _segmentTargetTime; // When the current countdown segment should end
  DateTime? _workStartTime;     // When the current count-up segment started
  int _secondsBeforePause = 0;  // Keeps track of elapsed/remaining seconds at the time of pause

  // Properties for rendering progress
  double get progressPercentage {
    if (_state == AppTimerState.idle) return 0.0;
    if (_mode == AppTimerMode.dynamicMode && (_state == AppTimerState.working || (_state == AppTimerState.paused && _pausedState == AppTimerState.working))) {
      // Dynamic work has no progress ring filling
      return 0.0;
    }
    if (_totalDurationForCurrentSegment == 0) return 0.0;
    
    if (_state == AppTimerState.working && _mode == AppTimerMode.classic) {
      return (totalDurationForCurrentSegment - _remainingSeconds) / totalDurationForCurrentSegment;
    } else if (_state == AppTimerState.breakTime) {
      return (totalDurationForCurrentSegment - _remainingSeconds) / totalDurationForCurrentSegment;
    }
    
    // Paused state handles progress based on which state it paused from
    if (_state == AppTimerState.paused) {
      if (_pausedState == AppTimerState.working && _mode == AppTimerMode.classic) {
        return (totalDurationForCurrentSegment - _remainingSeconds) / totalDurationForCurrentSegment;
      } else if (_pausedState == AppTimerState.breakTime) {
        return (totalDurationForCurrentSegment - _remainingSeconds) / totalDurationForCurrentSegment;
      }
    }
    return 0.0;
  }

  // Constructor
  TimerProvider() {
    _init();
  }

  // Load configuration and data from SharedPreferences
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Settings
    _classicWorkMinutes = prefs.getInt('classicWorkMinutes') ?? 25;
    _classicShortBreakMinutes = prefs.getInt('classicShortBreakMinutes') ?? 5;
    _classicLongBreakMinutes = prefs.getInt('classicLongBreakMinutes') ?? 15;
    _classicLongBreakInterval = prefs.getInt('classicLongBreakInterval') ?? 4;
    _dynamicDivisor = prefs.getDouble('dynamicDivisor') ?? 4.0;
    _carryOverBreakSeconds = prefs.getInt('carryOverBreakSeconds') ?? 0;
    
    // Load Mode
    final savedMode = prefs.getString('appTimerMode');
    if (savedMode != null) {
      _mode = savedMode == 'classic' ? AppTimerMode.classic : AppTimerMode.dynamicMode;
    }

    // Load Sessions
    final sessionsJson = prefs.getString('work_sessions');
    if (sessionsJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(sessionsJson) as List<dynamic>;
        _sessions = decodedList.map((item) => WorkSession.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Error decoding sessions: $e");
      }
    }
    notifyListeners();
  }

  // Toggle Mode
  void setMode(AppTimerMode newMode) {
    if (_state != AppTimerState.idle) return; // Can only change mode when idle
    _mode = newMode;
    _saveMode();
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  // Save Settings to SharedPreferences
  Future<void> saveSettings({
    int? workMin,
    int? shortBreakMin,
    int? longBreakMin,
    int? longBreakInterval,
    double? divisor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (workMin != null) {
      _classicWorkMinutes = workMin;
      prefs.setInt('classicWorkMinutes', workMin);
    }
    if (shortBreakMin != null) {
      _classicShortBreakMinutes = shortBreakMin;
      prefs.setInt('classicShortBreakMinutes', shortBreakMin);
    }
    if (longBreakMin != null) {
      _classicLongBreakMinutes = longBreakMin;
      prefs.setInt('classicLongBreakMinutes', longBreakMin);
    }
    if (longBreakInterval != null) {
      _classicLongBreakInterval = longBreakInterval;
      prefs.setInt('classicLongBreakInterval', longBreakInterval);
    }
    if (divisor != null) {
      _dynamicDivisor = divisor;
      prefs.setDouble('dynamicDivisor', divisor);
    }
    notifyListeners();
  }

  Future<void> _saveMode() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('appTimerMode', _mode == AppTimerMode.classic ? 'classic' : 'dynamic');
  }

  Future<void> _saveCarryOver() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('carryOverBreakSeconds', _carryOverBreakSeconds);
  }

  // Actions
  void startTimer() {
    if (_state != AppTimerState.idle) return;
    
    _state = AppTimerState.working;
    HapticFeedback.mediumImpact();
    
    if (_mode == AppTimerMode.classic) {
      _totalDurationForCurrentSegment = _classicWorkMinutes * 60;
      _remainingSeconds = _totalDurationForCurrentSegment;
      _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    } else {
      _elapsedSeconds = 0;
      _workStartTime = DateTime.now();
    }
    
    _startTicker();
    notifyListeners();
  }

  void pauseTimer() {
    if (_state != AppTimerState.working && _state != AppTimerState.breakTime) return;
    
    _pausedState = _state;
    _state = AppTimerState.paused;
    _stopTicker();
    HapticFeedback.lightImpact();

    // Store state before pausing to avoid drift upon resume
    if (_pausedState == AppTimerState.working && _mode == AppTimerMode.dynamicMode) {
      _secondsBeforePause = _elapsedSeconds;
    } else {
      _secondsBeforePause = _remainingSeconds;
    }
    notifyListeners();
  }

  void resumeTimer() {
    if (_state != AppTimerState.paused) return;
    
    _state = _pausedState;
    HapticFeedback.mediumImpact();

    // Recalculate target times based on remaining time stored
    if (_state == AppTimerState.working && _mode == AppTimerMode.dynamicMode) {
      _workStartTime = DateTime.now().subtract(Duration(seconds: _secondsBeforePause));
    } else {
      _remainingSeconds = _secondsBeforePause;
      _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    }
    
    _startTicker();
    notifyListeners();
  }

  void stopTimer() {
    if (_state == AppTimerState.idle) return;

    // If stopping in dynamic work, save work completed so far
    if (_state == AppTimerState.working && _mode == AppTimerMode.dynamicMode) {
      _logSession(_elapsedSeconds);
    } else if (_state == AppTimerState.paused && _pausedState == AppTimerState.working && _mode == AppTimerMode.dynamicMode) {
      _logSession(_secondsBeforePause);
    }
    
    _currentFlowSessionIndex = 0;
    _resetTimerEngine();
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  // Start Break in Dynamic Mode
  void triggerDynamicBreak() {
    if (_mode != AppTimerMode.dynamicMode) return;
    if (_state != AppTimerState.working && !(_state == AppTimerState.paused && _pausedState == AppTimerState.working)) return;

    int workDuration = _state == AppTimerState.working ? _elapsedSeconds : _secondsBeforePause;
    
    // Log the work session
    _logSession(workDuration);

    // Calculate break duration
    int baseBreak = (workDuration / _dynamicDivisor).round();
    int totalBreak = baseBreak + _carryOverBreakSeconds;

    // Reset carry over since we are consuming it
    _carryOverBreakSeconds = 0;
    _saveCarryOver();

    // Transition to break
    _currentFlowSessionIndex++;
    _state = AppTimerState.breakTime;
    _totalDurationForCurrentSegment = totalBreak;
    _remainingSeconds = totalBreak;
    _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _startTicker();
    _playAlertSound();
    notifyListeners();
  }

  // Skip Work to Break in Classic Mode
  void skipToClassicBreak() {
    if (_mode != AppTimerMode.classic) return;
    if (_state != AppTimerState.working && !(_state == AppTimerState.paused && _pausedState == AppTimerState.working)) return;

    int workedSeconds = _state == AppTimerState.working
        ? (_totalDurationForCurrentSegment - _remainingSeconds)
        : (_totalDurationForCurrentSegment - _secondsBeforePause);

    // Log the focus session if it lasted more than 5s
    if (workedSeconds >= 5) {
      _logSession(workedSeconds);
    }

    // Transition to break
    _stopTicker();
    int totalWorkSessions = _sessions.length;
    bool isLongBreak = totalWorkSessions > 0 && (totalWorkSessions % _classicLongBreakInterval == 0);
    int baseBreakMinutes = isLongBreak ? _classicLongBreakMinutes : _classicShortBreakMinutes;

    int totalBreakSeconds = (baseBreakMinutes * 60) + _carryOverBreakSeconds;
    _carryOverBreakSeconds = 0;
    _saveCarryOver();

    _currentFlowSessionIndex++;
    _state = AppTimerState.breakTime;
    _totalDurationForCurrentSegment = totalBreakSeconds;
    _remainingSeconds = totalBreakSeconds;
    _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _startTicker();
    _playAlertSound();
    notifyListeners();
  }

  // Resume Work Early (Rolls over break time)
  void resumeWorkEarly() {
    if (_state != AppTimerState.breakTime && !(_state == AppTimerState.paused && _pausedState == AppTimerState.breakTime)) return;

    int breakRemaining = _state == AppTimerState.breakTime ? _remainingSeconds : _secondsBeforePause;
    
    // Save carry over
    _carryOverBreakSeconds += breakRemaining;
    _saveCarryOver();

    // Stop current break and transition back to working state
    _stopTicker();
    _state = AppTimerState.working;
    HapticFeedback.mediumImpact();

    if (_mode == AppTimerMode.classic) {
      _totalDurationForCurrentSegment = _classicWorkMinutes * 60;
      _remainingSeconds = _totalDurationForCurrentSegment;
      _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    } else {
      _elapsedSeconds = 0;
      _workStartTime = DateTime.now();
    }

    _startTicker();
    notifyListeners();
  }

  // Internal Ticker Management
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _tick();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _resetTimerEngine() {
    _stopTicker();
    _state = AppTimerState.idle;
    _pausedState = AppTimerState.idle;
    _elapsedSeconds = 0;
    _remainingSeconds = 0;
    _totalDurationForCurrentSegment = 0;
    _segmentTargetTime = null;
    _workStartTime = null;
  }

  void _tick() {
    if (_state == AppTimerState.working) {
      if (_mode == AppTimerMode.classic) {
        if (_segmentTargetTime != null) {
          final diff = _segmentTargetTime!.difference(DateTime.now()).inSeconds;
          if (diff <= 0) {
            _remainingSeconds = 0;
            _handleClassicWorkCompleted();
          } else {
            if (_remainingSeconds != diff) {
              _remainingSeconds = diff;
              notifyListeners();
            }
          }
        }
      } else {
        // Dynamic mode counts up
        if (_workStartTime != null) {
          final diff = DateTime.now().difference(_workStartTime!).inSeconds;
          if (_elapsedSeconds != diff) {
            _elapsedSeconds = diff;
            notifyListeners();
          }
        }
      }
    } else if (_state == AppTimerState.breakTime) {
      if (_segmentTargetTime != null) {
        final diff = _segmentTargetTime!.difference(DateTime.now()).inSeconds;
        if (diff <= 0) {
          _remainingSeconds = 0;
          _handleBreakCompleted();
        } else {
          if (_remainingSeconds != diff) {
            _remainingSeconds = diff;
            notifyListeners();
          }
        }
      }
    }
  }

  // Complete work segment in Classic Mode
  void _handleClassicWorkCompleted() {
    _stopTicker();
    _logSession(_classicWorkMinutes * 60);

    // Calculate which break it is
    int totalWorkSessions = _sessions.length;
    bool isLongBreak = totalWorkSessions > 0 && (totalWorkSessions % _classicLongBreakInterval == 0);
    int baseBreakMinutes = isLongBreak ? _classicLongBreakMinutes : _classicShortBreakMinutes;

    int totalBreakSeconds = (baseBreakMinutes * 60) + _carryOverBreakSeconds;
    _carryOverBreakSeconds = 0;
    _saveCarryOver();

    // Transition to break
    _currentFlowSessionIndex++;
    _state = AppTimerState.breakTime;
    _totalDurationForCurrentSegment = totalBreakSeconds;
    _remainingSeconds = totalBreakSeconds;
    _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _startTicker();
    _playAlertSound();
    notifyListeners();
  }

  // Complete break segment
  void _handleBreakCompleted() {
    _resetTimerEngine();
    _playAlertSound();
    notifyListeners();
  }

  // Save Session data
  Future<void> _logSession(int durationInSeconds) async {
    if (durationInSeconds < 5) return; // Ignore micro-sessions less than 5 seconds

    final newSession = WorkSession(
      date: DateTime.now(),
      durationSeconds: durationInSeconds,
    );
    _sessions.add(newSession);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = _sessions.map((s) => s.toJson()).toList();
    prefs.setString('work_sessions', jsonEncode(jsonList));
    notifyListeners();
  }

  // Clean all session data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('work_sessions');
    await prefs.remove('carryOverBreakSeconds');
    _sessions.clear();
    _carryOverBreakSeconds = 0;
    _currentFlowSessionIndex = 0;
    _resetTimerEngine();
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  // Play Sound Effect
  Future<void> _playAlertSound() async {
    try {
      HapticFeedback.vibrate();
      await _audioPlayer.play(AssetSource('bell.wav'));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  // Disposal
  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // STATS HELPERS
  
  // Total work seconds since using the app
  int get lifetimeWorkSeconds {
    return _sessions.fold(0, (sum, s) => sum + s.durationSeconds);
  }

  // Seconds worked today
  int get todayWorkSeconds {
    final today = DateTime.now();
    return _sessions
        .where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day)
        .fold(0, (sum, s) => sum + s.durationSeconds);
  }

  // Seconds worked in the current week (ISO week starting on Monday)
  int get weekWorkSeconds {
    final now = DateTime.now();
    // Find the Monday of the current week
    final daysToSubtract = now.weekday - 1;
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
    final nextMonday = monday.add(const Duration(days: 7));

    return _sessions
        .where((s) => s.date.isAfter(monday.subtract(const Duration(seconds: 1))) && s.date.isBefore(nextMonday))
        .fold(0, (sum, s) => sum + s.durationSeconds);
  }

  // Seconds worked in the current calendar month
  int get monthWorkSeconds {
    final now = DateTime.now();
    return _sessions
        .where((s) => s.date.year == now.year && s.date.month == now.month)
        .fold(0, (sum, s) => sum + s.durationSeconds);
  }

  // Seconds worked in the current calendar year
  int get yearWorkSeconds {
    final now = DateTime.now();
    return _sessions
        .where((s) => s.date.year == now.year)
        .fold(0, (sum, s) => sum + s.durationSeconds);
  }

  // Map of YYYY-MM-DD -> total minutes worked (for GitHub grid)
  Map<String, double> get dailyMinutesMap {
    final Map<String, double> map = {};
    for (final s in _sessions) {
      final key = s.dateString;
      final minutes = s.durationSeconds / 60.0;
      map[key] = (map[key] ?? 0) + minutes;
    }
    return map;
  }
}
