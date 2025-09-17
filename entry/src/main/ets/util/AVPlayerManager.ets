import { media } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
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
  avPlayer: media.AVPlayer | null = null;
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
    const player = await this.getAVPlayerInstance();
    player.setVolume(volume/100)
  }

  private setupMediaSessionListeners() {
    if (!this.avSession) {
      return;
    }

    this.avSession.on('play', () => {
      this.play();
    });

    this.avSession.on('pause', () => {
      this.pause();
    });

    this.avSession.on('stop', () => {
      this.stop();
    });

    this.avSession.on('seek', (position: number) => {
      if (this.avPlayer) {
        this.avPlayer.seek(position);
        this.updatePlaybackState(this.currentPlaybackState, position);
        this.triggerSeek(position);
      }
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
        elapsedTime: position ?? this.avPlayer?.currentTime ?? 0,
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

  private setupAudioInterrupt(player: media.AVPlayer) {
    // 设置焦点模式为共享模式
    player.audioInterruptMode = audio.InterruptMode.SHARE_MODE;

    // 设置音频类型
    const audioRendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0
    };
    player.audioRendererInfo = audioRendererInfo;

    player.on('audioOutputDeviceChangeWithInfo', async (info: audio.AudioStreamDeviceChangeInfo) => {
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

    // 设置音频打断监听
    player.on('audioInterrupt', async (interruptEvent: audio.InterruptEvent) => {
      this.triggerAudioInterrupt(interruptEvent);
      const continuePlaying = PreferencesCache.interruptingContinue()
      if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            // 系统强制暂停（临时失去焦点）
            const tempState = this.isPlayingBeforeInterrupt
            await this.pause();
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
            await this.pause();
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
            await this.pause();
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

    const player = await media.createAVPlayer();
    this.setupAudioInterrupt(player);

    player.on('stateChange', async (state: string) => {
      this.triggerStateChange(state);

      switch (state) {
        case 'initialized':
          LyricsManager.init()
          player.prepare();
          break;
        case 'prepared':
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          const duration = player.duration;
          this.triggerDurationChange(duration);
          break;
        case 'playing':
          LyricsManager.start()
          this.isPlayingBeforeInterrupt = true;
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
          this.triggerPlay();
          break;
        case 'paused':
          LyricsManager.reset()
          this.isPlayingBeforeInterrupt = false;
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          this.triggerPause();
          break;
        case 'completed':
          LyricsManager.reset()
          const nextSong = PlaylistManager.playNext()
          if (nextSong) {
            const player = await this.getAVPlayerInstance();
            player.seek(0)
            PlaylistManager.playSong(nextSong)
            return;
          }
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          this.triggerCompleted();
          break;
        case 'stopped':
          LyricsManager.reset()
          this.isPlayingBeforeInterrupt = false;
          player.reset();
          this.currentPlaybackState = avSession.PlaybackState.PLAYBACK_STATE_IDLE;
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_IDLE);
          this.triggerStop();
          break;
        case 'released':
          LyricsManager.reset()
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

    // 监听缓冲进度
    player.on('bufferingUpdate', (progress: number) => {
      this.triggerBufferingUpdate(progress);
    });

    player.on('error', (error: Error) => {
      LyricsManager.reset()
      this.triggerError(error);
    });

    player.on('seekDone', (position) => {
      this.updatePlaybackState(this.currentPlaybackState, position);
    });

    player

    this.avPlayer = player;
    return this.avPlayer;
  }

  async playByPath(path: string, size?: number, pause?: boolean, metadata?: avSession.AVMetadata) {
    try {
      const player = await this.getAVPlayerInstance();
      await player.reset();

      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);

      if (size === undefined) {
        player.fdSrc = {
          fd: file.fd,
          offset: 0,
          length: (fs.statSync(path)).size
        };
      } else {
        // 使用dataSrc流式播放
        player.dataSrc = {
          fileSize: size,
          callback: (buffer: ArrayBuffer, length: number, pos?: number): number => {
            if (buffer == undefined || length == undefined || pos == undefined) {
              return -1;
            }
            try {
              // 检查seek位置是否已下载
              const stats = fs.statSync(path); // 获取最新文件大小
              if (pos >= stats.size) {
                // seek位置超出当前已下载大小
                return 0; // 返回0让播放器等待
              }

              const readOptions: ReadOptions = {
                offset: pos,
                length: length,
              };

              // 同步读取文件数据
              const readLength = fs.readSync(file.fd, buffer, readOptions);

              if (readLength > 0) {
                return readLength;
              }

              // 到达文件末尾但可能还在下载
              if (pos < stats.size) {
                return 0; // 还有数据,让播放器等待
              }

              return -1; // 真正的文件结束
            } catch (error) {
              return -2; // 不可恢复的错误
            }
          }
        }
      }

      if (metadata && this.avSession) {
        await this.avSession.setAVMetadata(metadata);
      }
      await player.prepare();
      LogUtil.info(TAG, 'playByPath', `Prepared player with path: ${path}`);
      if (pause) {
        // 如果传入pause参数为true，则暂停播放
        LogUtil.info(TAG, 'playByPath', 'Pausing playback as per request');
        await this.pause();
      } else {
        await this.play();
      }
    } catch (error) {
      this.triggerError(error);
    }
  }

  async playByUrl(url: string, metadata?: avSession.AVMetadata) {
    try {
      const player = await this.getAVPlayerInstance();
      await player.reset();
      player.url = url;

      if (metadata && this.avSession) {
        await this.avSession.setAVMetadata(metadata);
      }

      await player.prepare();
      await this.play();
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
      this.setAudioSession()
      const player = await this.getAVPlayerInstance();
      await this.initAppVolume()
      const fadeInOutEnabled = PreferencesCache.getUserPreference('fade_in_out', '0');
      LogUtil.info("AVPlayerManager", "play", "Playing the song with fadeInOutEnabled: " + fadeInOutEnabled);
      if (fadeInOutEnabled === '1') {
        await this.fadeIn();
      } else {
        await player.play();
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
    }
  }

  async pause() {
    try {
      const player = await this.getAVPlayerInstance();
      if(player.state === 'playing'){
        const fadeInOutEnabled = PreferencesCache.getUserPreference('fade_in_out', '0');
        if (fadeInOutEnabled === '1') {
          await this.fadeOut();
        } else {
          await player.pause();
          AppStorage.setOrCreate<boolean>("playing_judge", false);
          this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
          this.triggerPause();
          EventHelper.postSongState('PAUSE');
        }
        WindowUtil.destroyLyricsFloatWindow()
      }
    } catch (error) {
      this.triggerError(error);
    }
  }

  async stop() {
    try {
      const player = await this.getAVPlayerInstance();
      // 如果状态不支持停止，则先暂停再停止
      if (player.state === 'playing') {
        await player.pause();
      }
      if (player.state !== 'idle' && player.state !== 'initialized'){
        await player.stop();
        this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_IDLE);
        this.triggerStop();
      }
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
      if (this.avPlayer) {
        await this.avPlayer.release();
        this.avPlayer = null;
      }
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
      player.seek(position);
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

    // 设置初始音量为0
    player.setVolume(0)
    this.currentVolume = 0;

    // 开始播放
    await player.play();
    this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
    AppStorage.setOrCreate<boolean>("playing_judge", true);
    this.triggerPlay();
    EventHelper.postSongState('PLAY');

    // 计算每一步的音量增量
    const stepIncrease = 1.0 / this.FADE_STEPS;
    const stepInterval = this.FADE_DURATION / this.FADE_STEPS;
    const maxVolume = Number(PreferencesCache.getUserPreference('Volume','100'))/100;
    let currentStep = 0;

    // 设置定时器逐步增加音量
    this.fadeTimer = setInterval(async () => {
      if (currentStep < this.FADE_STEPS) {
        this.currentVolume += stepIncrease;
        const currentPlayer = await this.getAVPlayerInstance();
        LogUtil.debug(`[${TAG}]`, `currentVolume: ${this.currentVolume}`)
        currentPlayer.setVolume(Math.min(maxVolume, this.currentVolume))
        currentStep++;
      } else {
        // 淡入完成，清除定时器
        if (this.fadeTimer != -1) {
          clearInterval(this.fadeTimer);
          this.fadeTimer = -1;
        }
        this.currentVolume = maxVolume; // 确保最终音量为之前设置的
        const finalPlayer = await this.getAVPlayerInstance();
        finalPlayer.setVolume(this.currentVolume)
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
        currentPlayer.setVolume(Math.max(0, this.currentVolume))
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
        this.updatePlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
        this.triggerPause();
        EventHelper.postSongState('PAUSE');
        WindowUtil.destroyLyricsFloatWindow()
        this.currentVolume = maxVolume; // 重置音量
        finalPlayer.setVolume(maxVolume);
      }
    }, stepInterval);
  }
}

export default AVPlayerManager;

export const avPlayerManager = new AVPlayerManager();
