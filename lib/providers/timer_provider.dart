import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session.dart';
import '../services/notification_service.dart';

enum AppTimerMode { classic, dynamicMode }

enum AppTimerState { idle, working, breakTime, paused }

class TimerProvider extends ChangeNotifier with WidgetsBindingObserver {
  // Singleton instance
  static final TimerProvider instance = TimerProvider();

  // Timer States
  AppTimerMode _mode = AppTimerMode.classic;
  AppTimerState _state = AppTimerState.idle;
  AppTimerState _pausedState = AppTimerState.idle; // Stores which state was paused
  bool _isAppInForeground = true;                  // Tracks if app is active in the foreground
  bool _enableBreakRollover = true;                // Option to roll over early break exit time to the next break

  AppTimerMode get mode => _mode;
  bool get enableBreakRollover => _enableBreakRollover;
  AppTimerState get state => _state;
  AppTimerState get pausedState => _pausedState;

  // Settings (Classic)
  int _classicWorkMinutes = 25;
  int _classicShortBreakMinutes = 5;
  int _classicLongBreakMinutes = 15;
  int _classicLongBreakInterval = 4; // Every 4th break is long
  int _classicFocusCount = 0;        // Sessional counter of completed Classic Focus segments (independent of Dynamic mode)

  int get classicWorkMinutes => _classicWorkMinutes;
  int get classicShortBreakMinutes => _classicShortBreakMinutes;
  int get classicLongBreakMinutes => _classicLongBreakMinutes;
  int get classicLongBreakInterval => _classicLongBreakInterval;
  int get classicFocusCount => _classicFocusCount;

  // Settings (Dynamic)
  double _dynamicDivisor = 4.0;
  int _classicCarryOverBreakSeconds = 0; // Break overflow time for Classic Mode
  int _dynamicCarryOverBreakSeconds = 0; // Break overflow time for Dynamic Mode
  int _dynamicFocusCount = 0; // Sessional counter of completed Dynamic Focus segments (independent of Classic mode)

  double get dynamicDivisor => _dynamicDivisor;
  int get classicCarryOverBreakSeconds => _classicCarryOverBreakSeconds;
  int get dynamicCarryOverBreakSeconds => _dynamicCarryOverBreakSeconds;
  int get carryOverBreakSeconds => _mode == AppTimerMode.classic ? _classicCarryOverBreakSeconds : _dynamicCarryOverBreakSeconds;
  int get dynamicFocusCount => _dynamicFocusCount;

  // Active Timer Counters
  int _elapsedSeconds = 0; // Counts up in dynamic work
  int _remainingSeconds = 0; // Counts down in classic work, and both breaks
  int _totalDurationForCurrentSegment = 0; // To compute percentage/progress

  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;
  int get totalDurationForCurrentSegment => _totalDurationForCurrentSegment;

  // Dynamic getter returning active mode sessional count
  int get currentFlowSessionIndex {
    return _mode == AppTimerMode.classic ? _classicFocusCount : _dynamicFocusCount;
  }

  // Stats
  List<WorkSession> _sessions = [];
  List<WorkSession> get sessions => _sessions;

  List<WorkSession> _breakSessions = [];
  List<WorkSession> get breakSessions => _breakSessions;

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
    WidgetsBinding.instance.addObserver(this);
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
    _classicCarryOverBreakSeconds = prefs.getInt('classicCarryOverBreakSeconds') ?? prefs.getInt('carryOverBreakSeconds') ?? 0;
    _dynamicCarryOverBreakSeconds = prefs.getInt('dynamicCarryOverBreakSeconds') ?? 0;
    _enableBreakRollover = prefs.getBool('enableBreakRollover') ?? true;
    _classicFocusCount = prefs.getInt('classicFocusCount') ?? 0;
    _dynamicFocusCount = prefs.getInt('dynamicFocusCount') ?? 0;
    
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

    // Load Break Sessions
    final breakSessionsJson = prefs.getString('break_sessions');
    if (breakSessionsJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(breakSessionsJson) as List<dynamic>;
        _breakSessions = decodedList.map((item) => WorkSession.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Error decoding break sessions: $e");
      }
    }

    // Restore Saved Timer State
    final savedStateName = prefs.getString('timer_state');
    if (savedStateName != null) {
      final savedState = AppTimerState.values.firstWhere((e) => e.name == savedStateName, orElse: () => AppTimerState.idle);
      final savedModeName = prefs.getString('timer_mode');
      final savedMode = AppTimerMode.values.firstWhere((e) => e.name == savedModeName, orElse: () => AppTimerMode.classic);
      
      _state = savedState;
      _mode = savedMode;
      
      final pausedStateName = prefs.getString('timer_paused_state');
      _pausedState = pausedStateName != null 
          ? AppTimerState.values.firstWhere((e) => e.name == pausedStateName, orElse: () => AppTimerState.idle)
          : AppTimerState.idle;
      
      final targetTimeStr = prefs.getString('segment_target_time') ?? '';
      _segmentTargetTime = targetTimeStr.isNotEmpty ? DateTime.tryParse(targetTimeStr) : null;
      
      final startTimeStr = prefs.getString('work_start_time') ?? '';
      _workStartTime = startTimeStr.isNotEmpty ? DateTime.tryParse(startTimeStr) : null;
      
      _remainingSeconds = prefs.getInt('remaining_seconds') ?? 0;
      _elapsedSeconds = prefs.getInt('elapsed_seconds') ?? 0;
      _secondsBeforePause = prefs.getInt('paused_seconds') ?? 0;

      // Handle recovery of active timers
      if (_state == AppTimerState.working || _state == AppTimerState.breakTime) {
        if (_mode == AppTimerMode.classic || _state == AppTimerState.breakTime) {
          if (_segmentTargetTime != null) {
            final diff = _segmentTargetTime!.difference(DateTime.now()).inSeconds;
            if (diff <= 0) {
              // Timer already completed while app was closed
              _remainingSeconds = 0;
              if (_state == AppTimerState.working) {
                _handleClassicWorkCompleted();
              } else {
                _handleBreakCompleted();
              }
            } else {
              // Timer still running, resume ticking
              _remainingSeconds = diff;
              _startTicker();
              _updateSystemNotifications();
            }
          }
        } else {
          // Dynamic mode working: recalculate count-up
          if (_workStartTime != null) {
            _elapsedSeconds = DateTime.now().difference(_workStartTime!).inSeconds;
            _startTicker();
            _updateSystemNotifications();
          }
        }
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

  Future<void> _saveClassicCarryOver() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('classicCarryOverBreakSeconds', _classicCarryOverBreakSeconds);
  }

  Future<void> _saveDynamicCarryOver() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dynamicCarryOverBreakSeconds', _dynamicCarryOverBreakSeconds);
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
    NotificationService.instance.cancelCompletionReminder();
    _updateSystemNotifications();
    _saveTimerState();
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
    _updateSystemNotifications();
    _saveTimerState();
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
    NotificationService.instance.cancelCompletionReminder();
    _updateSystemNotifications();
    _saveTimerState();
    notifyListeners();
  }

  void stopTimer() {
    if (_state == AppTimerState.idle) return;

    // Log the work completed so far if stopping during work
    if (_state == AppTimerState.working) {
      int workedSeconds = _mode == AppTimerMode.dynamicMode
          ? _elapsedSeconds
          : (_totalDurationForCurrentSegment - _remainingSeconds);
      if (workedSeconds > 0) {
        _logSession(workedSeconds);
      }
    } else if (_state == AppTimerState.paused && _pausedState == AppTimerState.working) {
      int workedSeconds = _mode == AppTimerMode.dynamicMode
          ? _secondsBeforePause
          : (_totalDurationForCurrentSegment - _secondsBeforePause);
      if (workedSeconds > 0) {
        _logSession(workedSeconds);
      }
    }

    // Log the break completed so far if stopping during a break
    if (_state == AppTimerState.breakTime) {
      int breakSeconds = _totalDurationForCurrentSegment - _remainingSeconds;
      if (breakSeconds > 0) {
        _logBreakSession(breakSeconds);
      }
    } else if (_state == AppTimerState.paused && _pausedState == AppTimerState.breakTime) {
      int breakSeconds = _totalDurationForCurrentSegment - _secondsBeforePause;
      if (breakSeconds > 0) {
        _logBreakSession(breakSeconds);
      }
    }
    
    if (_mode == AppTimerMode.classic) {
      _classicFocusCount = 0;
      _saveClassicFocusCount();
      _classicCarryOverBreakSeconds = 0;
      _saveClassicCarryOver();
    } else {
      _dynamicFocusCount = 0;
      _saveDynamicFocusCount();
      _dynamicCarryOverBreakSeconds = 0;
      _saveDynamicCarryOver();
    }

    _resetTimerEngine();
    NotificationService.instance.cancelCompletionReminder();
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
    int totalBreak = baseBreak + _dynamicCarryOverBreakSeconds;

    // Reset carry over since we are consuming it
    _dynamicCarryOverBreakSeconds = 0;
    _saveDynamicCarryOver();

    // Transition to break
    _dynamicFocusCount++;
    _saveDynamicFocusCount();
    _state = AppTimerState.breakTime;
    _totalDurationForCurrentSegment = totalBreak;
    _remainingSeconds = totalBreak;
    _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _startTicker();
    _playAlertSound();
    _updateSystemNotifications();
    _saveTimerState();
    // Show static Focus Completed notification only if in background
    if (!_isAppInForeground) {
      NotificationService.instance.showSessionCompleteNotification(
        title: "Focus Completed!",
        body: "Your break has started. Tap to view the timer.",
      );
    }
    notifyListeners();
  }

  // Skip Work to Break in Classic Mode
  void skipToClassicBreak() {
    if (_mode != AppTimerMode.classic) return;
    if (_state != AppTimerState.working && !(_state == AppTimerState.paused && _pausedState == AppTimerState.working)) return;

    int workedSeconds = _state == AppTimerState.working
        ? (_totalDurationForCurrentSegment - _remainingSeconds)
        : (_totalDurationForCurrentSegment - _secondsBeforePause);

    // Log the focus session regardless of speed (so that fast skips count towards Focus of the day)
    _logSession(workedSeconds);

    // Transition to break
    _stopTicker();
    _classicFocusCount++;
    _saveClassicFocusCount();
    int totalWorkSessions = _classicFocusCount;
    bool isLongBreak = totalWorkSessions > 0 && (totalWorkSessions % _classicLongBreakInterval == 0);
    int baseBreakMinutes = isLongBreak ? _classicLongBreakMinutes : _classicShortBreakMinutes;

    int totalBreakSeconds = (baseBreakMinutes * 60) + _classicCarryOverBreakSeconds;
    _classicCarryOverBreakSeconds = 0;
    _saveClassicCarryOver();

    _state = AppTimerState.breakTime;
    _totalDurationForCurrentSegment = totalBreakSeconds;
    _remainingSeconds = totalBreakSeconds;
    _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _startTicker();
    _playAlertSound();
    _updateSystemNotifications();
    _saveTimerState();
    notifyListeners();
  }

  // Resume Work Early (Rolls over break time)
  void resumeWorkEarly() {
    if (_state != AppTimerState.breakTime && !(_state == AppTimerState.paused && _pausedState == AppTimerState.breakTime)) return;

    int breakRemaining = _state == AppTimerState.breakTime ? _remainingSeconds : _secondsBeforePause;
    
    // Log the actual break seconds spent
    int spentBreakSeconds = _totalDurationForCurrentSegment - breakRemaining;
    if (spentBreakSeconds > 0) {
      _logBreakSession(spentBreakSeconds);
    }

    // Save carry over if break rollover is enabled
    if (_enableBreakRollover) {
      if (_mode == AppTimerMode.classic) {
        _classicCarryOverBreakSeconds += breakRemaining;
        _saveClassicCarryOver();
      } else {
        _dynamicCarryOverBreakSeconds += breakRemaining;
        _saveDynamicCarryOver();
      }
    } else {
      if (_mode == AppTimerMode.classic) {
        _classicCarryOverBreakSeconds = 0;
        _saveClassicCarryOver();
      } else {
        _dynamicCarryOverBreakSeconds = 0;
        _saveDynamicCarryOver();
      }
    }

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
    _updateSystemNotifications();
    _saveTimerState();
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
    _updateSystemNotifications();
    _clearSavedTimerState();
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

    // Calculate which break it is (based entirely on Classic Focus count)
    _classicFocusCount++;
    _saveClassicFocusCount();
    int totalWorkSessions = _classicFocusCount;
    bool isLongBreak = totalWorkSessions > 0 && (totalWorkSessions % _classicLongBreakInterval == 0);
    int baseBreakMinutes = isLongBreak ? _classicLongBreakMinutes : _classicShortBreakMinutes;

    int totalBreakSeconds = (baseBreakMinutes * 60) + _classicCarryOverBreakSeconds;
    _classicCarryOverBreakSeconds = 0;
    _saveClassicCarryOver();

    // Transition to break
    _state = AppTimerState.breakTime;
    _totalDurationForCurrentSegment = totalBreakSeconds;
    _remainingSeconds = totalBreakSeconds;
    _segmentTargetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    _startTicker();
    _playAlertSound();
    _updateSystemNotifications();
    _saveTimerState();
    // Show static Focus Completed notification only if in background
    if (!_isAppInForeground) {
      NotificationService.instance.showSessionCompleteNotification(
        title: "Focus Completed!",
        body: "Your break has started automatically. Tap to view the timer.",
      );
    }
    notifyListeners();
  }

  // Complete break segment
  void _handleBreakCompleted() {
    _logBreakSession(_totalDurationForCurrentSegment);
    _resetTimerEngine();
    _playAlertSound();
    // Show static Break Completed notification only if in background
    if (!_isAppInForeground) {
      NotificationService.instance.showSessionCompleteNotification(
        title: "Break Completed!",
        body: "Tap to return to the app and start your next focus session.",
      );
    }
    notifyListeners();
  }

  // Save Session data
  Future<void> _logSession(int durationInSeconds) async {
    // Log every session regardless of duration so that fast skips count towards Focus of the day!

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

  // Save Break Session data
  Future<void> _logBreakSession(int durationInSeconds) async {
    if (durationInSeconds <= 0) return;

    final newSession = WorkSession(
      date: DateTime.now(),
      durationSeconds: durationInSeconds,
    );
    _breakSessions.add(newSession);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = _breakSessions.map((s) => s.toJson()).toList();
    prefs.setString('break_sessions', jsonEncode(jsonList));
    notifyListeners();
  }

  // Clean all session data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('work_sessions');
    await prefs.remove('break_sessions');
    await prefs.remove('carryOverBreakSeconds');
    await prefs.remove('classicCarryOverBreakSeconds');
    await prefs.remove('dynamicCarryOverBreakSeconds');
    await prefs.remove('classicFocusCount');
    await prefs.remove('dynamicFocusCount');
    _classicFocusCount = 0;
    _dynamicFocusCount = 0;
    _sessions.clear();
    _breakSessions.clear();
    _classicCarryOverBreakSeconds = 0;
    _dynamicCarryOverBreakSeconds = 0;
    _resetTimerEngine();
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  // Reset all user settings configurations to defaults
  Future<void> resetSettingsToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    _classicWorkMinutes = 25;
    _classicShortBreakMinutes = 5;
    _classicLongBreakMinutes = 15;
    _classicLongBreakInterval = 4;
    _dynamicDivisor = 4.0;
    _enableBreakRollover = true;

    await prefs.setInt('classicWorkMinutes', 25);
    await prefs.setInt('classicShortBreakMinutes', 5);
    await prefs.setInt('classicLongBreakMinutes', 15);
    await prefs.setInt('classicLongBreakInterval', 4);
    await prefs.setDouble('dynamicDivisor', 4.0);
    await prefs.setBool('enableBreakRollover', true);

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
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // App Foreground / Background Lifecycle sync
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _handleForegroundResume();
    }
  }

  Future<void> _handleForegroundResume() async {
    // Check if SCHEDULE_EXACT_ALARM permission was revoked mid-session
    if (_state == AppTimerState.working || _state == AppTimerState.breakTime) {
      final exactAlarmGranted = await Permission.scheduleExactAlarm.isGranted;
      if (!exactAlarmGranted) {
        // Revoked: pause timer and show warning
        pauseTimer();
        notifyListeners();
      }
    }
    // Force immediate time recalculation tick
    _tick();
  }

  // State Serialization & Persistent Storage
  Future<void> _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timer_state', _state.name);
    await prefs.setString('timer_mode', _mode.name);
    await prefs.setString('timer_paused_state', _pausedState.name);
    await prefs.setString('segment_target_time', _segmentTargetTime?.toIso8601String() ?? '');
    await prefs.setString('work_start_time', _workStartTime?.toIso8601String() ?? '');
    await prefs.setInt('remaining_seconds', _remainingSeconds);
    await prefs.setInt('elapsed_seconds', _elapsedSeconds);
    await prefs.setInt('paused_seconds', _secondsBeforePause);
  }

  Future<void> _clearSavedTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_state');
    await prefs.remove('timer_mode');
    await prefs.remove('timer_paused_state');
    await prefs.remove('segment_target_time');
    await prefs.remove('work_start_time');
    await prefs.remove('remaining_seconds');
    await prefs.remove('elapsed_seconds');
    await prefs.remove('paused_seconds');
  }

  // Native Notifications presentation interface
  void _updateSystemNotifications() {
    if (_state == AppTimerState.idle) {
      NotificationService.instance.cancelTimerNotifications();
      return;
    }

    final isBreak = _state == AppTimerState.breakTime;
    final isClassic = _mode == AppTimerMode.classic;
    final String phaseTitle = isBreak ? "Break Active" : "Focus Session Active";

    if (_state == AppTimerState.working || _state == AppTimerState.breakTime) {
      if (isClassic || isBreak) {
        if (_segmentTargetTime != null) {
          // Format target end time to hh:mm for premium high-utility readability
          final endTimeStr = "${_segmentTargetTime!.hour.toString().padLeft(2, '0')}:${_segmentTargetTime!.minute.toString().padLeft(2, '0')}";
          final bodyText = isBreak 
              ? "Ends at $endTimeStr • Take a relaxing break!" 
              : "Ends at $endTimeStr • Keep up the great work!";

          // Show active countdown chronometer in drawer
          NotificationService.instance.updateTimerNotification(
            title: phaseTitle,
            body: bodyText,
            endTime: _segmentTargetTime!,
            isCountdown: true,
          );

          // Schedule high-priority alarm notification when timer completes
          NotificationService.instance.scheduleCompletionAlarm(
            title: isBreak ? "Break Completed!" : "Focus Segment Completed!",
            body: isBreak ? "Ready to start focusing again?" : "Time to take a well-deserved break!",
            endTime: _segmentTargetTime!,
          );
        }
      } else {
        // Dynamic mode work counts up
        if (_workStartTime != null) {
          NotificationService.instance.updateTimerNotification(
            title: "Dynamic Focus Active",
            body: "Focusing without a strict deadline...",
            endTime: _workStartTime!,
            isCountdown: false,
          );
        }
      }
    } else if (_state == AppTimerState.paused) {
      // Paused state: show static pause notification with exact remaining time
      final bool pausedBreak = _pausedState == AppTimerState.breakTime;
      final String pausedTitle = pausedBreak ? "Break Paused" : "Focus Paused";
      
      String remainingText = "";
      if (pausedBreak || _mode == AppTimerMode.classic) {
        remainingText = "Time remaining: ${_secondsBeforePause ~/ 60}:${(_secondsBeforePause % 60).toString().padLeft(2, '0')}";
      } else {
        remainingText = "Time focused: ${_secondsBeforePause ~/ 60}:${(_secondsBeforePause % 60).toString().padLeft(2, '0')}";
      }

      // First cancel the active scheduled alarm while retaining status bar notification
      NotificationService.instance.cancelAlarmNotification();
      
      NotificationService.instance.showPausedNotification(
        title: pausedTitle,
        timeRemainingText: remainingText,
      );
    }
  }

  // Permission Request Interface
  Future<void> checkAndRequestPermissions(BuildContext context) async {
    // 1. Notification Permission (Android 13+)
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }

    // 2. Exact Alarm Permission (Android 13+ SCHEDULE_EXACT_ALARM)
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    if (!exactAlarmStatus.isGranted) {
      if (context.mounted) {
        final bool? accept = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Alarms & Reminders Permission"),
            content: const Text(
              "Yet Another Pomodoro needs the Alarms & Reminders permission to play completion sounds precisely on time in the background.\n\n"
              "Please allow this permission on the next settings screen."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("CANCEL"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("PROCEED"),
              ),
            ],
          ),
        );

        if (accept == true) {
          await Permission.scheduleExactAlarm.request();
        }
      }
    }

    // 3. Battery Optimizations exemption for OEM survival
    final batteryOptStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryOptStatus.isGranted) {
      if (context.mounted) {
        final bool? acceptBattery = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Battery Optimization Exemption"),
            content: const Text(
              "To prevent aggressive background task killers from stopping your timer, please exempt Yet Another Pomodoro from battery optimization on the next settings screen."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("CANCEL"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("PROCEED"),
              ),
            ],
          ),
        );

        if (acceptBattery == true) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }
    }
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

  // Seconds spent on break today
  int get todayBreakSeconds {
    final today = DateTime.now();
    return _breakSessions
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

  // Save Classic Focus Count
  Future<void> _saveClassicFocusCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('classicFocusCount', _classicFocusCount);
  }

  // Save Dynamic Focus Count
  Future<void> _saveDynamicFocusCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dynamicFocusCount', _dynamicFocusCount);
  }

  // Setter to dynamically enable or disable the Break Rollover feature
  Future<void> setEnableBreakRollover(bool value) async {
    _enableBreakRollover = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableBreakRollover', value);
    if (!value) {
      _classicCarryOverBreakSeconds = 0;
      _dynamicCarryOverBreakSeconds = 0;
      _saveClassicCarryOver();
      _saveDynamicCarryOver();
    }
    notifyListeners();
  }
}
