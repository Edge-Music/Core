import { LogUtil, PreferencesUtil } from '@pura/harmony-utils';
import { Song } from '../type/Adapter';
import { PlayRecord, PlayRecordJSON, TimeSlotStats, ArtistStats } from '../model/PlayRecord';

const TAG = 'PlayRecordManager';
const PREFERENCE_NAME = 'play_records';
const MAX_RECORDS = 1000; // 最多保存1000条记录

/**
 * 播放记录管理器（单例模式）
 */
export class PlayRecordManager {
  private static instance: PlayRecordManager | null = null;
  private records: Map<string, PlayRecord> = new Map();
  private initialized: boolean = false;

  private constructor() {
    // 私有构造函数，防止外部实例化
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): PlayRecordManager {
    if (PlayRecordManager.instance === null) {
      PlayRecordManager.instance = new PlayRecordManager();
    }
    return PlayRecordManager.instance;
  }

  /**
   * 初始化管理器，从持久化存储加载数据
   */
  public async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      const data = await PreferencesUtil.get(PREFERENCE_NAME, '{}');
      const recordsData = JSON.parse(data as string) as Record<string, PlayRecordJSON>;

      this.records.clear();
      const keys = Object.keys(recordsData);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const record = PlayRecord.fromJSON(recordsData[key]);
        this.records.set(key, record);
      }

      LogUtil.info(TAG, 'initialize', `Loaded ${this.records.size} play records`);
      this.initialized = true;
    } catch (error) {
      LogUtil.error(TAG, 'initialize', `Failed to load play records: ${(error as Error).message}`);
      this.records.clear();
      this.initialized = true;
    }
  }

  /**
   * 保存数据到持久化存储
   */
  private async saveToStorage(): Promise<void> {
    try {
      const recordsData: Record<string, PlayRecordJSON> = {};
      this.records.forEach((record, key) => {
        recordsData[key] = record.toJSON();
      });

      await PreferencesUtil.put(PREFERENCE_NAME, JSON.stringify(recordsData));
      LogUtil.info(TAG, 'saveToStorage', `Saved ${this.records.size} play records`);
    } catch (error) {
      LogUtil.error(TAG, 'saveToStorage', `Failed to save play records: ${(error as Error).message}`);
    }
  }

  /**
   * 记录播放事件
   */
  public async recordPlay(song: Song): Promise<void> {
    if (!this.initialized) {
      await this.initialize();
    }

    const key = `${song.id}_${song.source?.id || 'unknown'}`;
    const existingRecord = this.records.get(key);

    if (existingRecord) {
      // 已存在记录，增加播放次数
      existingRecord.incrementPlayCount();
      LogUtil.info(TAG, 'recordPlay', `Updated play count for ${song.name}: ${existingRecord.playCount}`);
    } else {
      // 新记录
      const newRecord = new PlayRecord(song);
      this.records.set(key, newRecord);
      LogUtil.info(TAG, 'recordPlay', `Created new play record for ${song.name}`);

      // 检查记录数量，超过限制则删除最旧的记录
      if (this.records.size > MAX_RECORDS) {
        this.removeOldestRecord();
      }
    }

    // 保存到持久化存储
    await this.saveToStorage();
  }

  /**
   * 删除最旧的记录（按首次播放时间）
   */
  private removeOldestRecord(): void {
    let oldestKey: string | null = null;
    let oldestTime: number = Date.now();

    this.records.forEach((record, key) => {
      if (record.firstPlayTime < oldestTime) {
        oldestTime = record.firstPlayTime;
        oldestKey = key;
      }
    });

    if (oldestKey) {
      this.records.delete(oldestKey);
      LogUtil.info(TAG, 'removeOldestRecord', `Removed oldest record: ${oldestKey}`);
    }
  }

  /**
   * 获取所有播放记录，按播放次数降序排序
   */
  public getAllRecords(): PlayRecord[] {
    const records = Array.from(this.records.values());
    records.sort((a, b) => b.playCount - a.playCount);
    return records;
  }

  /**
   * 获取指定数量的热门歌曲
   */
  public getTopRecords(limit: number): PlayRecord[] {
    const allRecords = this.getAllRecords();
    return allRecords.slice(0, limit);
  }

  /**
   * 获取时段统计数据
   */
  public getTimeSlotStats(): TimeSlotStats {
    const stats: TimeSlotStats = {
      dawn: 0,
      morning: 0,
      afternoon: 0,
      evening: 0
    };

    this.records.forEach((record) => {
      const date = new Date(record.lastPlayTime);
      const hour = date.getHours();

      if (hour >= 0 && hour < 6) {
        stats.dawn += record.playCount;
      } else if (hour >= 6 && hour < 12) {
        stats.morning += record.playCount;
      } else if (hour >= 12 && hour < 18) {
        stats.afternoon += record.playCount;
      } else {
        stats.evening += record.playCount;
      }
    });

    return stats;
  }

  /**
   * 获取最喜欢的歌手统计
   */
  public getTopArtists(limit: number = 5): ArtistStats[] {
    const artistMap: Map<string, number> = new Map();

    // 遍历所有播放记录，统计每个歌手的播放次数
    this.records.forEach((record) => {
      const artists = record.song.artists;
      if (artists && artists.length > 0) {
        for (let i = 0; i < artists.length; i++) {
          const artist = artists[i];
          const artistName = artist.name;
          if (artistName) {
            const currentCount = artistMap.get(artistName) || 0;
            artistMap.set(artistName, currentCount + record.playCount);
          }
        }
      }
    });

    // 转换为数组并排序
    const artistStats: ArtistStats[] = [];
    artistMap.forEach((playCount, artistName) => {
      artistStats.push({
        artistName: artistName,
        playCount: playCount
      });
    });

    // 按播放次数降序排序
    artistStats.sort((a, b) => b.playCount - a.playCount);

    // 返回前 N 个
    return artistStats.slice(0, limit);
  }

  /**
   * 清除所有播放记录
   */
  public async clearAllRecords(): Promise<void> {
    this.records.clear();
    await this.saveToStorage();
    LogUtil.info(TAG, 'clearAllRecords', 'All play records cleared');
  }

  /**
   * 删除指定歌曲的播放记录
   */
  public async deleteRecord(song: Song): Promise<void> {
    const key = `${song.id}_${song.source?.id || 'unknown'}`;
    if (this.records.delete(key)) {
      await this.saveToStorage();
      LogUtil.info(TAG, 'deleteRecord', `Deleted play record for ${song.name}`);
    }
  }

  /**
   * 获取总播放次数
   */
  public getTotalPlayCount(): number {
    let total = 0;
    this.records.forEach((record) => {
      total += record.playCount;
    });
    return total;
  }

  /**
   * 获取记录总数
   */
  public getRecordCount(): number {
    return this.records.size;
  }
}

// 导出单例实例
export const playRecordManager = PlayRecordManager.getInstance();

