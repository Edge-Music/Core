import { EmitterUtil, LogUtil, ToastUtil } from "@pura/harmony-utils";
import { Song } from "../type/Adapter";
import { avSession } from "@kit.AVSessionKit";
import { SongCacheItem, SongCacheManager } from "./SongCacheManager";
import { fileIo as fs } from '@kit.CoreFileKit';
import { avPlayerManager } from "./AVPlayerManager";
import { cover } from "./AdapterHelper";
import { util } from "@kit.ArkTS";
import { DownloadManager } from "./DownloadUtils";
import { ContextHelper } from "./ContextHelper";
import { SourceAdapter } from "../adapter";
import FormUtils from "./FormUtils";

async function checkCacheFileExists(cache: SongCacheItem, key: string) {
  if (!cache || !cache.path) {
    return false;
  }
  const access = await fs.access(cache.path);
  if (access) {
    return true;
  }
  SongCacheManager.remove(key);
  return false;
}

const handleSongDownload = async (song: Song) => {
  // 判断是否可以下载
  const privilege = song.privilege;
  const playable = privilege?.playable;
  if (!playable) {
    ToastUtil.showShort("当前歌曲无法播放，请尝试其他歌曲");
    return;
  }

  // 下载歌曲
  const url = song.meta?.url;
  if (!url) {
    ToastUtil.showShort("音乐资源不存在");
    return;
  }

  let fileName = url.split("/").pop() ?? `${util.generateRandomUUID()}`
  const index = fileName.indexOf("?")
  if (index > 0) {
    fileName = fileName.substring(0, index)
  }

  const filesDir = ContextHelper.getContext()?.filesDir;
  fileName = `${filesDir}/${fileName}`;

  await avPlayerManager.stop();

  DownloadManager.downloadFile({
    url,
    fileName,
  });

  let size = song.meta?.size;
  if (!size) {
    ToastUtil.showShort("音乐资源大小未知，本次播放将无法跳转进度");
    size = -1;
  }

  // 等待文件创建
  await new Promise<void>((resolve) => {
    const checkFile = setInterval(async () => {
      try {
        const stats = await fs.stat(fileName);
        const progress = (stats.size / size!) * 100;
        if (progress >= 10) {
          clearInterval(checkFile);
          resolve();
        }
      } catch (err) {
        // 文件还未创建,继续等待
      }
    }, 100);
  });

  // 创建缓存记录
  SongCacheManager.set(song.meta?.md5 || `${song.id}_${song.source?.id}`, fileName, song);

  return fileName;
}

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

const playSong = async (song: Song, path: string, cached: boolean, pause: boolean) => {
  avPlayerManager.stop().then(async () => {
    FormUtils.updateMusicControlCards(song,!pause)
    await avPlayerManager.playByPath(path, cached ? undefined : song.meta?.size, pause, {
      assetId: `track-${song.id}-${song.source?.id}`,
      duration: song.duration,
      title: song.name,
      mediaImage: cover(song.album.cover, 512),
      artist: song.artists.map(a => a.name).join("/"),
      lyric: song.meta?.lyric?.normal,
    })
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
    // 尝试获取缓存
    const key = song.meta?.md5 || `${song.id}_${song.source?.id}`;
    const cache = SongCacheManager.get(`${key}`);
    if (cache) {
      // 判断是否存在缓存
      const exists = await checkCacheFileExists(cache, key);
      if (exists) {
        await playSong(song, cache.path, true, pause);
      } else {
        const filePath = await handleSongDownload(song);
        if (filePath) {
          await playSong(song, filePath, false, pause); // 如果下载成功，继续播放
        }
      }
    } else {
      LogUtil.info("SourceAdapter ", "defaultPlaySongCallback ", "no cache ");
      const filePath = await handleSongDownload(song);
      LogUtil.info("SourceAdapter ", "defaultPlaySongCallback ", "filePath ", filePath);
      if (filePath) {
        await playSong(song, filePath, false, pause); // 如果下载成功，继续播放
      }
    }
  } catch (error) {
    LogUtil.error("SourceAdapter ", "defaultPlaySongCallback", error.message);
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
      }
      else{
        let pageStack = AppStorage.get("pageStack") as NavPathStack
        pageStack.pushPath({name:targetPage},{launchMode:LaunchMode.MOVE_TO_TOP_SINGLETON})

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
    EmitterUtil.post("on_song_state", data);
  }

  public static postPauseTimer(pauseAt: number) {
    EmitterUtil.post("on_pause_timer", pauseAt);
  }

  public static postFormJumpPage(targetPage: string){
    EmitterUtil.post("on_form_jump", targetPage);
  }
}