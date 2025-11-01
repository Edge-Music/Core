import { Song } from '../type/Adapter';

/**
 * 播放记录数据模型
 */
export class PlayRecord {
  // 歌曲信息
  song: Song;
  // 播放次数
  playCount: number;
  // 最后播放时间戳
  lastPlayTime: number;
  // 首次播放时间戳
  firstPlayTime: number;

  constructor(song: Song, playCount: number = 1, lastPlayTime: number = Date.now(), firstPlayTime: number = Date.now()) {
    this.song = song;
    this.playCount = playCount;
    this.lastPlayTime = lastPlayTime;
    this.firstPlayTime = firstPlayTime;
  }

  /**
   * 增加播放次数
   */
  incrementPlayCount(): void {
    this.playCount++;
    this.lastPlayTime = Date.now();
  }

  /**
   * 获取歌曲唯一标识
   */
  getSongKey(): string {
    return `${this.song.id}_${this.song.source?.id || 'unknown'}`;
  }

  /**
   * 转换为JSON对象（用于持久化）
   */
  toJSON(): PlayRecordJSON {
    return {
      song: this.song,
      playCount: this.playCount,
      lastPlayTime: this.lastPlayTime,
      firstPlayTime: this.firstPlayTime
    };
  }

  /**
   * 从JSON对象创建PlayRecord实例
   */
  static fromJSON(json: PlayRecordJSON): PlayRecord {
    return new PlayRecord(
      json.song,
      json.playCount,
      json.lastPlayTime,
      json.firstPlayTime
    );
  }
}

/**
 * 播放记录JSON格式（用于序列化）
 */
export interface PlayRecordJSON {
  song: Song;
  playCount: number;
  lastPlayTime: number;
  firstPlayTime: number;
}

/**
 * 时段统计数据
 */
export interface TimeSlotStats {
  dawn: number;      // 凌晨 (0-6点)
  morning: number;   // 上午 (6-12点)
  afternoon: number; // 下午 (12-18点)
  evening: number;   // 晚上 (18-24点)
}

/**
 * 歌手统计数据
 */
export interface ArtistStats {
  artistName: string;  // 歌手名称
  playCount: number;   // 该歌手的歌曲被播放的总次数
}

