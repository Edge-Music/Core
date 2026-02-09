import { EmitterUtil, LogUtil, ToastUtil, WantUtil } from '@pura/harmony-utils';
import { Song, SongV2 } from '../type/Adapter';
import { avSession } from '@kit.AVSessionKit';
import { SongCacheItem, SongCacheManager } from './SongCacheManager';
import { fileIo as fs } from '@kit.CoreFileKit';
import { avPlayerManager } from './AVPlayerManager';
import { cover } from './AdapterHelper';
import { util } from '@kit.ArkTS';
import { SourceAdapter } from '../adapter';
import FormUtils from './FormUtils';
import { PreferencesCache } from './PreferenceCache';
import { SongDownloadManager } from './SongDownloadManager';
import { image } from '@kit.ImageKit';
import { playRecordManager } from './PlayRecordManager';
import { AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const TAG = 'EventHelper'

// 文件优先级结果接口
interface FilePriorityResult {
  filePath: string;
  fileType: 'cache' | 'download' | 'none';
  song: Song;
}

/**
 * 文件优先级判断逻辑
 * 优先级规则：
 * 1. 如果歌曲既有缓存又有下载文件：优先使用缓存文件
 * 2. 如果歌曲只有下载文件没有缓存：使用下载文件
 * 3. 如果歌曲只有缓存没有下载文件：使用缓存文件
 * 4. 如果都没有：返回none类型
 */
async function getOptimalFilePath(song: Song): Promise<FilePriorityResult | null> {
  const songId = song.id.toString();
  const cacheKey = `${song.id}_${song.source?.id}`;
  const expectedSize = song.meta?.size;

  // 检查缓存状态
  const hasCache = SongCacheManager.has(cacheKey);
  const cache = hasCache ? SongCacheManager.get(cacheKey) : null;

  // 检查下载状态
  const hasDownload = SongDownloadManager.hasSong(songId);
  const downloadItem = hasDownload ? SongDownloadManager.getSong(songId) : null;

  LogUtil.info(`[${TAG}]`, `File priority check for song ${song.name}: cache=${hasCache}, download=${hasDownload}`);

  // 优先级判断
  if (hasCache && cache) {
    // 验证缓存文件是否真实存在
    const cacheExists = await checkCacheFileExists(cache, cacheKey, expectedSize);
    if (cacheExists) {
      LogUtil.info(`[${TAG}]`, `Using cache file for song ${song.name}: ${cache.path}`);
      return {
        filePath: cache.path,
        fileType: 'cache',
        song: cache.song
      };
    }
  }

  if (hasDownload && downloadItem) {
    // 兼容旧版本：仅当下载文件已完整时才使用本地文件。
    const ok = await checkLocalFileReady(downloadItem.path, expectedSize);
    if (ok) {
      LogUtil.info(`[${TAG}]`, `Using download file for song ${song.name}: ${downloadItem.path}`);
      return {
        filePath: downloadItem.path,
        fileType: 'download',
        song: downloadItem.song
      };
    }
  }

  LogUtil.info(`[${TAG}]`, `No local file found for song ${song.name}, will need to download`);
  return null;
}

async function checkLocalFileReady(path: string, expectedBytes?: number): Promise<boolean> {
  if (!path) {
    return false;
  }
  try {
    const stats = await fs.stat(path);
    if (expectedBytes && expectedBytes > 0) {
      return stats.size >= expectedBytes;
    }
    return stats.size > 0;
  } catch (e) {
    return false;
  }
}

async function checkCacheFileExists(cache: SongCacheItem, key: string, expectedBytes?: number) {
  if (!cache || !cache.path) {
    console.warn(`[${TAG}]`, `Cache for key ${key} does not exist or path is invalid.`);
    return false;
  }
  const ok = await checkLocalFileReady(cache.path, expectedBytes);
  console.info(`[${TAG}]`, `Checking cache file for key ${key}: ok=${ok}, path=${cache.path}`);
  if (ok) {
    return true;
  }

  // 文件不存在或不完整：清理缓存映射，避免下次优先使用半成品文件
  SongCacheManager.remove(key);
  return false;
}

/**
 * 处理特殊 URL（browser: 或 text: 前缀）
 * @param url 歌曲 URL
 * @returns 如果是特殊 URL 则返回 true，否则返回 false
 */
const handleSpecialUrl = async (url: string): Promise<boolean> => {
  if (!url) {
    return false;
  }

  // 检查 browser: 前缀
  if (url.startsWith('browser:')) {
    const targetUrl = url.substring('browser:'.length);
    LogUtil.info(TAG, `Detected browser URL: ${targetUrl}`);

    try {
      WantUtil.toWebBrowser(targetUrl)
      LogUtil.info(TAG, `Opened browser with URL: ${targetUrl}`);
    } catch (error) {
      LogUtil.error(TAG, `Failed to open browser: ${JSON.stringify(error)}`);
      ToastUtil.showShort("无法打开浏览器");
    }

    return true; // 是特殊 URL，阻止后续播放逻辑
  }

  // 检查 text: 前缀
  if (url.startsWith('text:')) {
    const message = url.substring('text:'.length);
    LogUtil.info(TAG, `Detected text URL: ${message}`);
    ToastUtil.showShort(message);
    return true; // 是特殊 URL，阻止后续播放逻辑
  }

  return false; // 不是特殊 URL
};

// NOTE:
// We no longer create new cache/download items here.
// - To avoid double bandwidth, we play by URL directly when there is no complete local file.
// - We still READ old cached/download files for compatibility.

const defaultLoveSongCallback = (_assetId: string) => {
  const currentSong = AppStorage.get<Song>("current_playing_song");
  if (!currentSong) {
    LogUtil.warn("EventHelper ", "defaultLoveSongCallback", "No current playing song found");
    return;
  }
  const like = currentSong.meta?.isFavorite
  if (currentSong.meta) {
    currentSong.meta.isFavorite = !like; // 切换喜欢状态
  } else {
    currentSong.meta = {
      isFavorite: true,
    };
  }
  AppStorage.set("current_playing_song", currentSong); // 更新当前歌曲缓存
  const session = avPlayerManager.getSession();
  if (session) {
    session.setAVPlaybackState({
      isFavorite: !like // 切换喜欢状态
    })
  }
};

export function base64ToPixelMap(base64Str: string): image.PixelMap {
  const base64Helper = new util.Base64Helper();
  // 去除前缀 data:image/png;base64, 或 data:image/jpeg;base64, 等
  const prefix = base64Str.indexOf("base64,") + "base64,".length;
  if (prefix > 0) {
    base64Str = base64Str.substring(prefix);
  }
  // 解码 Base64 字符串
  const data = base64Helper.decodeSync(base64Str);
  const imageSource = image.createImageSource(data.buffer)
  const opts: image.DecodingOptions = { editable: true };
  return imageSource.createPixelMapSync(opts);
}

const playSong = async (song: Song, path: string, cached: boolean, pause: boolean) => {
  console.info(`[AVPlayerManager]`, `Playing song: ${song.name}, path: ${path}, cached: ${cached}, pause: ${pause}`);

  // 记录播放事件（只在非暂停状态下记录）
  if (!pause) {
    playRecordManager.recordPlay(song).catch((error: Error) => {
      LogUtil.error("EventHelper ", "playSong", `Failed to record play: ${error.message}`);
    });
  }

  avPlayerManager.stop().then(async () => {
    FormUtils.updateMusicControlCards(song, !pause)
    let meteData: avSession.AVMetadata = {
      assetId: `track-${song.id}-${song.source?.id}`,
      duration: song.duration,
      title: song.name,
      mediaImage: cover(song.album.cover, 512) as string,
      artist: song.artists.map(a => a.name).join("/"),
    }
    if (song.meta?.lyric?.normal) {
      meteData.lyric = song.meta.lyric.normal;
    }
    // 如果cover并不是http(s)开头且是base64，则转化为 PixelMap
    if (song.album.cover && song.album.cover.startsWith("data:image/")) {
      try {
        const pixelMap = base64ToPixelMap(song.album.cover);
        meteData.mediaImage = pixelMap;
      } catch (error) {
        LogUtil.error("EventHelper ", "playSong", `Failed to convert cover to PixelMap: ${error.message}`);
      }
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      await avPlayerManager.playByUrl(path, song.meta?.size, pause, meteData)
      if (pause) {
        await avPlayerManager.pauseWithoutFadeOut()
      }
    } else {
      await avPlayerManager.playByPath(path, song.meta?.size, pause, meteData)
    }
    const session = avPlayerManager.getSession();
    if (session) {
      session.setAVPlaybackState({
        isFavorite: song.meta?.isFavorite
      })
    }
  });
}

// 让主线程代码好看一点，所以写在这里
const defaultPlaySongCallback = async (data: [Song, boolean]) => {
  const song = data[0];
  const pause = data[1]; // 是否暂停
  try {
    // 使用文件优先级判断逻辑
    const optimalFile = await getOptimalFilePath(song);

    if (optimalFile) {
      // 找到了本地文件（缓存或下载）
      LogUtil.info("EventHelper ", "defaultPlaySongCallback ",
        `Using ${optimalFile.fileType} file: ${optimalFile.filePath}`);
      AppStorage.setOrCreate("current_playing_song", optimalFile.song);
      PreferencesCache.lastSong(optimalFile.song);
      await playSong(optimalFile.song, optimalFile.filePath, optimalFile.fileType !== 'none', pause);
      // 尝试访问一遍最新数据，但不缓存歌曲文件
      SourceAdapter.getSongDetail(optimalFile.song).then((latestSong) => {
        AppStorage.setOrCreate("current_playing_song", latestSong);
        PreferencesCache.lastSong(latestSong);
      }).catch((error: Error) => {
        LogUtil.error("EventHelper ", "defaultPlaySongCallback ",
          `Failed to fetch latest song details: ${error.message}`);
      });
    } else {
      // 没有完整本地文件：直接使用 URL 播放（避免 AVPlayer 时代的 dataSrc 边下边播造成的不兼容）
      LogUtil.info("EventHelper ", "defaultPlaySongCallback ", "No complete local file, playing by URL...");

      const detailed = await SourceAdapter.getSongDetail(song);
      AppStorage.setOrCreate("current_playing_song", detailed);
      PreferencesCache.lastSong(detailed);

      const url = detailed.meta?.url;
      if (!url) {
        ToastUtil.showShort("音乐资源不存在");
        return;
      }

      const isSpecialUrl = await handleSpecialUrl(url);
      if (isSpecialUrl) {
        return;
      }

      await playSong(detailed, url, false, pause);
    }
  } catch (error) {
    LogUtil.error("EventHelper ", "defaultPlaySongCallback", error.message);
  }
};

export class EventHelper {
  public static subscribePlaySong(callback?: (data: [Song, boolean]) => void) {
    EmitterUtil.onSubscribe<[Song, boolean]>("on_playing_song", (data) => {
      if (callback) {
        callback(data);
      } else {
        defaultPlaySongCallback(data);
      }
    });
  }

  public static postPlaySong(data: [Song, boolean]) {
    EmitterUtil.post("on_playing_song", data);
  }

  public static subscribeLoopMode(callback: (loopMode: avSession.LoopMode | number) => void) {
    EmitterUtil.onSubscribe<avSession.LoopMode | number>("on_loop_mode", (data) => {
      callback(data);
    });
  }

  public static postLoopMode(loopMode: avSession.LoopMode | number) {
    EmitterUtil.post("on_loop_mode", loopMode);
  }

  public static subscribeFavoriteToggle(callback?: (data: string) => void) {
    EmitterUtil.onSubscribe("on_favorite_toggle", (data: string) => {
      if (callback) {
        callback(data);
      } else {
        // 默认回调
        defaultLoveSongCallback(data);
      }
    });
  }

  public static subscribeInitData(callback?: (data: string) => void) {
    EmitterUtil.onSubscribe("on_init_data", (data: string) => {
      if (callback) {
        callback(data);
      } else {
        Promise.all([
          SourceAdapter.getRecommendList(),
          SourceAdapter.getRecommendSongs(),
          SourceAdapter.getRecommendArtists(),
          SourceAdapter.getTopList(),
          SourceAdapter.getUserPlaylist()
        ])
      }
    });
  }

  public static subscribePauseTimer(callback: (pauseAt: number) => void) {
    EmitterUtil.onSubscribe("on_pause_timer", (pauseAt: number) => {
      callback(pauseAt);
    });
  }

  public static subscribeFormJumpPage(callback?: (targetPage: string) => void) {
    EmitterUtil.onSubscribe("on_form_jump", (targetPage: string) => {
      if (callback) {
        callback(targetPage);
      } else {
        let pageStack = AppStorage.get("pageStack") as NavPathStack
        pageStack.pushPath({ name: targetPage }, { launchMode: LaunchMode.MOVE_TO_TOP_SINGLETON })
      }
    });
  }

  public static postInitData(data: string) {
    EmitterUtil.post("on_init_data", data);
  }

  public static postFavoriteToggle(data: string) {
    EmitterUtil.post("on_favorite_toggle", data);
  }

  public static subscribeSongState(callback: (data: "PLAY" | "PAUSE") => void) {
    EmitterUtil.onSubscribe("on_song_state", (data: "PLAY" | "PAUSE") => {
      callback(data);
    });
  }

  public static postSongState(data: "PLAY" | "PAUSE") {
    let songState = AppStorage.get<"PLAY" | "PAUSE">('SongState')
    LogUtil.info(`[${TAG}]`, `现在全局[on_song_state]状态：[${songState}]`)
    if (songState !== data) {
      LogUtil.info(`[${TAG}]`, `发送[on_song_state]事件成功，状态由[${songState}]变[${data}]`)
      EmitterUtil.post("on_song_state", data);
      AppStorage.setOrCreate('SongState', data)
      return
    }
    if (songState === undefined) {
      LogUtil.info(`[${TAG}]`, `发送[on_song_state]事件成功，状态由[${songState}]变[${data}]`)
      EmitterUtil.post("on_song_state", data);
      AppStorage.setOrCreate('SongState', data)
    }
  }

  public static postPauseTimer(pauseAt: number) {
    EmitterUtil.post("on_pause_timer", pauseAt);
  }

  public static postFormJumpPage(targetPage: string) {
    EmitterUtil.post("on_form_jump", targetPage);
  }

  public static subscribePipLyric(callback: (data: string) => void) {
    EmitterUtil.onSubscribe("on_pip_lyric", (data: string) => {
      callback(data);
    });
  }

  public static postPipLyric(data: string) {
    EmitterUtil.post("on_pip_lyric", data);
    LogUtil.info(`[${TAG}]`, `发送[on_pip_lyric]事件成功，当前歌词：[${data}]`)
  }

  public static unSubscribePipLyric() {
    EmitterUtil.unSubscribe('on_pip_lyric')
  }

  public static getPipLyricListenerCount(): number {
    return EmitterUtil.getListenerCount('on_pip_lyric')
  }
}
