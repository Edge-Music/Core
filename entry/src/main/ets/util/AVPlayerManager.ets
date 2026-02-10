import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { common, WantAgent, wantAgent } from '@kit.AbilityKit';
import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';
import { PlaylistManager } from './PlaylistManager';
import { ClickUtil, LogUtil } from '@pura/harmony-utils';
import { EventHelper } from './EventHelper';
import { PreferencesCache } from './PreferenceCache';
import { SourceAdapter } from '../adapter';
import { Song } from '../type/Adapter';
import LyricsManager from './LyricsManager';
import { JSON } from '@kit.ArkTS';
import { window } from '@kit.ArkUI';
import WindowUtil from './WindowUtil';
import { commonEventManager,BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { notificationManager } from '@kit.NotificationKit';
import { AudioRendererPlayer,
  DecodeAudioProgress,
  PcmDecoderTool, PcmStreamDecoder, PcmStreamInfo } from '@ospark/free-pcm';
import map from '@hms.core.map.map';

const TAG = 'AVPlayerManager'
// 定义回调函数的类型
export interface PlayerCallbacks {
  onPlay: Array<() => void>;
  onPause: Array<() => void>;
  onStop: Array<() => void>;
  onSeek: Array<(position: number) => void>;
  onStateChange: Array<(state: string) => void>;
  onError: Array<(error: Error) => void>;
  onCompleted: Array<() => void>;
  onAudioInterrupt: Array<(info: audio.InterruptEvent) => void>;
  onBufferingUpdate: Array<(progress: number) => void>;
  onDurationChange: Array<(duration: number) => void>;
}

class AVPlayerManager {
  // NOTE: AVPlayer has been replaced by Free-PCM pipeline (PcmDecoderTool + AudioRendererPlayer).
  // This file intentionally does NOT import the Free-PCM library. In the target project,
  // ensure the following symbols are available via imports:
  // - PcmDecoderTool, AudioRendererPlayer, PcmStreamDecoder, PcmStreamInfo
  avPlayer: AudioRendererPlayer | null = null;

  private decoderTool: PcmDecoderTool = new PcmDecoderTool()
  private currentDecoder: PcmStreamDecoder | null = null;
  private currentStreamInfo: PcmStreamInfo | null = null;
  private currentSource: string = '';
  private prepared: boolean = false;

  // Volume lifecycle:
  // AudioRendererPlayer.setVolume() only works after AudioRenderer is created.
  // We cache desired volume and apply it after play() creates the renderer.
  private desiredVolume: number = 1.0;

  // Playback completion:
  // decoder.done indicates decode EOS, but playback may still be draining.
  private decodeDone: boolean = false;
  private completionTimer: number = -1;
  private lastPositionMs: number = 0;
  private lastPositionUpdateTs: number = 0;
  private completionFired: boolean = false;

  // Sequence guard for async callbacks.
  private sourceSeq: number = 0;

  // Ensure we don't double-bind renderer event listeners.
  private rendererListenersBound: boolean = false;
  audioManager = audio?.getAudioManager()
  audioSessionManager: audio.AudioSessionManager = this.audioManager?.getSessionManager()
  private avSession: avSession.AVSession | null = null;
  private currentPlaybackState: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
  private context: common.UIAbilityContext | undefined;
  private cachedAvMetadata: avSession.AVMetadata | null = null; // 缓存的元数据
  // 初始化所有回调为空数组
  private callbacks: PlayerCallbacks = {
    onPlay: [],
    onPause: [],
    onStop: [],
    onSeek: [],
    onStateChange: [],
    onError: [],
    onCompleted: [],
    onAudioInterrupt: [],
    onBufferingUpdate: [],
    onDurationChange: []
  };
  private isPlayingBeforeInterrupt: boolean = false;

  // 淡入淡出相关属性
  private fadeTimer: number = -1;
  private readonly FADE_DURATION: number = 750; // 淡入淡出持续时间(毫秒)
  private readonly FADE_STEPS: number = 20; // 淡入淡出步骤数
  private currentVolume: number = 1.0; // 当前音量

  public async init(context: common.UIAbilityContext) {
    this.context = context;
    await this.initAVSession();
  }

  // 添加回调监听
  public addListener(type: keyof PlayerCallbacks, callback: Function) {
    switch (type) {
      case 'onPlay':
        this.callbacks.onPlay.push(callback as () => void);
        break;
      case 'onPause':
        this.callbacks.onPause.push(callback as () => void);
        break;
      case 'onStop':
        this.callbacks.onStop.push(callback as () => void);
        break;
      case 'onSeek':
        this.callbacks.onSeek.push(callback as (position: number) => void);
        break;
      case 'onStateChange':
        this.callbacks.onStateChange.push(callback as (state: string) => void);
        break;
      case 'onError':
        this.callbacks.onError.push(callback as (error: Error) => void);
        break;
      case 'onCompleted':
        this.callbacks.onCompleted.push(callback as () => void);
        break;
      case 'onAudioInterrupt':
        this.callbacks.onAudioInterrupt.push(callback as (info: audio.InterruptEvent) => void);
        break;
      case 'onBufferingUpdate':
        this.callbacks.onBufferingUpdate.push(callback as (progress: number) => void);
        break;
      case 'onDurationChange':
        this.callbacks.onDurationChange.push(callback as (duration: number) => void);
        break;
    }
  }

  // 移除特定回调监听
  public removeListener(type: keyof PlayerCallbacks, callback: Function) {
    switch (type) {
      case 'onPlay':
        this.callbacks.onPlay = this.callbacks.onPlay.filter(cb => cb !== callback);
        break;
      case 'onPause':
        this.callbacks.onPause = this.callbacks.onPause.filter(cb => cb !== callback);
        break;
      case 'onStop':
        this.callbacks.onStop = this.callbacks.onStop.filter(cb => cb !== callback);
        break;
      case 'onSeek':
        this.callbacks.onSeek = this.callbacks.onSeek.filter(cb => cb !== callback);
        break;
      case 'onStateChange':
        this.callbacks.onStateChange = this.callbacks.onStateChange.filter(cb => cb !== callback);
        break;
      case 'onError':
        this.callbacks.onError = this.callbacks.onError.filter(cb => cb !== callback);
        break;
      case 'onCompleted':
        this.callbacks.onCompleted = this.callbacks.onCompleted.filter(cb => cb !== callback);
        break;
      case 'onAudioInterrupt':
        this.callbacks.onAudioInterrupt = this.callbacks.onAudioInterrupt.filter(cb => cb !== callback);
        break;
      case 'onBufferingUpdate':
        this.callbacks.onBufferingUpdate = this.callbacks.onBufferingUpdate.filter(cb => cb !== callback);
        break;
      case 'onDurationChange':
        this.callbacks.onDurationChange = this.callbacks.onDurationChange.filter(cb => cb !== callback);
        break;
    }
  }

  // 清除指定回调监听
  public clearListener(type: keyof PlayerCallbacks) {
    switch (type) {
      case 'onPlay':
        this.callbacks.onPlay = [];
        break;
      case 'onPause':
        this.callbacks.onPause = [];
        break;
      case 'onStop':
        this.callbacks.onStop = [];
        break;
      case 'onSeek':
        this.callbacks.onSeek = [];
        break;
      case 'onStateChange':
        this.callbacks.onStateChange = [];
        break;
      case 'onError':
        this.callbacks.onError = [];
        break;
      case 'onCompleted':
        this.callbacks.onCompleted = [];
        break;
      case 'onAudioInterrupt':
        this.callbacks.onAudioInterrupt = [];
        break;
      case 'onBufferingUpdate':
        this.callbacks.onBufferingUpdate = [];
        break;
      case 'onDurationChange':
        this.callbacks.onDurationChange = [];
        break;
    }
  }

  // 清除所有回调
  public clearCallbacks() {
    this.callbacks = {
      onPlay: [],
      onPause: [],
      onStop: [],
      onSeek: [],
      onStateChange: [],
      onError: [],
      onCompleted: [],
      onAudioInterrupt: [],
      onBufferingUpdate: [],
      onDurationChange: []
    };
  }

  private triggerPlay() {
    const callbacks = this.callbacks.onPlay;
    callbacks.forEach(callback => {
      callback();
    });
  }

  private triggerPause() {
    const callbacks = this.callbacks.onPause;
    callbacks.forEach(callback => {
      callback();
    });
  }

  private triggerStop() {
    const callbacks = this.callbacks.onStop;
    callbacks.forEach(callback => {
      callback();
    });
  }

  private triggerSeek(position: number) {
    const callbacks = this.callbacks.onSeek;
    callbacks.forEach(callback => {
      callback(position);
    });
  }

  private triggerStateChange(state: string) {
    const callbacks = this.callbacks.onStateChange;
    callbacks.forEach(callback => {
      callback(state);
    });
  }

  private triggerError(error: Error) {
    const callbacks = this.callbacks.onError;
    callbacks.forEach(callback => {
      callback(error);
    });
    LogUtil.error('[AVPlayerManager]', JSON.stringify(error));
  }

  private triggerCompleted() {
    const callbacks = this.callbacks.onCompleted;
    callbacks.forEach(callback => {
      callback();
    });
  }

  private triggerAudioInterrupt(info: audio.InterruptEvent) {
    const callbacks = this.callbacks.onAudioInterrupt;
    callbacks.forEach(callback => {
      callback(info);
    });
  }

  private triggerBufferingUpdate(progress: number) {
    const callbacks = this.callbacks.onBufferingUpdate;
    callbacks.forEach(callback => {
      callback(progress);
    });
  }

  private triggerDurationChange(duration: number) {
    const callbacks = this.callbacks.onDurationChange;
    callbacks.forEach(callback => {
      callback(duration);
    });
  }

  private async initAVSession() {
    try {
      this.avSession = await avSession.createAVSession(this.context!, 'AudioPlayer', 'audio');
      await this.avSession.activate();
      await this.updatePlaybackState(this.currentPlaybackState);
      this.setupMediaSessionListeners();
    } catch (error) {
      this.triggerError(error);
    }
  }

  async initAppVolume() {
    const volume = Number(PreferencesCache.getUserPreference('Volume', '100'))
    const v = Math.max(0, Math.min(1, volume / 100))
    this.desiredVolume = v

    // Best-effort apply if renderer already exists.
    const player = await this.getAVPlayerInstance();
    try {
      await player.setVolume(v)
      this.currentVolume = v
    } catch (e) {
      // Renderer not created yet; will apply after play() creates it.
    }
  }

  private async applyDesiredVolumeIfReady() {
    if (!this.avPlayer) {
      return
    }
    try {
      await this.avPlayer.setVolume(this.desiredVolume)
      this.currentVolume = this.desiredVolume
    } catch (e) {
      // ignore
    }
  }

  private setupMediaSessionListeners() {
    if (!this.avSession) {
      return;
    }

    this.avSession.on('play', () => {
      this.play();
    });

    this.avSession.on('pause', () => {
      this.pauseWithoutFadeOut();
    });

    this.avSession.on('stop', () => {
      this.stop();
    });

    this.avSession.on('seek', (position: number) => {
      // Delegate to manager seek() so Free-PCM pipeline can handle it.
      this.seek(position);
    });

    this.avSession.on('playNext', () => {
      ClickUtil.throttle(async () => {
        const nextSong = PlaylistManager.playNext()
        if (nextSong) {
          PlaylistManager.playSong(nextSong)
        }
      }, 500)
    })

    this.avSession.on('playPrevious', () => {
      ClickUtil.throttle(async () => {
        const prevSong = PlaylistManager.playPrevious()
        if (prevSong) {
          PlaylistManager.playSong(prevSong)
        }
      }, 500)
    })

    this.avSession.on('setLoopMode', () => {
      const mode = PlaylistManager.switchPlayMode()
      if (this.avSession) {
        this.avSession.setAVPlaybackState({
          loopMode: mode
        })
      }
    })

    this.avSession.on('toggleFavorite', (assetId) => {
      const currentSong = AppStorage.get<Song>("current_playing_song");
      if (!currentSong) {
        LogUtil.warn("AVPlayerManager ", "defaultLoveSongCallback", "No current playing song found");
        return;
      }
      // 执行喜欢歌曲的逻辑
      const like = currentSong.meta?.isFavorite
      SourceAdapter.likeSong(currentSong, !like)
      EventHelper.postFavoriteToggle(assetId)
    })
  }

  public async updatePlaybackState(state?: avSession.PlaybackState, position?: number) {
    if (!this.avSession) {
      return;
    }
    if (!state) {
      state = this.currentPlaybackState;
    }

    const playbackState: avSession.AVPlaybackState = {
      state: state === avSession.PlaybackState.PLAYBACK_STATE_PLAY ?
        avSession.PlaybackState.PLAYBACK_STATE_PLAY :
        avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        // Use internal buffer clock (ms) for playback position.
        elapsedTime: position ?? this.avPlayer?.getCurrentPosition() ?? 0,
        updateTime: new Date().getTime()
      },
      speed: 1.0,
      loopMode: PlaylistManager.getPlayMode()
    };
    await this.avSession.setAVPlaybackState(playbackState);
  }

  public getSession() {
    return this.avSession;
  }

  private bindRendererListeners() {
    if (this.rendererListenersBound) {
      return;
    }
    if (!this.avPlayer) {
      return;
    }
    const renderer = this.avPlayer.getRenderer();
    if (!renderer) {
      return;
    }

    this.rendererListenersBound = true;

    // renderer.on('audioOutputDeviceChangeWithInfo', async (info: audio.AudioStreamDeviceChangeInfo) => {
    //   switch (info.changeReason) {
    //     case audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE:
    //       // 设备不可用(如蓝牙断开)，需要暂停播放
    //       await this.pauseWithoutFadeOut()
    //       break;
    //
    //     case audio.AudioStreamDeviceChangeReason.REASON_NEW_DEVICE_AVAILABLE:
    //       // 新设备可用
    //       break;
    //
    //     case audio.AudioStreamDeviceChangeReason.REASON_OVERRODE:
    //       // 设备被切换
    //       break;
    //   }
    // })



    // 设置音频打断监听
    renderer.on('audioInterrupt', async (interruptEvent: audio.InterruptEvent) => {
      // 打印
      LogUtil.info('AVPlayerManager', 'audioInterrupt', JSON.stringify(interruptEvent))
      this.triggerAudioInterrupt(interruptEvent);
      const continuePlaying = PreferencesCache.interruptingContinue()
      if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            // 系统强制暂停（临时失去焦点）
            const tempState = this.isPlayingBeforeInterrupt
            await this.stop();
            this.isPlayingBeforeInterrupt = tempState;
            break;

          case audio.InterruptHint.INTERRUPT_HINT_RESUME:
            // 恢复播放
            if (this.isPlayingBeforeInterrupt) {
              await this.play();
            }
            break;

          case audio.InterruptHint.INTERRUPT_HINT_STOP:
            // 系统强制停止（永久失去焦点）
            this.isPlayingBeforeInterrupt = false;
            await this.stop();
            break;

          case audio.InterruptHint.INTERRUPT_HINT_DUCK:
            // 降低音量（默认降至20%）
            break;

          case audio.InterruptHint.INTERRUPT_HINT_UNDUCK:
            // 恢复音量
            break;

          default:
            break;
        }
      } else {
        // 非强制打断
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            await this.stop();
            break;
          case audio.InterruptHint.INTERRUPT_HINT_RESUME:
            if (this.isPlayingBeforeInterrupt) {
              await this.play();
            }
            break;
          default:
            break;
        }
      }
    });

  }

  async getAVPlayerInstance() {
    if (this.avPlayer !== null) {
      return this.avPlayer;
    }

    const player = new AudioRendererPlayer();
    this.avPlayer = player;


    return player;
  }

  mapAudioState(state:audio.AudioState) {
    switch (state) {
      case audio.AudioState.STATE_NEW:
        return 'initialized';
      case audio.AudioState.STATE_PREPARED:
        return 'prepared';
      case audio.AudioState.STATE_RUNNING:
        return 'playing';
        case audio.AudioState.STATE_PAUSED:
        return 'paused';
      case audio.AudioState.STATE_STOPPED:
        return 'stopped';
      case audio.AudioState.STATE_RELEASED:
        return 'released';
      default:
        return 'unknown';
    }
  }

  async setupAudioRenderer() {
    const player = this.avPlayer?.getRenderer()
    if (!player) return;

    player.on('stateChange', async (state: audio.AudioState) => {

      const stateStr = this.mapAudioState(state)

      this.triggerStateChange(stateStr);

      switch (stateStr) {
        case 'initialized':
          LyricsManager.init();
          break;
        case 'prepared':
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          const duration = this.avPlayer!.getDurationMs();
          this.triggerDurationChange(duration);
          break;
        case 'playing':
          LyricsManager.start();
          this.isPlayingBeforeInterrupt = true;
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
          this.triggerPlay();
          break;
        case 'paused':
          LyricsManager.reset();
          this.isPlayingBeforeInterrupt = false;
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          this.triggerPause();
          break;
        case 'stopped':
          LyricsManager.reset();
          this.isPlayingBeforeInterrupt = false;
          player.stop()
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_IDLE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_IDLE);
          this.triggerStop();
          break;
        case 'released':
          LyricsManager.reset();
          this.isPlayingBeforeInterrupt = false;
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_RELEASED;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_RELEASED);
          this.triggerPause();
          this.triggerStop();
          break;
        default:
          break;
      }
    });
  }

  private parseBooleanPref(value: string): boolean {
    const v = (value ?? '').trim().toLowerCase();
    return v === '1' || v === 'true' || v === 'yes' || v === 'on';
  }

  private clampEqGainDb(g: number): number {
    if (!Number.isFinite(g)) {
      return 0;
    }
    if (g > 24) return 24;
    if (g < -24) return -24;
    return g;
  }

  private loadEqGainsDbFromPreference(): number[] {
    const BAND_COUNT = 10;

    // 获取原始字符串
    const raw: string = PreferencesCache.getUserPreference(
      'eq_gains_db',
      '0,0,0,0,0,0,0,0,0,0'
    );

    // 直接按逗号分割
    const parts = raw.split(',');

    // 校验长度，不符合则直接返回全 0 数组
    if (parts.length !== BAND_COUNT) {
      return Array(BAND_COUNT).fill(0);
    }

    // 类型转换与数值限幅
    return parts.map((p) => {
      const val = Number(p);
      return this.clampEqGainDb(isNaN(val) ? 0 : val);
    });
  }

  private loadEqEnabledFromPreference(): boolean {
    const raw = PreferencesCache.getUserPreference('eq_enabled', '1');
    return this.parseBooleanPref(raw);
  }

  private async cleanupCurrentPipeline() {
    // Stop playback first.
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop();
      } catch (e) {
        // ignore
      }
    }

    // Stop decoding.
    if (this.currentDecoder) {
      try {
        this.currentDecoder.close();
      } catch (e) {
        // ignore
      }
    }

    this.currentDecoder = null;
    this.currentStreamInfo = null;
    this.prepared = false;
    this.rendererListenersBound = false;

    this.decodeDone = false;
    this.completionFired = false;
    this.lastPositionMs = 0;
    this.lastPositionUpdateTs = 0;
    if (this.completionTimer !== -1) {
      clearInterval(this.completionTimer);
      this.completionTimer = -1;
    }
  }

  private async prepareSource(source: string, metadata?: avSession.AVMetadata) {
    await this.getAVPlayerInstance();
    await this.cleanupCurrentPipeline();

    this.sourceSeq++;
    const seq = this.sourceSeq;

    this.currentSource = source;
    this.triggerStateChange('initialized');

    const eqEnabled = this.loadEqEnabledFromPreference();
    const eqGainsDb = this.loadEqGainsDbFromPreference();

    LogUtil.info("AVPlayerManager", "prepareSource", "eqEnabled: " + eqEnabled + ", eqGainsDb: " + eqGainsDb + ", source: " + source);

    const decoder = this.decoderTool.createStreamDecoder(
      source,
      {
        // ringBytes is optional (adaptive) by default.
        eqEnabled,
        eqGainsDb,
        sampleFormat: 3
      },
      {
        onProgress: (p: DecodeAudioProgress) => {
          // Map decode progress to bufferingUpdate (0~100) best-effort.
          if (p.progress >= 0) {
            this.triggerBufferingUpdate(Math.round(p.progress * 100));
          }
        },
        onError: (e: Error) => {
          LogUtil.error(`[${TAG}]`, `Decoder error: ${e.message}`);
          this.triggerError(e);
        },
      }
    );

    this.currentDecoder = decoder;
    const info = await decoder.ready;
    if (this.sourceSeq !== seq) {
      return;
    }
    this.currentStreamInfo = info;
    this.prepared = true;
    this.decodeDone = false;
    this.completionFired = false;

    this.triggerDurationChange(info.durationMs);
    this.triggerStateChange('prepared');

    // Metadata + lyrics init (kept consistent with AVPlayer flow)
    LyricsManager.init();
    if (metadata && this.avSession) {
      await this.avSession.setAVMetadata(metadata);
    }

    // Completion:
    // decoder.done means decode EOS, but playback may still be draining renderer/ring.
    // We only mark decodeDone here and let the playback-side watcher decide when to
    // fire "completed".
    decoder.done
      .then(() => {
        if (this.sourceSeq !== seq || this.currentDecoder !== decoder) {
          return;
        }
        this.decodeDone = true;
        this.startCompletionWatchdog();
      })
      .catch((e: Error) => {
        if (this.sourceSeq !== seq || this.currentDecoder !== decoder) {
          return;
        }
        this.triggerError(e);
      });
  }

  private startCompletionWatchdog() {
    if (this.completionTimer !== -1) {
      return;
    }

    // Polling is used to avoid relying on renderer-specific completion events.
    this.completionTimer = setInterval(async () => {
      // 打印这些状态
      LogUtil.info(`[${TAG}]`, `completionFired: ${this.completionFired} , decodeDone: ${this.decodeDone}, currentPlaybackState: ${this.currentPlaybackState}`)
      if (this.completionFired) {
        return;
      }
      if (!this.avPlayer) {
        return;
      }

      // Don't auto-complete while user paused.
      if (this.currentPlaybackState != avSession.PlaybackState.PLAYBACK_STATE_PLAY) {
        return;
      }

      const dur = this.currentStreamInfo?.durationMs ?? 0;
      const pos = this.avPlayer.getCurrentPosition();
      const now = new Date().getTime();

      LogUtil.info(`[${TAG}]`, `dur: ${dur} , pos: ${pos} , now: ${now} , lastPositionUpdateTs: ${this.lastPositionUpdateTs}`)

      // If duration is known, completion is based on internal buffer clock.
      if (dur > 0 && pos >= Math.max(0, dur - 50)) {
        await this.handleCompletedInternal();
        return;
      }

      // If duration unknown: assume complete when position stops advancing for a while.
      if (this.lastPositionUpdateTs > 0 && (now - this.lastPositionUpdateTs) > 1000) {
        const state = this.avPlayer.getState();
        if (state !== audio.AudioState.STATE_RUNNING) {
          await this.handleCompletedInternal();
        }
      }
    }, 200);
  }

  private async handleCompletedInternal() {
    LogUtil.info(`[${TAG}]`, `handleCompletedInternal`);
    try {
      // Prevent re-entry.
      if (this.completionFired) {
        return;
      }
      this.completionFired = true;

      LyricsManager.reset()

      const nextSong = PlaylistManager.playNext()
      if (nextSong) {
        await this.cleanupCurrentPipeline();
        PlaylistManager.playSong(nextSong)
        return;
      }

      this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
      this.triggerStateChange('completed');
      this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      this.triggerCompleted();
    } catch (error) {
      this.triggerError(error);
    }
  }

  async playByPath(path: string, size?: number, pause?: boolean, metadata?: avSession.AVMetadata) {
    try {
      // Free-PCM pipeline currently supports:
      // - local file path
      // - http/https URL
      // NOTE: The legacy AVPlayer dataSrc streaming mode is not used here.
      await this.prepareSource(path, metadata);

      if (pause) {
        await this.pauseWithoutFadeOut();
      } else {
        await this.play();
      }
    } catch (error) {
      this.triggerError(error);
    }
  }

  async playByUrl(url: string, size?: number, pause?: boolean, metadata?: avSession.AVMetadata) {
    try {
      await this.prepareSource(url, metadata);
      if (pause) {
        await this.pauseWithoutFadeOut();
      } else {
        await this.play();
      }
    } catch (error) {
      this.triggerError(error);
    }
  }

  async updateAVMetadata(metadata: avSession.AVMetadata, defaultMetadata?: boolean) {
    if (this.avSession) {
      await this.avSession.setAVMetadata(metadata);
      if (defaultMetadata) {
        this.cachedAvMetadata = metadata;
      }
    }
  }

  async updateMetadataLyric(lyric: string) {
    if (this.avSession) {
      const metadata = this.cachedAvMetadata;
      if (metadata) {
        metadata.lyric = lyric;
        await this.avSession.setAVMetadata(metadata);
      }
    }
  }

  async play() {
    try {
      await this.setAudioSession()
      AppStorage.setOrCreate('playing_judge',true)
      const player = await this.getAVPlayerInstance();
      const fadeInOutEnabled = PreferencesCache.getUserPreference('fade_in_out', '0');
      LogUtil.info("AVPlayerManager", "play", "Playing the song with fadeInOutEnabled: " + fadeInOutEnabled);

      if (!this.prepared || !this.currentDecoder || !this.currentStreamInfo) {
        // 打印这些状态
        LogUtil.info("AVPlayerManager", "play", "prepared: " + this.prepared + ", currentDecoder: " + this.currentDecoder + ", currentStreamInfo: " + this.currentStreamInfo);
        LogUtil.warn(TAG, 'play', 'No prepared source/decoder, ignoring play()');
        return;
      }

      if (fadeInOutEnabled === '1') {
        await this.fadeIn();
      } else {
        LogUtil.info("AVPlayerManager", "play", "Playing the song without fade in/out, State " + player.getState());
        if (player.getState() === audio.AudioState.STATE_PAUSED || player.getState() === audio.AudioState.STATE_STOPPED) {
          await player.resume();
        } else {
          await player.play(this.currentDecoder, this.currentStreamInfo);
        }

        this.bindRendererListeners();

        // Track playback-side progress (internal buffer clock).
        player.setOnTimeUpdate((posMs: number) => {
          this.lastPositionMs = posMs;
          this.lastPositionUpdateTs = new Date().getTime();
        })

        // Apply app volume AFTER renderer exists.
        await this.setupAudioInterrupt(this.avPlayer?.getRenderer()!)
        await this.setupAudioRenderer()
        await this.initAppVolume()
        await this.applyDesiredVolumeIfReady()

        // If decode already reached EOS before we started, start watchdog.
        this.startCompletionWatchdog()

        LyricsManager.start()
        this.isPlayingBeforeInterrupt = true;
        this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
        this.triggerStateChange('playing');
        this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
        AppStorage.setOrCreate<boolean>("playing_judge", true);
        this.triggerPlay();
        EventHelper.postSongState('PLAY');
      }
      if (PreferencesCache.statusBarLyricsSetting().open) {
        WindowUtil.createLyricsFloatWindow()
      }
      let playing_mix: string =  PreferencesCache.getUserPreference('playing_mix','0')
      // const player = await this.getAVPlayerInstance();
      let playing_judge:boolean = player.getState() === audio.AudioState.STATE_RUNNING

      if (playing_mix==='1') {
        let audioManager = audio.getAudioManager();
        let audioStreamManager = audioManager.getStreamManager();
        try {
          audioStreamManager.on('audioRendererChange', (changeInfoArray) => {
            changeInfoArray.forEach((value)=>{
              console.log('jizhishi0113'+JSON.stringify(value))
            })

            // 检查变化后的音频流数量
            // AppStorage.setOrCreate('playing_judge',false)
            if (changeInfoArray.length > 1&&AppStorage.get<boolean>('playing_judge')) {

              {
                let AppBundleName:string = 'zone.yby.seamusic' //TODO::这里包名记得与APP包名一致
                let EventChangePlay:string = 'EdgeMusic_Playing' //公共事件名称
                let wantAgentObj: WantAgent; // 用于保存创建成功的WantAgent对象，后续使用其完成触发的动作。
                // 通过WantAgentInfo的operationType设置动作类型
                let wantAgentInfo: wantAgent.WantAgentInfo = {
                  wants: [
                    {
                      // deviceId: '',
                      bundleName: AppBundleName, // 需要替换为对应的bundleName。
                      abilityName: 'EntryAbility', // 需要替换为对应的abilityName。
                      action: EventChangePlay,
                      parameters: {
                        "type":'Playing'
                      }
                    }
                  ],
                  actionType: wantAgent.OperationType.SEND_COMMON_EVENT,
                  requestCode: 0,
                  actionFlags: [wantAgent.WantAgentFlags.CONSTANT_FLAG]
                };

                wantAgent.getWantAgent(wantAgentInfo, (err: BusinessError, data: WantAgent) => {
                  if (err) {
                    hilog.error(0xFF00, TAG,
                      `Failed to get want agent. Code is ${err.code}, message is ${err.message}`);
                    return;
                  }
                  hilog.info(0xFF00, TAG, 'Succeeded in getting want agent.');
                  wantAgentObj = data;
                  let notificationRequest: notificationManager.NotificationRequest = {
                    id: 11451419,
                    groupName:'jizhishi',
                    updateOnly:true,
                    // notificationSlotType:notificationManager.SlotType.CONTENT_INFORMATION,
                    content: {

                      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
                      normal: {
                        title: "正在运行播放任务",
                        text: "点击通知，在下方按钮下暂停音乐",
                        // additionalText: "test_additionalText"
                      }
                    }
                  ,
                    actionButtons: [
                      {
                        title: '暂停',
                        wantAgent: wantAgentObj
                      }
                    ]
                  };
                  notificationManager.publish(notificationRequest, (err: BusinessError) => {
                    if (err) {
                      hilog.error(0x0001, TAG, `Failed to publish notification. Code is ${err.code}, message is ${err.message}`);
                      let notificationRequest: notificationManager.NotificationRequest = {
                        id: 11451419,
                        // groupName:'jizhishi',
                        notificationSlotType:notificationManager.SlotType.SERVICE_INFORMATION,
                        content: {

                          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
                          normal: {
                            title: "正在运行播放任务",
                            text: "点击通知，在下方按钮下暂停音乐",
                            // additionalText: "test_additionalText"
                          }
                        }
                      ,
                        actionButtons: [
                          {
                            title: '暂停',
                            wantAgent: wantAgentObj
                          }
                        ]
                      };
                      notificationManager.publish(notificationRequest, (err: BusinessError) => {
                        if (err) {
                          hilog.error(0x0001, TAG, `Failed to publish notification. Code is ${err.code}, message is ${err.message}`);
                          return;
                        }
                        hilog.info(0x0001, TAG, 'Succeeded in publishing notification.');
                      });
                      // return;
                    }
                    hilog.info(0x0001, TAG, 'Succeeded in publishing notification.');
                  });


                  // ...
                });
                //事件订阅部分
                let subscriberCustom: commonEventManager.CommonEventSubscriber | null = null;
                let subscribeInfoCustom: commonEventManager.CommonEventSubscribeInfo = {
                  events: [EventChangePlay], // 订阅的自定义事件名称
                  publisherBundleName:AppBundleName //限制包名为本应用
                  // 可选安全限制（二选一）：
                  // publisherPermissions: ["permission.APPROVE_ORDER"], // 限制发布者权限
                  // publisherBundleName: "com.example.sender" // 限制发布者包名
                };

                commonEventManager.createSubscriber(subscribeInfoCustom,
                  (err: BusinessError, data: commonEventManager.CommonEventSubscriber) => {
                    if (err) {
                      hilog.error(0xFF00, TAG,
                        `Failed to create subscriber. Code is ${err.code}, message is ${err.message}`);
                      return;
                    }
                    hilog.info(0xFF00, TAG, 'Succeeded in creating subscriber.');
                    subscriberCustom = data;
                    if (subscriberCustom !== null) {

                      commonEventManager.subscribe(subscriberCustom,
                        (err: BusinessError, data: commonEventManager.CommonEventData) => {
                          if (err) {
                            hilog.error(0xFF00, TAG,
                              `Failed to subscribe common event. Code is ${err.code}, message is ${err.message}`);
                            return;
                          }
                          hilog.info(0xFF00, TAG, `Succeeded in subscribing, data is ${JSON.stringify(data)}`);
                          AppStorage.setOrCreate('playing_judge',false)
                          avPlayerManager.avPlayer?.pause().catch(()=>{
                            avPlayerManager.avPlayer?.pause()
                          })
                          //暂停后关闭监听
                          if (subscriberCustom !== null) {
                            commonEventManager.unsubscribe(subscriberCustom, (err: BusinessError) => {
                              if (err) {
                                hilog.error(0xFF00, TAG,
                                  `Failed to unsubscribe. code is ${err.code}, message is ${err.message}`);
                              } else {
                                hilog.info(0xFF00, TAG, `Succeeded in unsubscribing.`);
                                subscriberCustom = null;
                              }
                            })
                          }

                        })
                    } else {
                      hilog.error(0xFF00, TAG, `Need create subscriber`);
                    }
                  })
              }
            }
          });
        } catch (error) {
          // TODO: Implement error handling.
        }
      }
    } catch (error) {
      this.triggerError(error);
    }
  }

  async pause() {
    try {
      AppStorage.setOrCreate('playing_judge',false)
      const player = await this.getAVPlayerInstance();
      if (player.getState() === audio.AudioState.STATE_RUNNING) {
        const fadeInOutEnabled = PreferencesCache.getUserPreference('fade_in_out', '0');
        if (fadeInOutEnabled === '1') {
          await this.fadeOut();
        } else {
          await player.pause();
          AppStorage.setOrCreate<boolean>("playing_judge", false);
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          this.triggerStateChange('paused');
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          this.triggerPause();
          EventHelper.postSongState('PAUSE');
        }
        WindowUtil.destroyLyricsFloatWindow()
        this.audioSessionManager.deactivateAudioSession().then(() => {
          console.info('Succeeded in doing deactivateAudioSession.');
        }).catch((err: BusinessError) => {
          console.error(`Failed to deactivateAudioSession. Code: ${err.code}, message: ${err.message}`);
        });
      }
    } catch (error) {
      this.triggerError(error);
    }
  }

  private async setupAudioInterrupt(player: audio.AudioRenderer) {
    // 设置焦点模式为共享模式
    player.setInterruptMode(audio.InterruptMode.SHARE_MODE);


    player.on('outputDeviceChangeWithInfo', async (info: audio.AudioStreamDeviceChangeInfo) => {
      switch (info.changeReason) {
        case audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE:
          // 设备不可用(如蓝牙断开)，需要暂停播放
          await this.stop()
          break;

        case audio.AudioStreamDeviceChangeReason.REASON_NEW_DEVICE_AVAILABLE:
          // 新设备可用
          break;

        case audio.AudioStreamDeviceChangeReason.REASON_OVERRODE:
          // 设备被切换
          break;
      }
    })
  }

  async pauseWithoutFadeOut() {
    try {
      const player = await this.getAVPlayerInstance();
        // 打印目前状态
      LogUtil.info("AVPlayerManager", "pauseWithoutFadeOut", "Pausing the song, State " + player.getState());
      await player.pause();
      AppStorage.setOrCreate<boolean>("playing_judge", false);
      this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
      this.triggerStateChange('paused');
      this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      this.triggerPause();
      EventHelper.postSongState('PAUSE');
      WindowUtil.destroyLyricsFloatWindow()
    } catch (error) {
      this.triggerError(error);
    }
  }

  async stop() {
    try {
      // await this.cleanupCurrentPipeline();
      LyricsManager.reset()
      this.isPlayingBeforeInterrupt = false;
      this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_IDLE;
      this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_IDLE);
      this.triggerStateChange('stopped');
      this.triggerStop();
      this.triggerPause()
    } catch (error) {
      this.triggerError(error);
    }
  }

  async destroy() {
    try {
      if (this.fadeTimer != -1) {
        clearInterval(this.fadeTimer);
        this.fadeTimer = -1;
      }
      await this.cleanupCurrentPipeline();
      this.avPlayer = null;
      if (this.avSession) {
        await this.avSession.destroy();
        this.avSession = null;
      }
      this.clearCallbacks();
    } catch (error) {
      this.triggerError(error);
    }
  }

  async setAudioSession() {
    // let isMixWithOthers = await AppStorage.get(StorageConstants.MIX_WITH_OTHERS) as boolean
    let playing_mix: string =  PreferencesCache.getUserPreference('playing_mix','0')

    const strategy: audio.AudioSessionStrategy = {
      concurrencyMode:playing_mix==='1'? audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS:audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT
    }
    await this.audioSessionManager.activateAudioSession(strategy)


  }

  async seek(position: number) {
    try {
      const player = await this.getAVPlayerInstance();
      if (!this.prepared) {
        return;
      }
      await player.seekTo(position);
      this.updatePlaybackState(this.currentPlaybackState, position);
      this.triggerSeek(position);
    } catch (error) {
      this.triggerError(error);
    }
  }

  // 淡入效果
  private async fadeIn() {
    // 清除可能存在的旧定时器
    if (this.fadeTimer != -1) {
      clearInterval(this.fadeTimer);
      this.fadeTimer = -1;
    }

    const player = await this.getAVPlayerInstance();

    if (!this.prepared || !this.currentDecoder || !this.currentStreamInfo) {
      return;
    }

    // 开始播放
    if (player.getState() === audio.AudioState.STATE_PAUSED) {
      await player.resume();
    } else {
      await player.play(this.currentDecoder, this.currentStreamInfo);
    }

    // Track playback-side progress.
    player.setOnTimeUpdate((posMs: number) => {
      this.lastPositionMs = posMs;
      this.lastPositionUpdateTs = new Date().getTime();
    })

    // Apply initial volume after renderer exists.
    try {
      await player.setVolume(0)
      this.currentVolume = 0;
    } catch (e) {
      // ignore
    }

    this.bindRendererListeners();
    LyricsManager.start()
    this.isPlayingBeforeInterrupt = true;
    this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    this.triggerStateChange('playing');
    this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
    AppStorage.setOrCreate<boolean>("playing_judge", true);
    this.triggerPlay();
    EventHelper.postSongState('PLAY');

    // 计算每一步的音量增量
    const stepIncrease = 1.0 / this.FADE_STEPS;
    const stepInterval = this.FADE_DURATION / this.FADE_STEPS;
    const maxVolume = Number(PreferencesCache.getUserPreference('Volume','100'))/100;
    this.desiredVolume = Math.max(0, Math.min(1, maxVolume));
    let currentStep = 0;

    // 设置定时器逐步增加音量
    this.fadeTimer = setInterval(async () => {
      if (currentStep < this.FADE_STEPS) {
        this.currentVolume += stepIncrease;
        const currentPlayer = await this.getAVPlayerInstance();
        LogUtil.debug(`[${TAG}]`, `currentVolume: ${this.currentVolume}`)
        try {
          await currentPlayer.setVolume(Math.min(maxVolume, this.currentVolume))
        } catch (e) {
          // ignore
        }
        currentStep++;
      } else {
        // 淡入完成，清除定时器
        if (this.fadeTimer != -1) {
          clearInterval(this.fadeTimer);
          this.fadeTimer = -1;
        }
        this.currentVolume = maxVolume; // 确保最终音量为之前设置的
        const finalPlayer = await this.getAVPlayerInstance();
        try {
          await finalPlayer.setVolume(this.currentVolume)
        } catch (e) {
          // ignore
        }
      }
    }, stepInterval);
  }

  // 淡出效果
  private async fadeOut() {
    // 清除可能存在的旧定时器
    if (this.fadeTimer != -1) {
      clearInterval(this.fadeTimer);
      this.fadeTimer = -1;
    }

    const player = await this.getAVPlayerInstance();
    const maxVolume = Number(PreferencesCache.getUserPreference('Volume','100'))/100;
    this.currentVolume = maxVolume;
    this.desiredVolume = Math.max(0, Math.min(1, maxVolume));

    // 计算每一步的音量减量
    const stepDecrease = maxVolume / this.FADE_STEPS;
    const stepInterval = this.FADE_DURATION / this.FADE_STEPS;
    let currentStep = 0;

    // 设置定时器逐步减小音量
    this.fadeTimer = setInterval(async () => {
      if (currentStep < this.FADE_STEPS) {
        this.currentVolume -= stepDecrease;
        const currentPlayer = await this.getAVPlayerInstance();
        LogUtil.debug(`[${TAG}]`, `currentVolume: ${this.currentVolume}`)
        try {
          await currentPlayer.setVolume(Math.max(0, this.currentVolume))
        } catch (e) {
          // ignore
        }
        currentStep++;
      } else {
        // 淡出完成，暂停播放并清除定时器
        if (this.fadeTimer != -1) {
          clearInterval(this.fadeTimer);
          this.fadeTimer = -1;
        }
        const finalPlayer = await this.getAVPlayerInstance();
        await finalPlayer.pause();
        AppStorage.setOrCreate<boolean>("playing_judge", false);
        this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
        this.triggerStateChange('paused');
        this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
        this.triggerPause();
        EventHelper.postSongState('PAUSE');
        WindowUtil.destroyLyricsFloatWindow()
        this.currentVolume = maxVolume; // 重置音量
        try {
          await finalPlayer.setVolume(maxVolume);
        } catch (e) {
          // ignore
        }
      }
    }, stepInterval);
  }

  // 设置均衡器效果
  setEqualizer(bands: number[]) {
    if (this.currentDecoder) {
      this.currentDecoder.setEqGains(bands);
    }
  }

  // 开启/关闭
  toggleEqualizer(enabled: boolean) {
    if (this.currentDecoder) {
      this.currentDecoder.setEqEnabled(enabled);
    }
  }
}

export default AVPlayerManager;

export const avPlayerManager = new AVPlayerManager();
