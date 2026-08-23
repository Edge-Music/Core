import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { common, WantAgent, wantAgent } from '@kit.AbilityKit';
import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';
import { PlaylistManager } from './PlaylistManager';
import { LogUtil } from '../logger/Logger';
import { EventHelper } from './EventHelper';
import { PreferencesCache } from './PreferenceCache';
import { SourceAdapter } from '../adapter';
import { Song } from '../type/Adapter';
import LyricsManager from './LyricsManager';
import { JSON } from '@kit.ArkTS';
import { window } from '@kit.ArkUI';
import WindowUtil from './WindowUtil';
import { commonEventManager,BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '../logger/Logger'
// import { notificationManager } from '@kit.NotificationKit';
import { AudioRendererPlayer,
  DecodeAudioProgress,
  PcmDecoderTool, PcmStreamDecoder, PcmStreamInfo } from '@ospark/free-pcm';
import map from '@hms.core.map.map';
import { deviceInfo } from '@kit.BasicServicesKit';

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
  // 提前 EOS 恢复计数（坏帧/流中断会让解码器在歌曲中途就报 done）：
  // 每首歌最多原地重建恢复 2 次，仍失败才按播完切歌
  private eosRecoveryCount: number = 0;

  // Sequence guard for async callbacks.
  private sourceSeq: number = 0;

  // 管线重建串行锁：createStreamDecoder / close / renderer 重建都会动底层原生资源，
  // 快速连切时若并发进入会同时存在多个解码线程，底层解码器随即失效（无声/崩溃）。
  // 所有 prepareSource 请求排队执行，配合 sourceSeq 让排队中的过期请求直接出队。
  private prepareChain: Promise<void> = Promise.resolve();

  // play() 重入保护：AudioRendererPlayer.play() 会重建 renderer，并发调用会互相踩。
  private playInFlight: boolean = false;

  // Ensure we don't double-bind renderer event listeners.
  private rendererListenersBound: boolean = false;
  audioManager = audio?.getAudioManager()
  audioSessionManager: audio.AudioSessionManager = this.audioManager?.getSessionManager()
  avSession: avSession.AVSession | null = null;
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
  // 非强制打断导致的暂停标记（不受 renderer stateChange 影响），用于打断结束后恢复播放
  private interruptPaused: boolean = false;

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
    // Error 直接 JSON.stringify 会丢失 message/stack 变成 {}，日志需显式取字段
    LogUtil.error('[AVPlayerManager]', `triggerError: ${error?.message ?? error}\n${error?.stack ?? ''}`);
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
      // 如果API版本大于等于API23
      if(deviceInfo.sdkApiVersion >= 23) {
        this.avSession.enableDesktopLyric(true).catch((error: Error) => {
          this.triggerError(error)
        });
      }
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
  // getDesktopLyricVisibility():{
  //   let r = this.avSession?.isDesktopLyricVisible()
  //   return r
  //
  // }
  private setupMediaSessionListeners() {
    if (!this.avSession) {
      return;
    }

    this.avSession.on('play', () => {
      this.play();
      if (deviceInfo.sdkApiVersion >= 23) {
        this.avSession?.enableDesktopLyric(true)
        // this.avSession?.onDesktopLyricVisibilityChanged((visible: boolean) => {
        //   console.info(`desktop lyric visible state: ${visible}`);
        //
        // });
      }
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

    // 连点保护统一由 PlaylistManager.playSong 的防抖承担：
    // 这里再套一层 leading throttle 会把 500ms 内的后续点击整个丢弃，
    // 表现为播控中心连点五次只跳一首
    this.avSession.on('playNext', () => {
      const nextSong = PlaylistManager.playNext()
      if (nextSong) {
        PlaylistManager.playSong(nextSong)
      }
    })

    this.avSession.on('playPrevious', () => {
      const prevSong = PlaylistManager.playPrevious()
      if (prevSong) {
        PlaylistManager.playSong(prevSong)
      }
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
      EventHelper.postFavoriteToggle()
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

    // 同一个 renderer 上的监听注册全部收敛到这里：
    // resume() 不会重建 renderer，若在 play() 中每次都注册，暂停/恢复一次就多一份回调，
    // 回调里还会写 AVSession 状态，累积后表现为越用越卡、状态错乱
    this.setupAudioInterrupt(renderer);
    this.setupAudioRenderer(renderer);

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
            EventHelper.postSongState('PAUSE');
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
            EventHelper.postSongState('PAUSE');
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
        // 非强制打断：系统不会替应用停流，必须自己暂停 renderer。
        // 原来只调 stop()（仅同步状态、不动音频），结果是 UI 显示已暂停但声音还在放
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            // 用独立标记记录"因打断而暂停"：isPlayingBeforeInterrupt 会被
            // renderer 的 stateChange('paused') 异步清零，不能用它判断是否该恢复
            this.interruptPaused = this.isPlayingBeforeInterrupt;
            await this.pauseWithoutFadeOut();
            break;
          case audio.InterruptHint.INTERRUPT_HINT_RESUME:
            if (this.interruptPaused) {
              this.interruptPaused = false;
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

  private setupAudioRenderer(player: audio.AudioRenderer) {
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

  // DRC 预设参数表（与音效面板 DRC_PRESETS 保持一致）
  private static readonly DRC_PARAMS: Record<string, number[]> = {
    'Default': [-12, 2.0, 10, 100, 0],
    'Speech': [-24, 4.0, 5, 80, 6],
    'Vocal': [-20, 3.0, 20, 300, 3],
    'Night': [-35, 10.0, 5, 500, 12],
    'Mastering': [-10, 1.5, 30, 400, 1],
    'Punch': [-18, 4.0, 30, 50, 4],
    'Broadcast': [-20, 6.0, 15, 200, 6],
    'Limiter': [-0.5, 20.0, 0.1, 50, 0]
  };

  // 换歌后重放 DRC / 声道平衡（这两者绑定在解码器/播放器实例上，管线重建会复位）
  private reapplyPostPrepareEffects(): void {
    try {
      const volLeft = parseFloat(PreferencesCache.getUserPreference('vol_left', '1.0'));
      const volRight = parseFloat(PreferencesCache.getUserPreference('vol_right', '1.0'));
      if (!isNaN(volLeft) && !isNaN(volRight) && (volLeft !== 1.0 || volRight !== 1.0)) {
        this.setChannelVolumes(volLeft, volRight);
      }

      const drcEnabled = this.parseBooleanPref(PreferencesCache.getUserPreference('drc_enabled', '0'));
      if (drcEnabled) {
        this.setDrcEnabled(true);
        const presetId = PreferencesCache.getUserPreference('drc_preset', 'Default');
        const p = AVPlayerManager.DRC_PARAMS[presetId] ?? AVPlayerManager.DRC_PARAMS['Default'];
        this.setDrcParams(p[0], p[1], p[2], p[3], p[4]);
      }
    } catch (e) {
      LogUtil.warn(TAG, `reapplyPostPrepareEffects failed: ${e}`);
    }
  }

  // 关闭解码器并等待其解码线程真正退出。
  // close() 只是发出退出信号，线程是异步收尾的；不等它退出就创建下一个解码器，
  // 会出现两个解码线程争用同一套底层资源，表现为切歌后无声或解码器报错。
  private async closeDecoderAndWaitExit(decoder: PcmStreamDecoder) {
    try {
      decoder.close();
    } catch (e) {
      // ignore
    }
    try {
      await Promise.race([
        decoder.done,
        // ready 未完成就被关闭时 done 可能永不 resolve，用超时兜底避免卡住整条队列
        new Promise<void>((resolve) => setTimeout(resolve, 300))
      ]);
    } catch (e) {
      // done reject 同样视为已退出
    }
  }

  private async cleanupCurrentPipeline() {
    // 先摘引用：等待期间到达的回调不应再拿到这个即将销毁的解码器
    const decoder = this.currentDecoder;
    this.currentDecoder = null;

    // Stop playback first.
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop();
      } catch (e) {
        // ignore
      }
    }

    // Stop decoding.
    if (decoder) {
      await this.closeDecoderAndWaitExit(decoder);
    }

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

  /** @returns 本次请求是否真正建立了管线（false 表示已被更新的切歌请求取代） */
  private prepareSource(source: string, metadata?: avSession.AVMetadata): Promise<boolean> {
    // 同步抢占序号：后到的请求立刻让先到的请求失效，哪怕后者还阻塞在 await 里。
    // 必须在任何 await 之前完成，否则并发请求会各自拿到相同的"最新"序号。
    const seq = ++this.sourceSeq;

    // 排队执行，保证同一时刻只有一条管线在重建
    const run = this.prepareChain.then(() => this.doPrepareSource(source, seq, metadata));
    // 链上的失败不应阻断后续请求
    this.prepareChain = run.then(() => {}).catch(() => {});
    return run;
  }

  private async doPrepareSource(source: string, seq: number,
    metadata?: avSession.AVMetadata): Promise<boolean> {
    // 排队期间已被更新的请求取代，无需再建管线
    if (seq !== this.sourceSeq) {
      LogUtil.info(TAG, 'doPrepareSource', `drop queued stale request, seq ${seq}`);
      return false;
    }

    await this.getAVPlayerInstance();
    await this.cleanupCurrentPipeline();
    if (seq !== this.sourceSeq) {
      return false;
    }

    // 换歌（新音源）时清零提前 EOS 的恢复计数；同一音源的重建（恢复）不清零
    if (source !== this.currentSource) {
      this.eosRecoveryCount = 0;
    }
    this.currentSource = source;
    this.triggerStateChange('initialized');

    const eqEnabled = this.loadEqEnabledFromPreference();
    const eqGainsDb = this.loadEqGainsDbFromPreference();

    LogUtil.info("AVPlayerManager", "prepareSource", "eqEnabled: " + eqEnabled + ", eqGainsDb: " + eqGainsDb + ", source: " + source);

    const decoder = this.decoderTool.createStreamDecoder(
      source,
      {
        eqEnabled,
        eqGainsDb,
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

    let info: PcmStreamInfo;
    try {
      info = await decoder.ready;
    } catch (e) {
      // ready 失败（资源不存在/格式不支持）时解码线程可能已启动，必须回收
      if (this.currentDecoder === decoder) {
        this.currentDecoder = null;
      }
      await this.closeDecoderAndWaitExit(decoder);
      throw e as Error;
    }

    if (this.sourceSeq !== seq) {
      // 过期请求：必须关闭本次创建的解码器。
      // 漏关会留下持续解码的僵尸线程，连续快切会累积多个，直到底层解码器失效。
      if (this.currentDecoder === decoder) {
        this.currentDecoder = null;
      }
      await this.closeDecoderAndWaitExit(decoder);
      return false;
    }

    this.currentStreamInfo = info;
    this.prepared = true;
    this.decodeDone = false;
    this.completionFired = false;

    this.triggerDurationChange(info.durationMs);
    this.triggerStateChange('prepared');

    // 换歌后重放 DRC / 声道平衡（EQ 已在解码器创建时应用；此两者随管线重建会丢失，需补回）
    this.reapplyPostPrepareEffects();

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

    return true;
  }

  private startCompletionWatchdog() {
    if (this.completionTimer !== -1) {
      return;
    }

    // Polling is used to avoid relying on renderer-specific completion events.
    // 注意：这里每 200ms 触发一次并贯穿整首歌，不要在其中做 info 级日志——
    // 原实现每首歌会打出上千条日志，明显拖慢 UI 线程并淹没其它日志
    this.completionTimer = setInterval(async () => {
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

      const now = new Date().getTime();
      const stallMs = this.lastPositionUpdateTs > 0 ? now - this.lastPositionUpdateTs : 0;

      // 完成判定统一以 decodeDone（解码线程真实到达流末尾）为前置：
      // 1) 流媒体的 durationMs 常是按码率/长度的估算值，偏小时旧的
      //    pos >= dur-50 判定会在真实结尾之前就切歌，切掉尾部；
      // 2) 网络卡顿造成的欠载暂停同样表现为"位置停滞"，无此前置会被
      //    误判为播放完成而跳下一首（播放到一半莫名切歌的主要来源）。
      // decodeDone 后消费时钟停滞 = 渲染器已把缓冲排空，此时切歌不会丢声音。
      if (!this.decodeDone || stallMs < 500) {
        return;
      }
      await this.handleCompletedInternal();
    }, 200);
  }

  private async handleCompletedInternal() {
    const dur = this.currentStreamInfo?.durationMs ?? 0;
    const pos = this.avPlayer?.getCurrentPosition() ?? -1;
    // 提前 EOS 保护：位置离声明时长还很远就收到完成信号，说明解码器因坏帧/流中断
    // 提前到达 EOS（坏帧在 seek 落点上尤其常见）。此时不能切歌——原地重建管线并
    // seek 回断点续播；每首歌最多恢复 2 次，仍失败才按播完处理，避免死循环。
    if (dur > 0 && pos >= 0 && pos < dur - 2000 && this.currentSource.length > 0 &&
      this.eosRecoveryCount < 2) {
      this.eosRecoveryCount++;
      LogUtil.error(`[${TAG}]`, `premature EOS detected: pos=${pos}ms dur=${dur}ms gap=${dur - pos}ms, ` +
        `rebuilding pipeline to resume (attempt ${this.eosRecoveryCount}/2), src=${this.currentSource}`);
      try {
        const resumeAt = Math.min(pos + 500, dur - 100); // 越过坏帧：从断点后 500ms 续播
        const ready = await this.prepareSource(this.currentSource, this.cachedAvMetadata ?? undefined);
        if (ready) {
          await this.play();
          await this.seek(resumeAt);
          return;
        }
        // 被更新的起播请求取代，直接交给新请求，不再走完成逻辑
        return;
      } catch (e) {
        LogUtil.error(`[${TAG}]`, `premature EOS recovery failed: ${(e as Error)?.message ?? e}`);
        // 恢复失败，落到下方正常完成逻辑切歌
      }
    }
    // 异常早切监控：正常播完时 pos 应贴近 dur；差值过大说明是误判/异常触发的切歌
    if (dur > 0 && pos >= 0 && pos < dur - 1000) {
      LogUtil.error(`[${TAG}]`, `ABNORMAL early song switch: pos=${pos}ms dur=${dur}ms gap=${dur - pos}ms ` +
        `decodeDone=${this.decodeDone} src=${this.currentSource}`);
    } else {
      LogUtil.info(`[${TAG}]`, `handleCompletedInternal pos=${pos} dur=${dur} decodeDone=${this.decodeDone}`);
    }
    try {
      // Prevent re-entry.
      if (this.completionFired) {
        return;
      }
      this.completionFired = true;

      LyricsManager.reset()

      // 自动续播必须尊重单曲循环：传 true 让单曲循环返回当前歌重播
      const nextSong = PlaylistManager.playNext(true)
      if (nextSong) {
        // 管线清理交给 prepareSource 串行链统一处理：在这里额外 cleanup 会与
        // 新起播的管线重建并发，反而制造竞态
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
      const ready = await this.prepareSource(path, metadata);
      // 本次请求已被更新的切歌取代，不要再起播——否则会与新管线抢 renderer
      if (!ready) {
        return;
      }

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
      const ready = await this.prepareSource(url, metadata);
      if (!ready) {
        return;
      }
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
    // 重入保护：UI、AVSession、自动续播可能同时触发 play()，
    // 两次并发进入时状态判断都还没变成 RUNNING，会重复重建 renderer 导致无声
    if (this.playInFlight) {
      LogUtil.info(TAG, 'play', 'play() already in flight, ignoring');
      return;
    }
    this.playInFlight = true;
    try {
      await this.setAudioSession()
      AppStorage.setOrCreate('playing_judge',true)
      const player = await this.getAVPlayerInstance();
      const fadeInOutEnabled = PreferencesCache.getUserPreference('fade_in_out', '0');
      LogUtil.info("AVPlayerManager", "play", "Playing the song with fadeInOutEnabled: " + fadeInOutEnabled);

      // 已播完：解码器是一次性的，resume 拿不到数据。
      // 必须重建管线，否则播完后点播放键毫无反应（单曲队列必然走到这里）
      if (this.completionFired || !this.prepared || !this.currentDecoder || !this.currentStreamInfo) {
        const cur = AppStorage.get<Song>('current_playing_song');
        if (cur) {
          LogUtil.info(TAG, 'play', 'pipeline exhausted, restarting current song');
          // 释放重入锁再交给起播链，否则重建过程中的 play() 会被自身挡掉
          this.playInFlight = false;
          PlaylistManager.playSong(cur);
          return;
        }
        LogUtil.warn(TAG, 'play', 'No prepared source/decoder, ignoring play()');
        return;
      }

      // 幂等保护：正在播放时重复 play() 会重启 AudioRenderer 并重新从已被消费的
      // 解码器拉流，导致无声卡死（如歌单中再次点击正在播放的歌曲）
      if (player.getState() === audio.AudioState.STATE_RUNNING) {
        LogUtil.info("AVPlayerManager", "play", "Already playing, ignoring play()");
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

        // renderer 相关监听统一在此绑定（内部已做幂等，resume 不会重复注册）
        this.bindRendererListeners();

        // Track playback-side progress (internal buffer clock).
        // 只有位置真的前进才刷新时间戳：watchdog 靠"位置停滞"判定排空完成，
        // 无条件刷新会让停滞检测永远失效（回调定时触发不代表位置在变）
        player.setOnTimeUpdate((posMs: number) => {
          if (posMs !== this.lastPositionMs) {
            this.lastPositionMs = posMs;
            this.lastPositionUpdateTs = new Date().getTime();
          }
        })

        // Apply app volume AFTER renderer exists.
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


    } catch (error) {
      this.triggerError(error);
    } finally {
      this.playInFlight = false;
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

  private setupAudioInterrupt(player: audio.AudioRenderer) {
    // 设置焦点模式为共享模式
    player.setInterruptMode(audio.InterruptMode.SHARE_MODE);


    player.on('outputDeviceChangeWithInfo', async (info: audio.AudioStreamDeviceChangeInfo) => {
      console.log('jizhishi0113'+JSON.stringify(info))
      switch (info.changeReason) {
        case audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE:
          // 设备不可用(如蓝牙断开)，需要暂停播放
          await this.pause()
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
      // 先通知歌词管理器乐观跳转并暂停旧位置回写，再执行 seek（缓冲期间位置回读仍是旧值）
      LyricsManager.notifySeek(position);
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

    // 幂等保护：正在播放时不要重复 play()（会重启 renderer 并重新从已被消费的
    // 解码器拉流导致卡死）；淡出定时器已在上面清除，这里只需把音量恢复到目标值
    if (player.getState() === audio.AudioState.STATE_RUNNING) {
      const maxVol = Number(PreferencesCache.getUserPreference('Volume', '100')) / 100;
      this.desiredVolume = Math.max(0, Math.min(1, maxVol));
      this.currentVolume = this.desiredVolume;
      try {
        await player.setVolume(this.desiredVolume)
      } catch (e) {
        // ignore
      }
      return;
    }

    // 开始播放
    if (player.getState() === audio.AudioState.STATE_PAUSED) {
      await player.resume();
    } else {
      await player.play(this.currentDecoder, this.currentStreamInfo);
    }

    // Track playback-side progress（仅在位置前进时刷新时间戳，理由同上处注释）
    player.setOnTimeUpdate((posMs: number) => {
      if (posMs !== this.lastPositionMs) {
        this.lastPositionMs = posMs;
        this.lastPositionUpdateTs = new Date().getTime();
      }
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

  // ========== 新增：左右耳独立控制 ==========

  // 设置左右耳独立音量 (linear: 0.0 ~ 2.0)
  setChannelVolumes(leftVolume: number, rightVolume: number): void {
    if (this.avPlayer && typeof this.avPlayer.setChannelVolumes === 'function') {
      try {
        this.avPlayer.setChannelVolumes(leftVolume, rightVolume);
      } catch (e) {
        LogUtil.warn(TAG, `setChannelVolumes failed: ${e}`);
      }
    }
  }

  // 设置左右耳独立EQ曲线
  setEqualizerLR(leftGains: number[], rightGains: number[]): void {
    if (this.avPlayer && typeof this.avPlayer.setEqGainsLR === 'function') {
      try {
        this.avPlayer.setEqGainsLR(leftGains, rightGains);
      } catch (e) {
        LogUtil.warn(TAG, `setEqGainsLR failed: ${e}`);
      }
    }
  }

  // ========== 新增：DRC动态范围控制 ==========

  // 设置DRC开关
  setDrcEnabled(enabled: boolean): void {
    if (this.currentDecoder && typeof this.currentDecoder.setDrcEnabled === 'function') {
      try {
        this.currentDecoder.setDrcEnabled(enabled);
      } catch (e) {
        LogUtil.warn(TAG, `setDrcEnabled failed: ${e}`);
      }
    }
  }

  // 设置DRC参数
  setDrcParams(thresholdDb: number, ratio: number, attackMs: number, releaseMs: number, makeupDb: number): void {
    if (this.currentDecoder && typeof this.currentDecoder.setDrcParams === 'function') {
      try {
        this.currentDecoder.setDrcParams(thresholdDb, ratio, attackMs, releaseMs, makeupDb);
      } catch (e) {
        LogUtil.warn(TAG, `setDrcParams failed: ${e}`);
      }
    }
  }

  /**
   * 当前管线是否还能直接续播（而不需要重建解码管线）。
   *
   * 解码器是一次性的拉流对象：播完（EOS）后再 resume/play 拿不到任何数据。
   * 队列只有一首歌时，播完后 playNext 会返回同一首，若上层因"歌曲 id 相同"
   * 就只调 play()，就会卡在无声、进度 0:00、点播放无反应的状态。
   */
  canResumeCurrent(): boolean {
    if (!this.prepared || !this.currentDecoder || !this.currentStreamInfo) {
      return false;
    }
    if (this.completionFired) {
      return false;
    }
    // 解码线程已退出的解码器同样无法续播
    if (this.currentDecoder.isAlive && !this.currentDecoder.isAlive()) {
      return false;
    }
    return true;
  }

  // 获取当前解码器（供外部调用）
  getCurrentDecoder(): PcmStreamDecoder | null {
    return this.currentDecoder;
  }

  // 获取当前播放器（供外部调用）
  getCurrentPlayer(): AudioRendererPlayer | null {
    return this.avPlayer;
  }
}

export default AVPlayerManager;

export const avPlayerManager = new AVPlayerManager();
