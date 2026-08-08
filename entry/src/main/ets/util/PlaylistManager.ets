import { SourceAdapter } from "../adapter";
import { Song, SongV2 } from "../type/Adapter";
import { avSession } from "@kit.AVSessionKit";
import { EventHelper } from "./EventHelper";
import { avPlayerManager } from "./AVPlayerManager";
import { LogUtil } from "@pura/harmony-utils";
import { PreferencesCache } from "./PreferenceCache";
import { AppStorageV2 } from "@kit.ArkUI";


let SongItem: SongV2 =
  AppStorageV2.connect(SongV2,'SongV2', () => new SongV2())!
export enum PlayMode {
  SEQUENCE = avSession.LoopMode.LOOP_MODE_SEQUENCE,
  RANDOM = avSession.LoopMode.LOOP_MODE_SHUFFLE,
  LOOP = avSession.LoopMode.LOOP_MODE_LIST,
  SINGLE = avSession.LoopMode.LOOP_MODE_SINGLE
}

export enum PlayAction {
  NEXT = "NEXT", // 下一首
  PRE = "PRE" // 上一首
}

export class PlaylistManager {

  private static instance: PlaylistManager | null = null;
  private _playlist: Array<Song> = [];
  private _playMode: PlayMode = PlayMode.LOOP;
  private _rawPlaylist: Array<Song> = [];
  private _lastAction: PlayAction | null = null;
  // 最近一次切歌请求的目标歌曲（同步更新），用于快速连切时计算下一首/上一首的基准，
  // 避免依赖滞后的 AppStorage.current_playing_song 反查索引
  private _targetSong: Song | null = null;
  // 切歌请求序号：每次 playSong 自增，仅最新请求允许真正起播/写 UI 状态
  private static playSeq: number = 0;
  // 切歌防抖：底层解码管线重建（关旧解码器 → 建新解码器 → 重建 renderer）代价高，
  // 连点会让多次重建叠在一起把解码器打崩。首次点击立即起播保证跟手，
  // 紧随其后的连点只保留最后一次；自动续播间隔远大于阈值，不受影响。
  private static readonly SWITCH_DEBOUNCE_MS: number = 300;
  private static switchTimer: number = -1;
  private static lastDispatchTs: number = 0;

  private constructor() {

  }

  public static getInstance(): PlaylistManager {
    if (PlaylistManager.instance === null) {
      PlaylistManager.instance = new PlaylistManager()
      PlaylistManager.loadPlaylist(PreferencesCache.playlist())
      PlaylistManager.switchPlayMode(PreferencesCache.playMode())
      const lastSong = PreferencesCache.lastSong()
      if (lastSong) {
        PlaylistManager.playSong(lastSong, true)
      }
    }
    return PlaylistManager.instance
  }

  public static playSong(song: Song, pause = false) {
    // 同步记录本次请求：序号 + 目标歌曲（供 playNext/playPrevious 立即拿到新基准）
    const seq = ++PlaylistManager.playSeq;
    PlaylistManager.getInstance()._targetSong = song;

    const fadeInOutEnabled = PreferencesCache.getUserPreference('fade_in_out', '0');
    let delayTime: number = 0
    if (fadeInOutEnabled === '1') {
      avPlayerManager.pause()
      // 这里的延迟时间与淡入淡出的最大时间保持一致750ms
      delayTime = 750
    }

    // 覆盖上一次还未落地的请求，连点期间不重复重建解码管线
    if (PlaylistManager.switchTimer !== -1) {
      clearTimeout(PlaylistManager.switchTimer)
      PlaylistManager.switchTimer = -1
    }

    const sinceLast = Date.now() - PlaylistManager.lastDispatchTs
    if (delayTime === 0 && sinceLast >= PlaylistManager.SWITCH_DEBOUNCE_MS) {
      // 距上次起播已超过阈值（单次点击、自动续播）：立即执行，不引入额外延迟
      PlaylistManager.dispatchPlay(song, pause, seq)
      return
    }

    const wait = delayTime > 0 ? delayTime : (PlaylistManager.SWITCH_DEBOUNCE_MS - sinceLast)
    PlaylistManager.switchTimer = setTimeout(() => {
      PlaylistManager.switchTimer = -1
      PlaylistManager.dispatchPlay(song, pause, seq)
    }, wait)
  }

  /** 真正派发起播请求；仅由 playSong 的防抖逻辑调用 */
  private static async dispatchPlay(song: Song, pause: boolean, seq: number) {
    // 快速连切时只让最后一次请求生效，过期请求直接丢弃，
    // 防止中间每一首都写一遍 current_playing_song 造成 UI 反复跳动
    if (seq !== PlaylistManager.playSeq) {
      LogUtil.info("PlaylistManager ", "playSong ", "drop stale request, seq ", seq.toString())
      return
    }
    PlaylistManager.lastDispatchTs = Date.now()
    try {
      // 获取当前播放的歌曲
      const currentSong = AppStorage.get<Song>("current_playing_song")
      // 点击正在播放的歌曲时只需续播，无需重建管线。
      // 但必须确认管线还能续播：单曲队列播完后 playNext 返回的仍是这首歌，
      // 此时解码器已 EOS，只调 play() 会卡死在无声 + 进度 0:00 + 点播放无反应
      if (currentSong && currentSong.id === song.id
        && PlaylistManager.getPlayMode() !== PlayMode.SINGLE
        && avPlayerManager.canResumeCurrent()) {
        EventHelper.postSongState("PLAY")
        await avPlayerManager.play()
        return
      }
      LogUtil.info("PlaylistManager ", "playSong ", "song ", JSON.stringify(song))
      AppStorage.setOrCreate("current_playing_song", song)
      // 从song转换至SongV2
      SongItem.id = song.id;
      SongItem.name = song.name;
      SongItem.artists =song.artists;
      SongItem.album = song.album;
      SongItem.duration = song.duration;
      SongItem.privilege =song.privilege;
      if (song.tns) {
        SongItem.tns = song.tns;
      }
      if (song.meta) {
        SongItem.meta =song.meta;

      }
      if (song.source) {
        SongItem.source =song.source;
      }
      if (song.sourceID) {
        SongItem.sourceID =song.sourceID;
      }
      // 获取歌曲信息
      EventHelper.postPlaySong([song, pause, seq]) // 发送播放歌曲事件（携带序号，供接收方丢弃过期结果）
    } catch (error) {
      LogUtil.error("AVPlayerManager ", "playSong ", "Error: ", error.message)
    }
  }

  /**
   * 洗牌算法生成随机播放列表
   * @param playlist
   * @returns
   */
  private static shuffle(playlist: Array<Song>): Array<Song> {
    const arr = playlist.slice()
    for (let i = arr.length - 1; i >= 0; i--) {
      const randomIndex = Math.floor(Math.random() * (i + 1))
      const temp = arr[randomIndex]
      arr[randomIndex] = arr[i]
      arr[i] = temp
    }
    return arr
  }

  /**
   * 切换播放模式
   * @param mode 指定的播放模式，不指定则按顺序循环切换
   */
  public static switchPlayMode(mode?: number) {
    const instance = PlaylistManager.getInstance();
    const prevMode = instance._playMode;

    // 如果没有指定模式，则按顺序循环切换
    if (mode === undefined) {
      const modeSequence = [
        // PlayMode.SEQUENCE, 现在没有人用这个模式了，意义不明
        PlayMode.LOOP,
        PlayMode.SINGLE,
        PlayMode.RANDOM,
      ];

      // 找到当前模式在序列中的位置
      let currentIndex = 0;
      for (let i = 0; i < modeSequence.length; i++) {
        if (modeSequence[i] === prevMode) {
          currentIndex = i;
          break;
        }
      }

      // 计算下一个模式
      const nextIndex = (currentIndex + 1) % modeSequence.length;
      mode = modeSequence[nextIndex];
    }

    // 设置新的播放模式
    instance._playMode = mode;
    // 发送播放模式变更事件
    EventHelper.postLoopMode(mode);

    // 处理随机播放模式的切换逻辑
    let playlistChanged = false;

    // 从其他模式切换到随机播放
    if (mode === PlayMode.RANDOM && prevMode !== PlayMode.RANDOM) {
      instance._rawPlaylist = instance._playlist.slice(); // 保存原始列表的副本
      instance._playlist = PlaylistManager.shuffle(instance._playlist);
      playlistChanged = true;
    }
    // 从随机播放切换到其他模式
    else if (prevMode === PlayMode.RANDOM && mode !== PlayMode.RANDOM) {
      instance._playlist = instance._rawPlaylist;
      playlistChanged = true;
    }

    // 更新AppStorage中的播放模式
    AppStorage.setOrCreate("current_playing_playMode", mode);

    PreferencesCache.playMode(mode); // 更新用户偏好设置中的播放模式

    // 只有当播放列表实际发生变化时才更新AppStorage
    if (playlistChanged) {
      AppStorage.setOrCreate("current_playing_playlist", instance._playlist);
      PreferencesCache.playlist(instance._playlist);
    }

    return mode;
  }

  /**
   * 播放下一首歌曲
   *
   * 默认按「用户主动切歌」语义：单曲循环下也真正跳到下一首——
   * 点了下一首却在原地重播不符合任何用户预期。
   * 原先的 forceNext 默认 false 且全部 12 个调用点都没传 true，
   * 等于单曲循环模式下切歌按钮完全失效。
   * @param respectSingleLoop 仅自动续播传 true：单曲循环下返回当前歌以便重播
   * @returns 下一首歌曲
   */
  public static playNext(respectSingleLoop: boolean = false): Song | null {
    const instance = PlaylistManager.getInstance();
    const currentIndex = instance.getCurrentIndex();

    if (currentIndex === -2 || instance._playlist.length === 0) {
      return null;
    }

    let nextIndex: number;

    // 根据播放模式决定下一首歌曲
    switch (instance._playMode) {
      case PlayMode.SINGLE:
        if (respectSingleLoop) {
          // 自动续播：单曲循环模式下继续播放当前歌曲
          nextIndex = currentIndex;
        } else {
          // 用户主动切歌：即使单曲循环也跳到下一首
          nextIndex = (currentIndex + 1) % instance._playlist.length;
        }
        break;

      case PlayMode.RANDOM:
        // 随机模式下，随机列表已排好，只需要移动到下一个
        nextIndex = (currentIndex + 1) % instance._playlist.length;
        break;

      case PlayMode.LOOP:
      case PlayMode.SEQUENCE:
      default:
      // 顺序播放和循环播放的区别在于到末尾时的处理
        nextIndex = currentIndex + 1;

      // 到达列表末尾
        if (nextIndex >= instance._playlist.length) {
          // 循环模式回到开头，顺序模式停止
          if (instance._playMode === PlayMode.LOOP) {
            nextIndex = 0;
          } else {
            // 顺序播放模式到达末尾，返回null表示播放结束
            return null;
          }
        }
        break;
    }

    instance._lastAction = PlayAction.NEXT;
    LogUtil.info("PlaylistManager ", "playNext ", "nextIndex ", nextIndex.toString());

    // 返回下一首歌曲
    return instance._playlist[nextIndex];
  }

  /**
   * 播放上一首歌曲
   *
   * 只有用户主动操作会调用，因此单曲循环下同样真正跳到上一首
   * @returns 上一首歌曲
   */
  public static playPrevious(): Song | null {
    const instance = PlaylistManager.getInstance();
    const currentIndex = instance.getCurrentIndex();

    if (currentIndex === -2 || instance._playlist.length === 0) {
      return null;
    }

    let prevIndex: number;

    // 根据播放模式决定上一首歌曲
    switch (instance._playMode) {
      case PlayMode.SINGLE:
      case PlayMode.RANDOM:
        // 随机模式下，向前移动一个位置
        prevIndex = (currentIndex - 1 + instance._playlist.length) % instance._playlist.length;
        break;

      case PlayMode.LOOP:
      case PlayMode.SEQUENCE:
      default:
      // 向前移动一个位置
        prevIndex = currentIndex - 1;

      // 到达列表开头
        if (prevIndex < 0) {
          // 循环模式跳到末尾，顺序模式保持在第一首
          if (instance._playMode === PlayMode.LOOP) {
            prevIndex = instance._playlist.length - 1;
          } else {
            // 顺序播放模式保持在第一首
            prevIndex = 0;
          }
        }
        break;
    }

    instance._lastAction = PlayAction.PRE;

    LogUtil.info("PlaylistManager ", "playPrevious ", "prevIndex ", prevIndex.toString());

    // 返回上一首歌曲
    return instance._playlist[prevIndex];
  }

  /**
   * 获取当前播放索引
   */
  private getCurrentIndex(): number {
    const instance = PlaylistManager.getInstance();
    // 优先以最近一次切歌请求的目标歌曲为基准，AppStorage 中的值在延迟起播期间是滞后的
    const currentSong = instance._targetSong ?? AppStorage.get<Song>("current_playing_song");
    if (!currentSong && instance._playlist.length === 0) {
      return -2;
    } else if (!currentSong) {
      return -1;
    }
    return instance._playlist.findIndex(song => song.id === currentSong.id);
  }

  /**
   * 装载播放列表
   * @param playlist
   * @param song 默认播放歌曲
   * @param radio 队列来源是否为「电台/推荐」——仅 radio 队列允许自动补充续播；
   *              歌单/专辑/历史等有界队列播完即止（默认 false）
   */
  public static loadPlaylist(playlist: Array<Song>, song?: Song, radio: boolean = false) {
    const instance = PlaylistManager.getInstance()
    instance._rawPlaylist = playlist
    // 如果当前播放模式是随机播放，那么需要打乱播放列表
    if (instance._playMode === PlayMode.RANDOM) {
      instance._playlist = PlaylistManager.shuffle(playlist)
    } else {
      instance._playlist = playlist
    }
    AppStorage.setOrCreate("current_playing_playlist", playlist)
    AppStorage.setOrCreate('v3_queue_radio', radio)
    PreferencesCache.playlist(playlist)
    if (song) {
      PlaylistManager.playSong(song)
    }
  }

  /**
   * 插入歌曲列表到指定索引之后
   * @param songs
   * @param index 默认是当前播放歌曲的下一首
   * @param song 默认播放歌曲
   */
  public static insertSongs(songs: Array<Song>, index: number = -1, song?: Song) {
    const instance = PlaylistManager.getInstance()
    const current_song_data = AppStorage.get<Song>("current_playing_song")
    if (!current_song_data) {
      // 没有当前播放歌曲，直接加载播放列表
      PlaylistManager.loadPlaylist(songs, song)
      return
    }
    if (index === -1) {
      index = instance._playlist.findIndex(song => song.id === current_song_data.id) + 1
    }
    instance._playlist.splice(index, 0, ...songs)
    // 如果当前播放模式是随机播放，那么插入歌曲后，需要添加rawPlaylist
    if (instance._playMode === PlayMode.RANDOM) {
      const rawIndex = instance._rawPlaylist.findIndex(song => song.id === current_song_data.id) + 1
      instance._rawPlaylist.splice(rawIndex, 0, ...songs)
    }
    AppStorage.setOrCreate("current_playing_playlist", instance._playlist)
    PreferencesCache.playlist(instance._playlist)
    if (song) {
      PlaylistManager.playSong(song)
    }
  }

  /**
   * 追加歌曲到队列末尾（按 id 去重）。供推荐流式补充：哪个接口先返回先压入。
   * 队列为空且无播放时，自动装载并起播首曲。不改变队列来源标记（radio 由起播时决定）。
   */
  public static appendSongs(songs: Array<Song>) {
    if (!songs || songs.length === 0) {
      return
    }
    const instance = PlaylistManager.getInstance()
    const existing = new Set(instance._playlist.map(s => s.id.toString()))
    const fresh = songs.filter(s => s && !existing.has(s.id.toString()))
    if (fresh.length === 0) {
      return
    }
    const current = AppStorage.get<Song>("current_playing_song")
    if (!current || instance._playlist.length === 0) {
      // 空队列/无播放：装载并起播（radio 队列，允许后续自动补充）
      PlaylistManager.loadPlaylist(fresh, fresh[0], true)
      return
    }
    instance._playlist.push(...fresh)
    if (instance._playMode === PlayMode.RANDOM) {
      instance._rawPlaylist.push(...fresh)
    }
    AppStorage.setOrCreate("current_playing_playlist", instance._playlist)
    PreferencesCache.playlist(instance._playlist)
  }

  /**
   * 删除歌曲
   * @param song
   */
  public static removeSong(song: Song) {
    const instance = PlaylistManager.getInstance()
    const index = instance._playlist.findIndex(s => s.id === song.id)
    if (index === -1) {
      return
    }
    instance._playlist.splice(index, 1)
    // 如果当前播放模式是随机播放，那么删除歌曲后，需要删除rawPlaylist
    if (instance._playMode === PlayMode.RANDOM) {
      const rawIndex = instance._rawPlaylist.findIndex(s => s.id === song.id)
      instance._rawPlaylist.splice(rawIndex, 1)
    }
    AppStorage.setOrCreate("current_playing_playlist", instance._playlist)
    PreferencesCache.playlist(instance._playlist)
  }

  /**
   * 清空播放列表
   */
  public static clearPlaylist() {
    const instance = PlaylistManager.getInstance()
    instance._playlist = []
    instance._rawPlaylist = []
    AppStorage.setOrCreate("current_playing_playlist", [])
    PreferencesCache.playlist([])
  }

  /**
   * 获取当前播放模式
   */
  public static getPlayMode(): number {
    const instance = PlaylistManager.getInstance()
    return instance._playMode
  }

  /**
   * 获取最后一次操作
   */
  public static getLastAction(): PlayAction | null {
    const instance = PlaylistManager.getInstance()
    return instance._lastAction
  }
}