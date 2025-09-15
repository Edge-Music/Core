import { Artist, ID, Playlist, Song, SourceConfig } from "../type/Adapter";
import { LogUtil, PreferencesUtil, ToastUtil } from '@pura/harmony-utils';
import { display } from "@kit.ArkUI";

// 比特率类型
export type BitrateType = 128000 | 192000 | 320000 | 350000 | 999000 | number;

export interface QualityLevel {
  level: string;
  description: string | Resource
  bitrate: BitrateType;
}

export interface SBLyricsPre{
  open:boolean;
  lines:number;
  alignment:number;
  x: number;
  y: number;
  width: number;
  height: number;
  transparency: number;
  fontSize: number;
  fontColor: Color | ResourceColor,
  showShadow: boolean,
  cornerRadius: number
}

export const qualityLevels: QualityLevel[] = [
  { level: 'standard', description: $r('app.string.quality_standard'), bitrate: 128000 },
  { level: 'higher', description: $r('app.string.quality_higher'), bitrate: 192000 },
  { level: 'exhigh', description: $r('app.string.quality_ex_high'), bitrate: 320000 },
  { level: 'lossless', description: $r('app.string.quality_lossless'), bitrate: 350000 },
  { level: 'hires', description: $r('app.string.quality_hires'), bitrate: 999000 },
  { level: 'vivid', description: $r('app.string.vivid'), bitrate: 999900 },
];

/**
 * 根据比特率获取音质等级
 * @param bitrate 比特率
 */
export function getQualityLevel(bitrate: BitrateType): QualityLevel {
  return qualityLevels.find(item => item.bitrate === bitrate) as QualityLevel;
}

/**
 * 系统设置偏好
 */
const TAG = 'PreferencesCache'
export class PreferencesCache {
  private static CACHE_MAP = new Map<string, string>();

  /**
   * 设置缓存
   */
  static setCache(key: string, value: string): void {
    PreferencesUtil.putSync(key, value);
    PreferencesCache.CACHE_MAP.set(key, value);
  }

  /**
   * 获取缓存
   */
  static getCache(key: string, defaultValue?: string): string {
    if (PreferencesCache.CACHE_MAP.has(key)) {
      return PreferencesCache.CACHE_MAP.get(key) as string;
    }
    const value = PreferencesUtil.getStringSync(key, defaultValue);
    PreferencesCache.CACHE_MAP.set(key, value);
    return value;
  }

  static deleteCache(key: string) {
    PreferencesUtil.deleteSync(key);
    PreferencesCache.CACHE_MAP.delete(key);
  }


  /**
   * 获取用户数据源
   */
  static getUserDataSource(): SourceConfig[] {
    const sourceConfig = PreferencesCache.getCache('user_data_source', '[]');
    return JSON.parse(sourceConfig);
  }

  /**
   * 设置用户数据源
   */
  static setUserDataSource(sourceConfig: SourceConfig[]): void {
    PreferencesCache.setCache('user_data_source', JSON.stringify(sourceConfig));
    AppStorage.setOrCreate('user_data_source', sourceConfig);
  }

  /**
   * 添加用户数据源
   */
  static addUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getUserDataSource();
    sourceList.push(sourceConfig);
    PreferencesCache.setUserDataSource(sourceList);
  }

  /**
   * 更新指定用户数据源
   */
  static updateUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceConfig.id);
    if (index !== -1) {
      sourceList[index] = sourceConfig;
      PreferencesCache.setUserDataSource(sourceList);
    }
  }

  /**
   * 删除指定用户数据源
   */
  static deleteUserDataSource(sourceId: ID): void {
    const sourceList = PreferencesCache.getUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceId);
    if (index !== -1) {
      sourceList.splice(index, 1);
      PreferencesCache.setUserDataSource(sourceList);
    }
  }

  /**
   * 获取展示用户数据源
   */
  static getShowUserDataSource(): SourceConfig[] {
    const sourceConfig = PreferencesCache.getCache('show_user_data_source', '[]');
    return JSON.parse(sourceConfig);
  }

  /**
   * 设置展示用户数据源
   */
  static setShowUserDataSource(sourceConfig: SourceConfig[]): void {
    PreferencesCache.setCache('show_user_data_source', JSON.stringify(sourceConfig));
    AppStorage.setOrCreate('show_user_data_source', sourceConfig);
  }

  /**
   * 添加展示用户数据源
   */
  static addShowUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getShowUserDataSource();
    sourceList.push(sourceConfig);
    PreferencesCache.setShowUserDataSource(sourceList);
  }

  /**
   * 更新展示指定用户数据源
   */
  static updateShowUserDataSource(sourceConfig: SourceConfig): void {
    const sourceList = PreferencesCache.getShowUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceConfig.id);
    if (index !== -1) {
      sourceList[index] = sourceConfig;
      PreferencesCache.setShowUserDataSource(sourceList);
    }
  }

  /**
   * 删除展示指定用户数据源
   */
  static deleteShowUserDataSource(sourceId: ID): void {
    const sourceList = PreferencesCache.getShowUserDataSource();
    const index = sourceList.findIndex(item => item.id === sourceId);
    if (index !== -1) {
      sourceList.splice(index, 1);
      PreferencesCache.setShowUserDataSource(sourceList);
    }
  }

  /**
   * 获取用户偏好
   * @param key 偏好键
   * @param defaultValue 默认值
   */
  static getUserPreference(key: string, defaultValue?: string): string {
    key = 'user_preference_' + key;
    return PreferencesCache.getCache(key, defaultValue);
  }

  /**
   * 设置用户偏好
   * @param key 偏好键
   * @param value 偏好值
   */
  static setUserPreference(key: string, value: string): void {
    key = 'user_preference_' + key;
    PreferencesCache.setCache(key, value);
  }

  /**
   * 用户偏好 - 中断后继续
   * @param value 是否中断后继续（若不传值则获取当前设置）
   * @returns 是否中断后继续
   */
  static interruptingContinue(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('interrupting_continue', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('interrupting_continue') === '1';
  }

  /**
   * 用户偏好 - 播放歌词
   * @param value 是否播放歌词（若不传值则获取当前设置）
   * @returns 是否播放歌词
   */
  static playerLyric(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('player_lyric', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('player_lyric') === '1';
  }

  /**
   * 用户偏好 - 播放音质
   * @param value 音质（若不传值则获取当前设置）
   * @returns 音质
   */
  static playingLevel(value?: BitrateType): BitrateType {
    if (value) {
      PreferencesCache.setUserPreference('playing_level', value.toString());
    }
    return parseInt(PreferencesCache.getUserPreference('playing_level') || '128000') as BitrateType;
  }

  /**
   * 用户偏好 - 下载音质
   * @param value 音质（若不传值则获取当前设置）
   * @returns 音质
   */
  static downloadLevel(value?: BitrateType): BitrateType {
    if (value) {
      PreferencesCache.setUserPreference('download_level', value.toString());
    }
    return parseInt(PreferencesCache.getUserPreference('download_level') || '999000') as BitrateType;
  }

  /**
   * 用户偏好 - 播放缓存
   * @param value 缓存大小（若不传值则获取当前设置）
   * @returns 缓存大小
   */
  static playingCache(value?: number): number {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('playing_cache', value.toString());
    }

    const storedValue = PreferencesCache.getUserPreference('playing_cache');
    return storedValue !== undefined && storedValue !== null && storedValue !== ''
      ? parseInt(storedValue)
      : 100;
  }

  /**
   * 用户偏好 - 请求缓存过期时间
   * @param value 过期时间（若不传值则获取当前设置）
   * @returns 过期时间
   */
  static requestCacheExpire(value?: number): number {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('request_cache_expire', value.toString());
    }

    const storedValue = PreferencesCache.getUserPreference('request_cache_expire');
    return storedValue !== undefined && storedValue !== null && storedValue !== ''
      ? parseInt(storedValue)
      : 7;
  }

  /**
   * 歌单持久化 - 存储
   * @param songs
   */
  static playlist(songs?: Song[]): Song[] {
    if (songs) {
      PreferencesCache.setCache('playlist', JSON.stringify(songs));
    }
    return JSON.parse(PreferencesCache.getCache('playlist', '[]'));
  }

  /**
   * 上一次播放的歌曲
   * @param songs
   */
  static lastSong(song?: Song): Song | null {
    if (song) {
      PreferencesCache.setCache('last_song', JSON.stringify(song));
    }
    return JSON.parse(PreferencesCache.getCache('last_song', 'null'));
  }

  /**
   * 播放模式
   * @param value 播放模式（若不传值则获取当前设置）
   */
  static playMode(value?: number): number {
    if (value !== undefined) {
      // 将 value 转换为字符串存储
      PreferencesCache.setUserPreference('play_mode', value.toString());
    }
    const storedValue = PreferencesCache.getUserPreference('play_mode', '0'); // 默认值为 0
    // 尝试将存储的值转换为数字
    const parsedValue = parseInt(storedValue, 10);
    // 如果转换失败，返回默认值 0
    if (isNaN(parsedValue)) {
      return 0; // 默认值
    }
    return parsedValue; // 返回解析后的值
  }

  /**
   * 播放页面 封面-歌词布局翻转
   * @param value 是否翻转
   * @returns 是否翻转
   */
  static flipCoverLyric(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('flip_cover_lyric', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('flip_cover_lyric') === '1';
  }

  /**
   * 显示翻译/音译歌词
   * @param value 是否显示
   * @returns 是否显示
   */
  static showTranslationLyric(value?: boolean): boolean {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('show_translation_lyric', value ? '1' : '0');
    }
    return PreferencesCache.getUserPreference('show_translation_lyric') === '1';
  }

  /**
   * 获取缓存
   */
  static getPlaylistCache(strIndex: string): Playlist[] {
    const cache = PreferencesCache.getCache(strIndex, '[]');
    return JSON.parse(cache);
  }

  static getArtistCache(strIndex: string): Artist[] {
    const cache = PreferencesCache.getCache(strIndex, '[]');
    return JSON.parse(cache);
  }

  static getSongCache(strIndex: string): Song[] {
    const cache = PreferencesCache.getCache(strIndex, '[]');
    return JSON.parse(cache);
  }

  /**
   * 设置缓存
   */
  static setPlaylistCache(strIndex: string, sourceConfig: Playlist[]): void {
    PreferencesCache.setCache(strIndex, JSON.stringify(sourceConfig));
    AppStorage.setOrCreate(strIndex, sourceConfig);
  }

  static setArtistCache(strIndex: string, sourceConfig: Artist[]): void {
    PreferencesCache.setCache(strIndex, JSON.stringify(sourceConfig));
    AppStorage.setOrCreate(strIndex, sourceConfig);
  }

  static setSongCache(strIndex: string, sourceConfig: Song[]): void {
    PreferencesCache.setCache(strIndex, JSON.stringify(sourceConfig));
    AppStorage.setOrCreate(strIndex, sourceConfig);
  }

  static addPlaylistsCache(strIndex: string, sourceConfig: Playlist[]): void {
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache(strIndex, '[]'));
    playlists.push(...sourceConfig)
    PreferencesCache.setCache(strIndex, JSON.stringify(playlists));
    AppStorage.setOrCreate(strIndex, playlists);
  }

  static updatePlaylistsCache(strIndex: string, sourceConfig: Playlist, name: string | undefined, desc: string | undefined): void {
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache(strIndex, '[]'));
    playlists.filter((item: Playlist) => {
      if (item.id === sourceConfig.id) {
        item.name = name
        item.description = desc
      }
    })
    PreferencesCache.setCache(strIndex, JSON.stringify(playlists));
    AppStorage.setOrCreate(strIndex, playlists);
  }

  static deletePlaylistCache(strIndex: string, sourceConfig: Playlist): void {
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache(strIndex, '[]'));
    playlists.filter((item: Playlist, index: number) => {
      if (item.id === sourceConfig.id) {
        playlists.splice(index, 1)
        LogUtil.info(`[${TAG}]`, `删除后的歌单：${JSON.stringify(playlists)}`)
        PreferencesCache.setCache(strIndex, JSON.stringify(playlists));
        AppStorage.setOrCreate(strIndex, playlists);
      }
    })
  }

  static async deleteSongCache(strIndex: string, playlistId: number | string, song: Song): Promise<void> {
    // 1. 从缓存中获取播放列表数组
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache(strIndex, '[]'));
    let tmpSongs: Song[] = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlistId}`, '[]'))

    // 2. 查找目标播放列表（根据sourceConfig.id）
    let targetPlaylistIndex: number = -1
    targetPlaylistIndex = playlists.findIndex((playlist: Playlist) => playlist.id === playlistId);

    // 3. 如果找到目标播放列表
    if (targetPlaylistIndex !== -1) {
      // 4. 从songs数组中移除指定歌曲（根据song.id）
      tmpSongs = tmpSongs.filter((s: Song) => s.id !== song.id);

      playlists[targetPlaylistIndex].size = tmpSongs.length
      if(tmpSongs.length != 0) {
        playlists[targetPlaylistIndex].cover = tmpSongs[tmpSongs.length-1].album.cover
      } else {
        playlists[targetPlaylistIndex].cover = $r('app.media.icon_startwindow')
      }

      // 5. 更新缓存
      PreferencesCache.setCache(strIndex, JSON.stringify(playlists));
      PreferencesCache.setCache(`aggregation_playlist_songs_${playlistId}`, JSON.stringify(tmpSongs));

      AppStorage.setOrCreate(strIndex, playlists);
      // AppStorage.setOrCreate('current_playlist_data', tmpSongs)

      LogUtil.info(`[${TAG}]`, `已从播放列表${playlists[targetPlaylistIndex].name}中删除歌曲: ${song.name}`);
      LogUtil.info(`[${TAG}]`, `删除后的歌单：${JSON.stringify(playlists)}`)
      LogUtil.info(`[${TAG}]`, `删除后的歌曲：${JSON.stringify(tmpSongs)}`)
    } else {
      LogUtil.warn(`[${TAG}]`, `未找到ID为${playlists[targetPlaylistIndex].name}的播放列表`);
    }

  }

  static async addSongToAggregationPlaylist(playlist: Playlist, song: Song): Promise<boolean> {
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache('aggregation_playlist', '[]'));
    let tmpSongs: Song[] = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]'))

    let targetIndex: number = playlists.findIndex((item: Playlist) => item.id === playlist.id);
    const isExist = tmpSongs!.some((s: Song) => s.id === song.id);

    if(isExist) {
      LogUtil.info(`[${TAG}]`, `[${song.name}]已存在于歌单[${playlists[targetIndex].name}]`)
    } else {
      let item: Playlist = playlists[targetIndex]
      song.sourceID = song.source?.id
      if(tmpSongs){
        tmpSongs.push(song)
      }else{
        tmpSongs = [song]
      }

      playlists[targetIndex].size = tmpSongs.length
      playlists[targetIndex].cover = song.album.cover

      PreferencesCache.setCache(`aggregation_playlist_songs_${playlist.id}`, JSON.stringify(tmpSongs));
      PreferencesCache.setCache('aggregation_playlist', JSON.stringify(playlists));
      AppStorage.setOrCreate('aggregation_playlist', playlists);
      LogUtil.info(`[${TAG}]`, `添加后的歌单：${JSON.stringify(playlists)}`)
      LogUtil.info(`[${TAG}]`, `添加后的歌曲：${JSON.stringify(tmpSongs)}`)
    }

    return isExist
  }

  static async addSongsToAggregationPlaylist(playlist: Playlist, songs: Song[]): Promise<void> {
    // 获取所有聚合歌单
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache('aggregation_playlist', '[]'));
    let tmpSongs: Song[] = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]'))

    // 查找目标歌单索引
    let targetIndex: number = playlists.findIndex((item: Playlist) => item.id === playlist.id);
    if (targetIndex === -1) {
      LogUtil.error(`[${TAG}]`, `歌单[${playlist.name}]不存在`);
    }

    // 初始化统计变量
    let successCount: number = 0;
    let existCount: number = 0;

    // 获取目标歌单
    let targetPlaylist: Playlist = playlists[targetIndex];

    // 初始化歌单歌曲数组（如果不存在）
    if (!tmpSongs) {
      tmpSongs = [];
    }

    // 遍历要添加的所有歌曲
    songs.forEach((song: Song) => {
      // 检查歌曲是否已存在
      const isExist = tmpSongs!.some((s: Song) => s.id === song.id);

      if (isExist) {
        existCount++;
        LogUtil.info(`[${TAG}]`, `[${song.name}]已存在于歌单[${targetPlaylist.name}]`);
      } else {
        // 设置歌曲来源ID
        song.sourceID = song.source?.id;

        // 添加到歌单
        tmpSongs!.push(song);
        successCount++;
      }
    });

    // 更新歌单大小
    targetPlaylist.size = tmpSongs!.length;
    targetPlaylist.cover = songs[songs.length-1].album.cover
    // 更新缓存
    PreferencesCache.setCache(`aggregation_playlist_songs_${playlist.id}`, JSON.stringify(tmpSongs));
    PreferencesCache.setCache('aggregation_playlist', JSON.stringify(playlists));
    AppStorage.setOrCreate('aggregation_playlist', playlists);

    LogUtil.info(`[${TAG}]`, `成功添加${successCount}首歌曲到歌单[${targetPlaylist.name}]`);
    LogUtil.info(`[${TAG}]`, `更新后的歌单：${JSON.stringify(targetPlaylist)}`);
    LogUtil.info(`[${TAG}]`, `添加后的歌曲：${JSON.stringify(tmpSongs)}`)

    ToastUtil.showShort(`${successCount}首添加成功，${existCount}已存在`)
  }

  static convertPlaylistData(): void {
    const convertFlag = PreferencesCache.getCache('aggregation_playlist_converted', '0')
    if(convertFlag === '0') {
      let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache('aggregation_playlist', '[]'));
      playlists.forEach((value: Playlist, index: number) => {
        PreferencesCache.setCache(`aggregation_playlist_songs_${value.id}`, JSON.stringify(value.songs));
        playlists[index].songs = []
      })
      PreferencesCache.setCache('aggregation_playlist', JSON.stringify(playlists))
      PreferencesCache.setCache('aggregation_playlist_converted', '1')
      LogUtil.info(`[${TAG}]`, '歌单数据转换完毕')
    }
  }


  static async deleteSongsOfAggregationPlaylists(sourceId: ID): Promise<void> {
    let playlists: Playlist[] = JSON.parse(PreferencesCache.getCache('aggregation_playlist', '[]'));

    playlists = playlists.map(playlist => {
      // 过滤掉sourceId匹配的歌曲
      let tmpSongs: Song[] = JSON.parse(PreferencesCache.getCache(`aggregation_playlist_songs_${playlist.id}`, '[]'))
      const filteredSongs = tmpSongs.filter(song => song.sourceID !== sourceId);
      PreferencesCache.setCache(`aggregation_playlist_songs_${playlist.id}`, JSON.stringify(filteredSongs));
      playlist.size = filteredSongs.length
      // 返回更新后的歌单（保持其他属性不变）
      return playlist
    });

    LogUtil.info(`[${TAG}]`, `删除后的歌单：${JSON.stringify(playlists)}`)
    PreferencesCache.setCache('aggregation_playlist', JSON.stringify(playlists));
    AppStorage.setOrCreate('aggregation_playlist', playlists);
  }

  static clearPlaylistsCache(strIndex: string): void {
    PreferencesCache.setCache(strIndex, '[]');
    AppStorage.setOrCreate(strIndex, JSON.parse('[]'));
  }

  /**
   * 显示翻译/音译歌词
   * @param value 是否显示
   * @returns 是否显示
   */
  static currentLyricsOffsetTime(value?: number): number {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('current_lyrics_offset_time', `${value}`);
      LogUtil.info(`[${TAG}]`, ` currentLyricsOffsetTime: ${value}`)
    }
    return parseInt(PreferencesCache.getUserPreference('current_lyrics_offset_time', '0'))
  }

  /**
   * 状态栏歌词设置
   */
  static statusBarLyricsSetting(value?: SBLyricsPre): SBLyricsPre {
    if (value !== undefined) {
      PreferencesCache.setUserPreference('status_bar_lyrics_setting',JSON.stringify(value));
    }
    let output  = PreferencesCache.getUserPreference('status_bar_lyrics_setting')
    if (!output){
      const data: SBLyricsPre = {
        open: false,
        lines: 0,
        alignment: 0,
        x: 0,
        y: 0,
        width: display.getDefaultDisplaySync().width/2,
        height: 0,
        transparency: 0,
        fontSize: 0,
        fontColor: '#FF6A6A',
        showShadow: false,
        cornerRadius: 0
      }
      PreferencesCache.setUserPreference('status_bar_lyrics_setting',JSON.stringify(data));
      output = JSON.stringify(data)
      AppStorage.setOrCreate('status_bar_lyrics_setting', JSON.parse(output) as SBLyricsPre)
    }
    return JSON.parse(output) as SBLyricsPre
  }
}