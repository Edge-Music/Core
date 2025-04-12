import { LogUtil, PreferencesUtil } from '@pura/harmony-utils';
import { Song } from '../type/Adapter';
import fs from '@ohos.file.fs';
import { PreferencesCache } from './PreferenceCache';

// 缓存配置接口
interface CacheConfig {
  prefix?: string;
  preferenceName?: string;
}

// 歌曲缓存项
export interface SongCacheItem {
  song: Song;
  path: string;
  createTime: number;
  lastAccessTime: number;
}

// 默认配置
const DEFAULT_CONFIG: CacheConfig = {
  prefix: 'cache_',
  preferenceName: 'song_cache'
};

class CacheManager {
  private static instance: CacheManager = new CacheManager();
  private config: CacheConfig = DEFAULT_CONFIG;
  private initialized: boolean = false;

  private constructor() {
  }

  public static getInstance(): CacheManager {
    return CacheManager.instance;
  }

  // 手动实现配置合并
  private mergeConfig(defaultConfig: CacheConfig, userConfig: CacheConfig): CacheConfig {
    const result: CacheConfig = {
      prefix: userConfig.prefix !== undefined ? userConfig.prefix : defaultConfig.prefix,
      preferenceName: userConfig.preferenceName !== undefined ? userConfig.preferenceName : defaultConfig.preferenceName
    };
    return result;
  }

  // 初始化缓存管理器
  public initialize(config?: CacheConfig): void {
    if (this.initialized) {
      LogUtil.warn('CacheManager already initialized');
      return;
    }

    if (config) {
      this.config = this.mergeConfig(DEFAULT_CONFIG, config);
    }

    this.initialized = true;
  }

  private checkInitialized(): void {
    if (!this.initialized) {
      throw new Error('CacheManager not initialized. Please call initialize() first.');
    }
  }

  private checkOverMaxSize() {
    const maxCount = PreferencesCache.playingCache()
    // 获取所有缓存
    const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
    if (!allData) {
      return;
    }
    const keys = Object.keys(allData).filter(key =>
      key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
    );

    if (keys.length > maxCount) {
      // 按访问时间排序
      keys.sort((a, b) => {
        const itemA: SongCacheItem = JSON.parse(allData[a]);
        const itemB: SongCacheItem = JSON.parse(allData[b]);
        return itemA.lastAccessTime - itemB.lastAccessTime;
      });

      // 删除最早访问的缓存
      for (let i = 0; i < keys.length - maxCount; i++) {
        this.remove(keys[i]);
      }
    }
  }

  private getFullKey(key: string): string {
    return `${this.config.prefix}${key}`;
  }

  /**
   * 保存歌曲到缓存
   * @param key 缓存键
   * @param path 文件缓存路径
   * @param song 歌曲数据
   * @returns 是否成功
   */
  public async set(key: string, path: string, song: Song): Promise<boolean> {
    this.checkInitialized();
    this.checkOverMaxSize();
    try {
      const cacheItem: SongCacheItem = {
        song,
        path,
        createTime: Date.now(),
        lastAccessTime: Date.now(),
      };

      await PreferencesUtil.put(
        this.getFullKey(key),
        JSON.stringify(cacheItem),
        this.config.preferenceName
      );
      return true;
    } catch (error) {
      LogUtil.error(`Failed to cache song: ${error}`);
      return false;
    }
  }

  /**
   * 从缓存获取歌曲
   * @param key 缓存键
   * @returns 歌曲数据或null
   */
  public get(key: string): SongCacheItem | null {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(key);
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);

      if (!data) {
        return null;
      }

      const cacheItem: SongCacheItem = JSON.parse(data);

      // 更新访问时间
      cacheItem.lastAccessTime = Date.now();
      PreferencesUtil.put(fullKey, JSON.stringify(cacheItem), this.config.preferenceName);

      return cacheItem;
    } catch (error) {
      LogUtil.error(`Failed to get cached song: ${error}`);
      return null;
    }
  }

  /**
   * 检查缓存是否存在
   */
  public has(key: string): boolean {
    this.checkInitialized();
    return PreferencesUtil.hasSync(this.getFullKey(key), this.config.preferenceName);
  }

  /**
   * 删除缓存
   */
  public async remove(key: string): Promise<boolean> {
    this.checkInitialized();

    try {
      // 获取缓存项以便删除文件
      const data = PreferencesUtil.getStringSync(key, undefined, this.config.preferenceName);
      if (data) {
        const cacheItem: SongCacheItem = JSON.parse(data);
        // 删除文件
        try {
          await fs.unlink(cacheItem.path);
        } catch (e) {
          LogUtil.warn(`Failed to delete cached file: ${e}`);
        }
      }

      // 删除偏好设置中的条目
      await PreferencesUtil.delete(key, this.config.preferenceName);
      return true;
    } catch (error) {
      LogUtil.error(`Failed to remove cache: ${error}`);
      return false;
    }
  }

  public size(): number {
    this.checkInitialized();
    const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
    if (!allData) {
      return 0;
    }
    return Object.keys(allData).filter(key =>
      key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
    ).length;
  }

  /**
   * 清除所有缓存
   */
  public async clear(): Promise<boolean> {
    this.checkInitialized();

    try {
      const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
      if (!allData) {
        return true;
      }

      const keys = Object.keys(allData).filter(key =>
      key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
      );

      for (const key of keys) {
        const cacheItem: SongCacheItem = JSON.parse(allData[key]);
        // 删除文件
        await fs.unlink(cacheItem.path);
        // 删除缓存数据
        await PreferencesUtil.delete(key, this.config.preferenceName);
      }
      return true;
    } catch (error) {
      return false;
    }
  }
}

const SongCacheManager = CacheManager.getInstance();

export { SongCacheManager };