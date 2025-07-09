export type ID = number | string;

export type Bitrate = number;

export interface BaseMeta {
  source: SourceConfig | LocalSourceConfig;
}

export interface Privilege {
  // 是否可播放
  playable: boolean;
  // 原因
  reason?: string;
  // 码率列表
  bitrates?: Bitrate[];
  // 当前用户最高码率
  maxBitrate?: Bitrate;
}

export interface Artist {
  // 歌手ID
  id: ID;
  // 歌手名称
  name: string;
  // 歌手封面
  avatar?: string;

  // 数据来源
  source?: SourceConfig;
}

export interface Album {
  // 专辑ID
  id: ID;
  // 专辑名称
  name: string;
  // 专辑封面
  cover?: string;
  // 歌手
  artists?: Artist[];
  // size
  size?: number;
  // 介绍
  description?: string;

  // 数据来源
  source?: SourceConfig;
}

export interface User {
  // 用户ID
  id: ID;
  // 用户名称
  name: string;
  // 用户头像
  avatar?: string;
  // 用户简介
  description?: string;
}

export enum PlaylistType {
  // 普通歌单
  NORMAL = 'normal',
  // 专辑
  ALBUM = 'album',
  // 歌手
  ARTIST = 'artist',
  // 播控/电台
  DJ = 'dj',
  // 聚合
  AGGREGATION = 'aggregation'
}

export interface PlayListMeta {
  subscribed: boolean; // 是否已订阅
}

export interface Playlist {
  // 歌单ID
  id: ID;
  // 歌单名称
  name?: string;
  // 歌单封面
  cover?: string | Resource;
  // 歌曲数量
  size?: number;
  // 创建者
  creator?: User;
  // 歌曲列表
  songs?: Song[];
  // 歌单类型
  type?: PlaylistType;
  // 描述
  description?: string;
  // 元数据
  meta?: PlayListMeta;

  // 数据来源
  source?: SourceConfig;
}

export interface SongMeta  {
  // 播放链接
  url?: string;
  // 播放码率
  bitrate?: Bitrate;
  // 是否喜欢
  isFavorite?: boolean;
  // 歌词
  lyric?: Lyric;
  // md5
  md5?: string;
  // 尺寸
  size?: number;
}

export interface Song {
  // 歌曲ID
  id: ID;
  // 歌曲名称
  name: string;
  // 歌曲封面
  artists: Artist[];
  // 专辑
  album: Album;
  // 时长
  duration: number;
  // 是否可播放
  privilege: Privilege;
  // 别名
  tns?: string[];
  // 元数据
  meta?: SongMeta;

  // 数据来源
  source?: SourceConfig;
}

export interface LyricLine {
  // 开始时间，从0开始
  start: number;
  // 结束时间，-1表示无限长
  end: number;
  // 歌词
  content: string;
}

export interface Lyric {
  // 正常歌词
  normal?: string;
  // 音译歌词
  transliteration?: string;
  // 翻译歌词
  translation?: string;
}

export enum SearchType {
  // 歌曲
  SONG = 'song',
  // 歌单
  PLAYLIST = 'playlist',
  // 歌手
  ARTIST = 'artist',
  // 专辑
  ALBUM = 'album'
}

export interface SearchResult {
  // 歌曲列表
  songs?: Song[];
  // 歌单列表
  playlists?: Playlist[];
  // 歌手列表
  artists?: Artist[];
  // 专辑列表
  albums?: Album[];
}

export interface Auth {
  token: string; // 可能是Token，也可以是Cookie
  signAt: number;
  user?: User;
}

export interface SourceConfig {
  // 数据源ID
  id: ID;

  // 数据源版本
  version?: string;

  // 数据源名称
  name: string;

  // 数据源地址
  url: string;

  // 数据源描述
  description?: string;

  // 数据源登录凭证
  auth?: Auth;
}

export interface LocalAuth {
  username: string;
  password: string;
}

export interface LocalSourceConfig {
  // 数据源名称
  name: string;

  // 数据源地址
  url: string;

  // 数据源描述
  description?: string;

  // 数据源登录凭证
  auth?: LocalAuth;
}