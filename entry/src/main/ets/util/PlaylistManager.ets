import { SourceAdapter } from "../adapter";
import { Song } from "../type/Adapter";
import { avSession } from "@kit.AVSessionKit";
import { EventHelper } from "./EventHelper";
import { avPlayerManager } from "./AVPlayerManager";
import { LogUtil } from "@pura/harmony-utils";
import { PreferencesCache } from "./PreferenceCache";


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

  public static async playSong(song: Song, pause = false) {
    // 获取当前播放的歌曲
    const currentSong = AppStorage.get<Song>("current_playing_song")
    // 如果当前播放的歌曲和要播放的歌曲相同，则不做任何操作，且并不是单曲循环模式
    if (currentSong && currentSong.id === song.id && PlaylistManager.getPlayMode() !== PlayMode.SINGLE) {
      EventHelper.postSongState("PLAY")
      return
    } else if (currentSong && currentSong.id === song.id && PlaylistManager.getPlayMode() === PlayMode.SINGLE) {
      LogUtil.info("PlaylistManager ", "PlaySong ", "Single Loop Mode")
      // 如果当前播放的歌曲和要播放的歌曲相同，且是单曲循环模式，则只需要Seek到0
      await avPlayerManager.seek(0)
      await avPlayerManager.play()
      EventHelper.postSongState("PLAY")
      return;
    }
    LogUtil.info("PlaylistManager ", "playSong ", "song ", JSON.stringify(song))
    AppStorage.setOrCreate("current_playing_song", song)
    // 获取歌曲信息
    SourceAdapter.getSongDetail(song).then(songDetail => {
      AppStorage.setOrCreate("current_playing_song", songDetail)
      PreferencesCache.lastSong(songDetail)
      // 播放音乐
      EventHelper.postPlaySong([songDetail, pause]) // 发送播放歌曲事件
    })
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
   * @param forceNext 是否强制播放下一首（忽略单曲循环模式）
   * @returns 下一首歌曲
   */
  public static playNext(forceNext: boolean = false): Song | null {
    const instance = PlaylistManager.getInstance();
    const currentIndex = instance.getCurrentIndex();

    if (currentIndex === -2 || instance._playlist.length === 0) {
      return null;
    }

    let nextIndex: number;

    // 根据播放模式决定下一首歌曲
    switch (instance._playMode) {
      case PlayMode.SINGLE:
        if (forceNext) {
          // 强制下一首时，即使是单曲循环也继续
          nextIndex = (currentIndex + 1) % instance._playlist.length;
        } else {
          // 单曲循环模式下继续播放当前歌曲
          nextIndex = currentIndex;
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
        // 单曲循环模式下继续播放当前歌曲
        prevIndex = currentIndex;
        break;

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
    const currentSong = AppStorage.get<Song>("current_playing_song");
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
   */
  public static loadPlaylist(playlist: Array<Song>, song?: Song) {
    const instance = PlaylistManager.getInstance()
    instance._rawPlaylist = playlist
    // 如果当前播放模式是随机播放，那么需要打乱播放列表
    if (instance._playMode === PlayMode.RANDOM) {
      instance._playlist = PlaylistManager.shuffle(playlist)
    } else {
      instance._playlist = playlist
    }
    AppStorage.setOrCreate("current_playing_playlist", playlist)
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