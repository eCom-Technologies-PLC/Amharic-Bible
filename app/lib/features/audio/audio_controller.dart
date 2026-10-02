import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../core/vkey.dart';
import '../../data/audio_repository.dart';
import '../../domain/models.dart';
import '../../domain/streak.dart';
import '../../state/providers.dart';

enum AudioStatus { idle, loading, ready, error }

enum AudioError { notConfigured, notAvailable, failed }

@immutable
class AudioState {
  const AudioState({
    this.status = AudioStatus.idle,
    this.version,
    this.book,
    this.chapter,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.currentVerse,
    this.hasTimings = false,
    this.error,
    this.sleepAt,
    this.sleepAtEndOfChapter = false,
  });

  final AudioStatus status;
  final BibleVersion? version;
  final Book? book;
  final int? chapter;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;
  final int? currentVerse; // vkey of the verse being read, when timings exist
  final bool hasTimings;
  final AudioError? error;
  final DateTime? sleepAt;
  final bool sleepAtEndOfChapter;

  bool get active => book != null && status != AudioStatus.idle;

  bool isChapter(String versionId, String bookCode, int ch) =>
      version?.id == versionId && book?.code == bookCode && chapter == ch;

  AudioState copyWith({
    AudioStatus? status,
    BibleVersion? version,
    Book? book,
    int? chapter,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    int? Function()? currentVerse,
    bool? hasTimings,
    AudioError? Function()? error,
    DateTime? Function()? sleepAt,
    bool? sleepAtEndOfChapter,
  }) => AudioState(
    status: status ?? this.status,
    version: version ?? this.version,
    book: book ?? this.book,
    chapter: chapter ?? this.chapter,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    currentVerse: currentVerse != null ? currentVerse() : this.currentVerse,
    hasTimings: hasTimings ?? this.hasTimings,
    error: error != null ? error() : this.error,
    sleepAt: sleepAt != null ? sleepAt() : this.sleepAt,
    sleepAtEndOfChapter: sleepAtEndOfChapter ?? this.sleepAtEndOfChapter,
  );
}

/// Creates the platform player; replaced in tests.
final audioPlayerFactoryProvider = Provider<AudioPlayer Function()>((ref) => AudioPlayer.new);

class AudioController extends Notifier<AudioState> {
  AudioPlayer? _player;
  ChapterAudio? _audio;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _sleepTimer;
  int _loadSeq = 0;
  bool _chapterCredited = false; // streak: this chapter already counted

  @override
  AudioState build() {
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _sleepTimer?.cancel();
      _player?.dispose();
    });
    return const AudioState();
  }

  AudioRepository get _repo => ref.read(audioRepositoryProvider);

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = ref.read(audioPlayerFactoryProvider)();
    _subs
      ..add(p.positionStream.listen(_onPosition))
      ..add(
        p.playerStateStream.listen((s) {
          state = state.copyWith(playing: s.playing);
          if (s.processingState == ProcessingState.completed) _onCompleted();
        }),
      )
      ..add(
        p.durationStream.listen((d) {
          if (d != null) state = state.copyWith(duration: d);
        }),
      );
    return _player = p;
  }

  void _onPosition(Duration pos) {
    final audio = _audio;
    final book = state.book;
    int? current;
    if (audio != null && audio.hasTimings && book != null) {
      final v = audio.verseAt(pos);
      if (v != null) current = vkey(book.num, state.chapter!, v);
    }
    state = state.copyWith(position: pos, currentVerse: () => current);
    final duration = state.duration;
    if (duration != null && duration > Duration.zero && pos >= duration * audioCreditFraction) _creditChapter();
  }

  void _creditChapter() {
    if (_chapterCredited || state.book == null) return;
    _chapterCredited = true;
    unawaited(recordReadingDay(ref, ReadingSource.audio));
  }

  /// Load and play a chapter, optionally starting at a verse.
  Future<void> playChapter(BibleVersion version, Book book, int chapter, {int? fromVerse}) async {
    final seq = ++_loadSeq;
    _chapterCredited = false;
    state = state.copyWith(
      status: AudioStatus.loading,
      version: version,
      book: book,
      chapter: chapter,
      position: Duration.zero,
      currentVerse: () => null,
      error: () => null,
    );
    if (!_repo.configured) {
      state = state.copyWith(status: AudioStatus.error, error: () => AudioError.notConfigured);
      return;
    }
    if (!version.hasAudio) {
      state = state.copyWith(status: AudioStatus.error, error: () => AudioError.notAvailable);
      return;
    }
    try {
      final audio = await _repo.resolve(version.audioFilesetId!, book.code, chapter);
      if (seq != _loadSeq) return; // superseded by a newer request
      _audio = audio;
      final player = _ensurePlayer();
      await player.setAudioSource(
        AudioSource.uri(
          audio.uri,
          tag: MediaItem(
            id: '${version.audioFilesetId}/${book.code}/$chapter',
            title: '${book.shortName} $chapter',
            album: version.localName,
          ),
        ),
      );
      final start = fromVerse != null ? audio.startOf(fromVerse) : null;
      if (start != null) await player.seek(start);
      state = state.copyWith(status: AudioStatus.ready, hasTimings: audio.hasTimings);
      unawaited(player.play());
    } on AudioUnavailable {
      if (seq != _loadSeq) return;
      state = state.copyWith(status: AudioStatus.error, error: () => AudioError.notAvailable);
    } catch (e) {
      if (seq != _loadSeq) return;
      debugPrint('audio load failed: $e');
      state = state.copyWith(status: AudioStatus.error, error: () => AudioError.failed);
    }
  }

  Future<void> togglePlay() async {
    final p = _player;
    if (p == null) return;
    p.playing ? await p.pause() : await p.play();
  }

  Future<void> seek(Duration d) async => _player?.seek(d);

  Future<void> skip(Duration delta) async {
    final p = _player;
    if (p == null) return;
    var target = p.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    final dur = p.duration;
    if (dur != null && target > dur) target = dur;
    await p.seek(target);
  }

  /// Seek to a verse in the loaded chapter; returns false without timings.
  Future<bool> seekToVerse(int key) async {
    final start = _audio?.startOf(vkeyVerse(key));
    if (start == null) return false;
    await _player?.seek(start);
    return true;
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _player?.setSpeed(speed);
  }

  void setSleepTimer(Duration? after, {bool endOfChapter = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (after != null) {
      _sleepTimer = Timer(after, () {
        _player?.pause();
        state = state.copyWith(sleepAt: () => null);
      });
    }
    state = state.copyWith(
      sleepAt: () => after != null ? DateTime.now().add(after) : null,
      sleepAtEndOfChapter: endOfChapter,
    );
  }

  Future<void> next() => _advance(1);
  Future<void> previous() => _advance(-1);

  Future<void> _advance(int dir) async {
    final version = state.version, book = state.book, chapter = state.chapter;
    if (version == null || book == null || chapter == null) return;
    final target = await ref.read(contentRepositoryProvider).neighbourChapter(version.id, book, chapter, dir);
    if (target != null) await playChapter(version, target.$1, target.$2);
  }

  void _onCompleted() {
    _creditChapter();
    if (state.sleepAtEndOfChapter) {
      state = state.copyWith(sleepAtEndOfChapter: false, playing: false);
      return;
    }
    unawaited(next());
  }

  Future<void> stop() async {
    _loadSeq++;
    await _player?.stop();
    _audio = null;
    setSleepTimer(null);
    state = const AudioState().copyWith(speed: state.speed);
  }
}

final audioControllerProvider = NotifierProvider<AudioController, AudioState>(AudioController.new);
