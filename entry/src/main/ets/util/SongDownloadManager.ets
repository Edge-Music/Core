import { fileUri, picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ID, Song } from '../type/Adapter';
import { PreferencesUtil, ToastUtil } from '@pura/harmony-utils';
import { LogUtil } from '../logger/Logger';
import { DownloadManager } from './DownloadUtils';
import { ContextHelper } from './ContextHelper';
import { getFileExtension } from './String';
import { PreferencesCache } from './PreferenceCache';
import { SourceAdapter } from '../adapter';
import { AudioTag } from '../v3/util/flacTag/AudioTag';
import { buildFlacWithTagAutoCover } from '../v3/util/flacTag/FlacTag';
import { buildId3v2, parseId3v2 } from '../v3/util/flacTag/Id3v2';


// 下载配置接口
interface DownloadConfig {
  prefix?: string;
  preferenceName?: string;
}

// 歌曲下载项
export interface SongDownloadItem {
  song: Song;
  path: string;
  downloadTime: number;
  lastPlayTime: number;
  size: number;
}

// 下载状态类型
export type DownloadStatus = 'waiting' | 'downloading' | 'completed' | 'paused' | 'error' | 'retrying' | 'failed';

// 下载进度接口
export interface DownloadProgress {
  song: Song;
  progress: number;
  status: DownloadStatus;
  retryCount: number;
  queuePosition?: number;
  errorMessage?: string;
}

// 下载任务项（内部使用）
interface DownloadTask {
  song: Song;
  songId: ID;
  retryCount: number;
  isPaused: boolean;
  downloadPromise?: Promise<void>;
}

export interface QueueStats {
  total: number;
  downloading: number;
  waiting: number;
  completed: number;
  paused: number;
  failed: number;
}

// 默认配置
const DEFAULT_CONFIG: DownloadConfig = {
  prefix: 'download_',
  preferenceName: 'song_downloads'
};

/**
 * 歌曲下载管理器 - 单例模式
 * 用于管理歌曲的下载和持久化存储
 */
class SongDownloadManagerClass {
  private static instance: SongDownloadManagerClass = new SongDownloadManagerClass();
  private config: DownloadConfig = DEFAULT_CONFIG;
  private initialized: boolean = false;
  private documentViewPicker: picker.DocumentViewPicker | null = null;
  private baseUri: string = '';

  // 下载队列管理（用于 UI 显示）
  private downloadQueue: Map<ID, DownloadProgress> = new Map();

  // 等待队列（FIFO）
  private waitingQueue: DownloadTask[] = [];

  // 活跃下载任务（正在下载的任务）
  private activeTasks: Map<ID, DownloadTask> = new Map();

  // 已暂停的任务
  private pausedTasks: Set<ID> = new Set();

  // 全局暂停标志
  private globalPaused: boolean = false;

  // 常量配置
  private readonly MAX_CONCURRENT_DOWNLOADS = 3;
  private readonly MAX_RETRY_COUNT = 3;
  private readonly RETRY_DELAY_MS = 2500; // 2.5秒

  /**
   * 更新队列中的任务状态（同步到 AppStorage）
   */
  private updateQueue(songId: ID, progress: DownloadProgress): void {
    if (this.downloadQueue.has(songId)) {
      const existingItem = this.downloadQueue.get(songId);
      if (existingItem) {
        existingItem.progress = progress.progress;
        existingItem.status = progress.status;
        existingItem.retryCount = progress.retryCount;
        existingItem.queuePosition = progress.queuePosition;
        existingItem.errorMessage = progress.errorMessage;
      }
    } else {
      this.downloadQueue.set(songId, progress);
    }
    // 触发 UI 更新
    AppStorage.setOrCreate('download_queue', this.downloadQueue);
  }

  /**
   * 从队列中移除任务
   */
  private removeFromQueue(songId: ID): void {
    this.downloadQueue.delete(songId);
    this.activeTasks.delete(songId);
    this.pausedTasks.delete(songId);
    AppStorage.setOrCreate('download_queue', this.downloadQueue);
  }

  /**
   * 更新等待队列中所有任务的位置
   */
  private updateWaitingQueuePositions(): void {
    this.waitingQueue.forEach((task, index) => {
      const progress = this.downloadQueue.get(task.songId);
      if (progress) {
        progress.queuePosition = index + 1;
      }
    });
    AppStorage.setOrCreate('download_queue', this.downloadQueue);
  }

  /**
   * 处理下一批等待的下载任务（填满并发槽位）
   */
  private processWaitingQueue(): void {
    // 如果全局暂停，不处理
    if (this.globalPaused) {
      return;
    }

    // 计算可以启动的任务数量
    const availableSlots = this.MAX_CONCURRENT_DOWNLOADS - this.activeTasks.size;

    if (availableSlots <= 0 || this.waitingQueue.length === 0) {
      return;
    }

    // 启动多个任务以填满并发槽位
    const tasksToStart = Math.min(availableSlots, this.waitingQueue.length);

    for (let i = 0; i < tasksToStart; i++) {
      const task = this.waitingQueue.shift();
      if (task && !task.isPaused) {
        // 不使用 await，让下载并发执行
        this.startDownloadTask(task);
      }
    }

    // 更新剩余等待任务的位置
    this.updateWaitingQueuePositions();
  }

  /**
   * 启动单个下载任务（不阻塞）
   */
  private startDownloadTask(task: DownloadTask): void {
    const songId = task.songId;
    const song = task.song;

    // 添加到活跃任务
    this.activeTasks.set(songId, task);

    // 更新状态为下载中
    this.updateQueue(songId, {
      song: song,
      progress: 0,
      status: 'downloading',
      retryCount: task.retryCount,
      queuePosition: undefined
    });

    // 启动下载（不等待完成）
    task.downloadPromise = this.executeDownload(task)
      .then(() => {
        // 下载成功
        this.onDownloadComplete(task);
      })
      .catch((error: Error) => {
        // 下载失败
        this.onDownloadError(task, error);
      });
  }

  /**
   * 下载完成回调
   */
  private onDownloadComplete(task: DownloadTask): void {
    const songId = task.songId;
    const song = task.song;

    // 更新状态为已完成
    this.updateQueue(songId, {
      song: song,
      progress: 100,
      status: 'completed',
      retryCount: task.retryCount,
      queuePosition: undefined
    });

    // 从活跃任务中移除
    this.activeTasks.delete(songId);

    LogUtil.info('SongDownloadManager', `Download completed: ${song.name}`);

    // 处理下一批等待的任务
    this.processWaitingQueue();
  }

  /**
   * 下载错误回调
   */
  private onDownloadError(task: DownloadTask, error: Error): void {
    const songId = task.songId;
    const song = task.song;

    LogUtil.error('SongDownloadManager', `Download error: ${song.name}`, error.message);

    // 从活跃任务中移除
    this.activeTasks.delete(songId);

    // 判断是否需要重试
    if (task.retryCount < this.MAX_RETRY_COUNT) {
      // 增加重试计数
      task.retryCount++;

      // 更新状态为重试中
      this.updateQueue(songId, {
        song: song,
        progress: 0,
        status: 'retrying',
        retryCount: task.retryCount,
        queuePosition: undefined,
        errorMessage: error.message
      });

      // 延迟后重试
      setTimeout(() => {
        if (!task.isPaused && !this.globalPaused) {
          LogUtil.info('SongDownloadManager', `Retrying download (${task.retryCount}/${this.MAX_RETRY_COUNT}): ${song.name}`);

          // 如果有空闲槽位，立即重试
          if (this.activeTasks.size < this.MAX_CONCURRENT_DOWNLOADS) {
            this.startDownloadTask(task);
          } else {
            // 否则加入等待队列
            this.waitingQueue.unshift(task); // 优先重试
            this.updateQueue(songId, {
              song: song,
              progress: 0,
              status: 'waiting',
              retryCount: task.retryCount,
              queuePosition: 1,
              errorMessage: error.message
            });
            this.updateWaitingQueuePositions();
          }
        }
      }, this.RETRY_DELAY_MS);
    } else {
      // 超过最大重试次数，标记为永久失败
      this.updateQueue(songId, {
        song: song,
        progress: 0,
        status: 'failed',
        retryCount: task.retryCount,
        queuePosition: undefined,
        errorMessage: error.message
      });

      ToastUtil.showShort(`下载失败: ${song.name}`);

      // 处理下一批等待的任务
      this.processWaitingQueue();
    }
  }

  /**
   * 执行实际的下载操作
   */
  private async executeDownload(task: DownloadTask): Promise<void> {
    const songId = task.songId;
    const song = task.song;

    // 检查是否被暂停
    if (task.isPaused || this.globalPaused) {
      throw new Error('Download paused');
    }

    // 调用原有的下载逻辑
    await this.downloadSongInternal(songId, song, (progress) => {
      // 进度回调
      if (!task.isPaused && !this.globalPaused) {
        this.updateQueue(songId, {
          song: song,
          progress: progress,
          status: 'downloading',
          retryCount: task.retryCount,
          queuePosition: undefined
        });
      }
    });
  }

  private constructor() {
  }

  public static getInstance(): SongDownloadManagerClass {
    return SongDownloadManagerClass.instance;
  }

  /**
   * 暂停所有下载
   */
  public pauseAll(): void {
    this.globalPaused = true;

    // 暂停所有活跃任务
    this.activeTasks.forEach((task, songId) => {
      task.isPaused = true;
      this.pausedTasks.add(songId);

      const progress = this.downloadQueue.get(songId);
      if (progress) {
        this.updateQueue(songId, {
          song: progress.song,
          progress: progress.progress,
          status: 'paused',
          retryCount: progress.retryCount,
          queuePosition: progress.queuePosition,
          errorMessage: progress.errorMessage
        });
      }
    });

    // 暂停所有等待任务
    this.waitingQueue.forEach((task) => {
      task.isPaused = true;
      this.pausedTasks.add(task.songId);

      const progress = this.downloadQueue.get(task.songId);
      if (progress) {
        this.updateQueue(task.songId, {
          song: progress.song,
          progress: progress.progress,
          status: 'paused',
          retryCount: progress.retryCount,
          queuePosition: progress.queuePosition,
          errorMessage: progress.errorMessage
        });
      }
    });

    ToastUtil.showShort('已暂停所有下载');
    LogUtil.info('SongDownloadManager', 'All downloads paused');
  }

  /**
   * 继续所有下载
   */
  public resumeAll(): void {
    this.globalPaused = false;

    // 继续所有暂停的任务
    const pausedTaskIds = Array.from(this.pausedTasks);

    pausedTaskIds.forEach((songId) => {
      // 从活跃任务中查找
      const activeTask = this.activeTasks.get(songId);
      if (activeTask) {
        activeTask.isPaused = false;
        this.pausedTasks.delete(songId);

        const progress = this.downloadQueue.get(songId);
        if (progress) {
          this.updateQueue(songId, {
            song: progress.song,
            progress: progress.progress,
            status: 'downloading',
            retryCount: progress.retryCount,
            queuePosition: progress.queuePosition,
            errorMessage: progress.errorMessage
          });
        }

        // 重新启动下载
        this.startDownloadTask(activeTask);
        return;
      }

      // 从等待队列中查找
      const waitingTask = this.waitingQueue.find(t => t.songId === songId);
      if (waitingTask) {
        waitingTask.isPaused = false;
        this.pausedTasks.delete(songId);

        const progress = this.downloadQueue.get(songId);
        if (progress) {
          this.updateQueue(songId, {
            song: progress.song,
            progress: progress.progress,
            status: 'waiting',
            retryCount: progress.retryCount,
            queuePosition: progress.queuePosition,
            errorMessage: progress.errorMessage
          });
        }
      }
    });

    // 恢复所有 retrying 状态的任务
    this.downloadQueue.forEach((progress, songId) => {
      if (progress.status === 'retrying') {
        // 检查是否已在活跃任务中
        if (!this.activeTasks.has(songId)) {
          // 创建新任务并加入等待队列
          const task: DownloadTask = {
            songId: songId,
            song: progress.song,
            retryCount: 0, // 重置重试次数
            isPaused: false
          };
          this.waitingQueue.push(task);
          this.updateQueue(songId, {
            song: progress.song,
            progress: 0,
            status: 'waiting',
            retryCount: 0,
            queuePosition: this.waitingQueue.length,
            errorMessage: undefined
          });
          LogUtil.info('SongDownloadManager', `Retrying task added to waiting queue: ${progress.song.name}`);
        }
      }
    });

    // 处理等待队列
    this.processWaitingQueue();

    ToastUtil.showShort('已继续所有下载');
    LogUtil.info('SongDownloadManager', 'All downloads resumed');
  }

  /**
   * 暂停单个任务
   */
  public pauseTask(songId: ID): void {
    const activeTask = this.activeTasks.get(songId);
    if (activeTask) {
      activeTask.isPaused = true;
      this.pausedTasks.add(songId);

      const progress = this.downloadQueue.get(songId);
      if (progress) {
        this.updateQueue(songId, {
          song: progress.song,
          progress: progress.progress,
          status: 'paused',
          retryCount: progress.retryCount,
          queuePosition: progress.queuePosition,
          errorMessage: progress.errorMessage
        });
      }

      LogUtil.info('SongDownloadManager', `Task paused: ${songId}`);
      return;
    }

    const waitingTask = this.waitingQueue.find(t => t.songId === songId);
    if (waitingTask) {
      waitingTask.isPaused = true;
      this.pausedTasks.add(songId);

      const progress = this.downloadQueue.get(songId);
      if (progress) {
        this.updateQueue(songId, {
          song: progress.song,
          progress: progress.progress,
          status: 'paused',
          retryCount: progress.retryCount,
          queuePosition: progress.queuePosition,
          errorMessage: progress.errorMessage
        });
      }

      LogUtil.info('SongDownloadManager', `Task paused: ${songId}`);
    }
  }

  /**
   * 继续单个任务
   */
  public resumeTask(songId: ID): void {
    const activeTask = this.activeTasks.get(songId);
    if (activeTask && activeTask.isPaused) {
      activeTask.isPaused = false;
      this.pausedTasks.delete(songId);

      const progress = this.downloadQueue.get(songId);
      if (progress) {
        this.updateQueue(songId, {
          song: progress.song,
          progress: progress.progress,
          status: 'downloading',
          retryCount: progress.retryCount,
          queuePosition: progress.queuePosition,
          errorMessage: progress.errorMessage
        });
      }

      // 重新启动下载
      this.startDownloadTask(activeTask);
      LogUtil.info('SongDownloadManager', `Task resumed: ${songId}`);
      return;
    }

    const waitingTask = this.waitingQueue.find(t => t.songId === songId);
    if (waitingTask && waitingTask.isPaused) {
      waitingTask.isPaused = false;
      this.pausedTasks.delete(songId);

      const progress = this.downloadQueue.get(songId);
      if (progress) {
        this.updateQueue(songId, {
          song: progress.song,
          progress: progress.progress,
          status: 'waiting',
          retryCount: progress.retryCount,
          queuePosition: progress.queuePosition,
          errorMessage: progress.errorMessage
        });
      }

      // 尝试启动
      this.processWaitingQueue();
      LogUtil.info('SongDownloadManager', `Task resumed: ${songId}`);
    }
  }

  /**
   * 清除所有已完成的任务
   */
  public clearCompleted(): void {
    const completedIds: ID[] = [];

    this.downloadQueue.forEach((progress, songId) => {
      if (progress.status === 'completed') {
        completedIds.push(songId);
      }
    });

    completedIds.forEach(songId => {
      this.removeFromQueue(songId);
    });

    if (completedIds.length > 0) {
      ToastUtil.showShort(`已清除 ${completedIds.length} 个已完成任务`);
      LogUtil.info('SongDownloadManager', `Cleared ${completedIds.length} completed tasks`);
    }
  }

  /**
   * 清空所有任务（包括进行中、等待中、已完成、失败的任务）
   */
  public clearAllTasks(): void {
    const totalCount = this.downloadQueue.size;

    if (totalCount === 0) {
      ToastUtil.showShort('队列已为空');
      return;
    }

    // 暂停所有活跃任务
    this.activeTasks.forEach((task) => {
      task.isPaused = true;
    });

    // 清空所有队列和集合
    this.activeTasks.clear();
    this.waitingQueue.length = 0;
    this.pausedTasks.clear();
    this.downloadQueue.clear();
    this.globalPaused = false;

    // 触发 UI 更新
    AppStorage.setOrCreate('download_queue', this.downloadQueue);

    ToastUtil.showShort(`已清空 ${totalCount} 个任务`);
    LogUtil.info('SongDownloadManager', `Cleared all ${totalCount} tasks`);
  }

  /**
   * 暂停所有正在进行和等待中的任务
   */
  public pauseAllTasks(): void {
    let pausedCount = 0;

    // 暂停所有活跃任务
    this.activeTasks.forEach((task, songId) => {
      if (!task.isPaused) {
        task.isPaused = true;
        this.pausedTasks.add(songId);

        const progress = this.downloadQueue.get(songId);
        if (progress) {
          this.updateQueue(songId, {
            song: progress.song,
            progress: progress.progress,
            status: 'paused',
            retryCount: progress.retryCount,
            queuePosition: progress.queuePosition,
            errorMessage: progress.errorMessage
          });
        }
        pausedCount++;
      }
    });

    // 暂停所有等待中的任务
    for (let i = 0; i < this.waitingQueue.length; i++) {
      const task = this.waitingQueue[i];
      if (!task.isPaused) {
        task.isPaused = true;
        this.pausedTasks.add(task.songId);

        const progress = this.downloadQueue.get(task.songId);
        if (progress) {
          this.updateQueue(task.songId, {
            song: progress.song,
            progress: progress.progress,
            status: 'paused',
            retryCount: progress.retryCount,
            queuePosition: progress.queuePosition,
            errorMessage: progress.errorMessage
          });
        }
        pausedCount++;
      }
    }

    this.globalPaused = true;

    if (pausedCount > 0) {
      ToastUtil.showShort(`已暂停 ${pausedCount} 个任务`);
      LogUtil.info('SongDownloadManager', `Paused ${pausedCount} tasks`);
    } else {
      ToastUtil.showShort('没有可暂停的任务');
    }
  }

  /**
   * 恢复所有已暂停的任务
   */
  public resumeAllTasks(): void {
    const pausedCount = this.pausedTasks.size;

    if (pausedCount === 0) {
      ToastUtil.showShort('没有已暂停的任务');
      return;
    }

    this.globalPaused = false;
    this.resumeAll();
  }

  /**
   * 检查是否有正在运行的任务
   */
  public hasRunningTasks(): boolean {
    let hasRunning = false;
    this.downloadQueue.forEach((progress) => {
      if (progress.status === 'downloading' || progress.status === 'retrying' || progress.status === 'waiting') {
        hasRunning = true;
      }
    });
    return hasRunning;
  }

  /**
   * 检查是否有已暂停或重试中的任务（需要恢复按钮）
   */
  public hasPausedTasks(): boolean {
    if (this.pausedTasks.size > 0) {
      return true;
    }
    // 检查是否有 retrying 状态的任务
    let hasRetrying = false;
    this.downloadQueue.forEach((progress) => {
      if (progress.status === 'retrying') {
        hasRetrying = true;
      }
    });
    return hasRetrying;
  }

  /**
   * 获取当前状态统计
   */
  public getQueueStats(): QueueStats {
    let downloading = 0;
    let waiting = 0;
    let completed = 0;
    let paused = 0;
    let failed = 0;

    this.downloadQueue.forEach((progress) => {
      switch (progress.status) {
        case 'downloading':
        case 'retrying':
          downloading++;
          break;
        case 'waiting':
          waiting++;
          break;
        case 'completed':
          completed++;
          break;
        case 'paused':
          paused++;
          break;
        case 'failed':
        case 'error':
          failed++;
          break;
      }
    });

    return {
      total: this.downloadQueue.size,
      downloading,
      waiting,
      completed,
      paused,
      failed
    };
  }

  // 初始化下载管理器
  public init(context: common.Context, config?: DownloadConfig): void {
    if (this.initialized) {
      LogUtil.warn('SongDownloadManager already initialized');
      return;
    }

    if (config) {
      this.config = this.mergeConfig(DEFAULT_CONFIG, config);
    }

    this.documentViewPicker = new picker.DocumentViewPicker(context);
    this.initialized = true;
  }

  // 手动实现配置合并
  private mergeConfig(defaultConfig: DownloadConfig, userConfig: DownloadConfig): DownloadConfig {
    const result: DownloadConfig = {
      prefix: userConfig.prefix !== undefined ? userConfig.prefix : defaultConfig.prefix,
      preferenceName: userConfig.preferenceName !== undefined ? userConfig.preferenceName : defaultConfig.preferenceName
    };
    return result;
  }

  private checkInitialized(): void {
    if (!this.initialized) {
      throw new Error('SongDownloadManager not initialized. Please call init() first.');
    }
  }

  /**
   * 初始化下载目录并获取基础URI
   * @returns Promise<string> 下载目录的URI
   */
  async initDownloadDirectory(): Promise<string> {
    this.checkInitialized();

    if (!this.documentViewPicker) {
      return '';
    }

    if (this.baseUri) {
      return this.baseUri;
    }

    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;

    try {
      const result = await this.documentViewPicker.save(documentSaveOptions);
      this.baseUri = result[0];
      return this.baseUri;
    } catch (err) {
      return '';
    }
  }

  private getFullKey(songId: string): string {
    return `${this.config.prefix}${songId}`;
  }

  /**
   * 下载并保存歌曲（公共接口）
   * @param songId 歌曲ID
   * @param song 歌曲数据
   * @returns Promise<boolean> 是否成功加入队列
   */
  public downloadSong(
    songId: ID,
    song: Song
  ): boolean {
    this.checkInitialized();

    const songIdStr = songId.toString();

    // 检查是否已在队列中
    if (this.downloadQueue.has(songIdStr)) {
      LogUtil.warn('SongDownloadManager', `Song ${song.name} is already in download queue`);
      ToastUtil.showShort('歌曲已在下载队列中');
      return false;
    }

    // 创建下载任务
    const task: DownloadTask = {
      song: song,
      songId: songIdStr,
      retryCount: 0,
      isPaused: false
    };

    // 如果当前活跃下载数小于最大并发数，直接开始下载
    if (this.activeTasks.size < this.MAX_CONCURRENT_DOWNLOADS && !this.globalPaused) {
      this.startDownloadTask(task);
    } else {
      // 否则加入等待队列
      this.waitingQueue.push(task);
      this.updateQueue(songIdStr, {
        song: song,
        progress: 0,
        status: 'waiting',
        retryCount: 0,
        queuePosition: this.waitingQueue.length
      });
      this.updateWaitingQueuePositions();
      ToastUtil.showShort('已加入下载队列');
    }

    return true;
  }

  /**
   * 判断二进制内容是否为原生 FLAC。
   * 不依赖扩展名，避免下载链接没有正确后缀时漏处理。
   */
  private isFlacData(data: Uint8Array): boolean {
    return data.length >= 4 &&
      data[0] === 0x66 && // f
      data[1] === 0x4C && // L
      data[2] === 0x61 && // a
      data[3] === 0x43; // C
  }

  /**
   * 获取 ID3v2 标签总大小。没有 ID3v2 标签时返回 0。
   */
  private getId3v2TotalSize(data: Uint8Array): number {
    if (data.length < 10 ||
      data[0] !== 0x49 || // I
      data[1] !== 0x44 || // D
      data[2] !== 0x33) { // 3
      return 0;
    }

    const tagSize: number = ((data[6] & 0x7F) << 21) |
      ((data[7] & 0x7F) << 14) |
      ((data[8] & 0x7F) << 7) |
      (data[9] & 0x7F);
    return 10 + tagSize;
  }

  /**
   * 校验指定位置是否为真正的 MPEG Layer III（MP3）帧头。
   * 不检查码率、采样率和声道，因为这些不影响 ID3 标签写入。
   */
  private isMp3FrameHeader(data: Uint8Array, offset: number): boolean {
    if (offset < 0 || offset + 4 > data.length) {
      return false;
    }

    // 11 位帧同步：11111111 111xxxxx
    if (data[offset] !== 0xFF || (data[offset + 1] & 0xE0) !== 0xE0) {
      return false;
    }

    const versionBits: number = (data[offset + 1] >> 3) & 0x03;
    const layerBits: number = (data[offset + 1] >> 1) & 0x03;
    const bitrateIndex: number = (data[offset + 2] >> 4) & 0x0F;
    const sampleRateIndex: number = (data[offset + 2] >> 2) & 0x03;

    // versionBits=01 为保留值；layerBits=01 才表示 Layer III，也就是通常所说的 MP3。
    if (versionBits === 0x01 || layerBits !== 0x01) {
      return false;
    }

    // bitrateIndex=15、sampleRateIndex=3 均为非法值。
    if (bitrateIndex === 0x0F || sampleRateIndex === 0x03) {
      return false;
    }

    return true;
  }

  /**
   * 判断二进制内容是否为 MP3。
   * 会跳过 ID3v2 标签后继续校验 MPEG Layer III 帧头，避免把 AAC/MP2 误判为 MP3。
   */
  private isMp3Data(data: Uint8Array): boolean {
    const audioOffset: number = this.getId3v2TotalSize(data);
    if (audioOffset > data.length) {
      return false;
    }
    return this.isMp3FrameHeader(data, audioOffset);
  }

  /**
   * 识别封面格式。
   */
  private detectCoverMime(data: Uint8Array): string {
    // JPEG SOI
    if (data.length >= 3 && data[0] === 0xFF && data[1] === 0xD8 && data[2] === 0xFF) {
      return 'image/jpeg';
    }

    // PNG
    if (data.length >= 8 &&
      data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47 &&
      data[4] === 0x0D && data[5] === 0x0A && data[6] === 0x1A && data[7] === 0x0A) {
      return 'image/png';
    }

    // WebP：RIFF....WEBP
    if (data.length >= 12 &&
      data[0] === 0x52 && data[1] === 0x49 && data[2] === 0x46 && data[3] === 0x46 &&
      data[8] === 0x57 && data[9] === 0x45 && data[10] === 0x42 && data[11] === 0x50) {
      return 'image/webp';
    }

    // HEIC/HEIF：....ftyp + heic/heix/hevc/hevx/mif1/msf1
    if (data.length >= 12 &&
      data[4] === 0x66 && data[5] === 0x74 && data[6] === 0x79 && data[7] === 0x70) {
      const brand: number = (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11];
      if (brand === 0x68656963 || brand === 0x68656966 || brand === 0x68656978 ||
        brand === 0x68657663 || brand === 0x68657678 || brand === 0x6D696631 ||
        brand === 0x6D736631) {
        return 'image/heic';
      }
    }

    return '';
  }

  private uint8ArrayToArrayBuffer(data: Uint8Array): ArrayBuffer {
    const buffer: ArrayBuffer = new ArrayBuffer(data.length);
    const view: Uint8Array = new Uint8Array(buffer);
    view.set(data);
    return buffer;
  }

  /**
   * 将 WebP/HEIC 封面转换为 PNG，避免 APIC 中写入播放器不识别的格式。
   */
  private async convertCoverToPng(coverData: Uint8Array): Promise<Uint8Array | null> {
    let imageSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    let imagePacker: image.ImagePacker | null = null;

    try {
      imageSource = image.createImageSource(this.uint8ArrayToArrayBuffer(coverData));
      if (imageSource === null) {
        return null;
      }

      const decodingOptions: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      pixelMap = await imageSource.createPixelMap(decodingOptions);

      imagePacker = image.createImagePacker();
      if (imagePacker === null) {
        return null;
      }

      const pngData: ArrayBuffer = await imagePacker.packToData(pixelMap, {
        format: 'image/png',
        quality: 100
      });
      return new Uint8Array(pngData);
    } catch (err) {
      return null;
    } finally {
      if (pixelMap !== null) {
        try {
          await pixelMap.release();
        } catch (err) {
        }
      }
      if (imageSource !== null) {
        try {
          await imageSource.release();
        } catch (err) {
        }
      }
      if (imagePacker !== null) {
        try {
          await imagePacker.release();
        } catch (err) {
        }
      }
    }
  }

  private async normalizeCoverForMp3(coverData: Uint8Array): Promise<Uint8Array | null> {
    const mime: string = this.detectCoverMime(coverData);
    if (mime === 'image/jpeg' || mime === 'image/png') {
      return coverData;
    }
    if (mime === 'image/webp' || mime === 'image/heic') {
      return await this.convertCoverToPng(coverData);
    }
    return null;
  }

  /**
   * 合并新旧标签。新字段为空时保留原字段。
   */
  private mergeAudioTag(originalTag: AudioTag, newTag: AudioTag): AudioTag {
    const merged: AudioTag = new AudioTag();
    merged.title = newTag.title.length > 0 ? newTag.title : originalTag.title;
    merged.artist = newTag.artist.length > 0 ? newTag.artist : originalTag.artist;
    merged.album = newTag.album.length > 0 ? newTag.album : originalTag.album;
    merged.lyrics = newTag.lyrics.length > 0 ? newTag.lyrics : originalTag.lyrics;
    merged.cover = newTag.cover !== null && newTag.cover.length > 0 ? newTag.cover : originalTag.cover;
    return merged;
  }

  /**
   * 替换 MP3 文件头部的 ID3v2 标签，保留后面的音频数据。
   */
  private buildMp3WithTag(original: Uint8Array, newTag: AudioTag): Uint8Array | null {
    const parseResult: [AudioTag, number] = parseId3v2(original);
    const oldTag: AudioTag = parseResult[0];
    const oldTagSize: number = parseResult[1];

    if (oldTagSize < 0 || oldTagSize > original.length) {
      return null;
    }

    const finalTag: AudioTag = this.mergeAudioTag(oldTag, newTag);
    const id3Data: Uint8Array = buildId3v2(finalTag);
    const audioData: Uint8Array = original.slice(oldTagSize);

    const result: Uint8Array = new Uint8Array(id3Data.length + audioData.length);
    result.set(id3Data, 0);
    result.set(audioData, id3Data.length);
    return result;
  }

  /**
   * 将 URL 下载到本地文件。
   */
  private async downloadUrlToFile(url: string, targetPath: string): Promise<void> {
    try {
      await fs.unlink(targetPath);
    } catch (e) {
      // 忽略不存在的临时文件
    }

    return new Promise<void>((resolve, reject) => {
      DownloadManager.downloadFile({
        url: url,
        fileName: targetPath,
        background: true,
        autoRetry: false,
        onProgress: () => {
          // 封面下载进度不需要单独显示
        },
        onComplete: () => {
          resolve();
        },
        onError: (err: Error) => {
          reject(err);
        }
      }).catch((err: Error) => {
        reject(err);
      });
    });
  }

  /**
   * 读取二进制文件。
   */
  private async readFileBytes(path: string): Promise<Uint8Array> {
    const stats = await fs.stat(path);
    const file = await fs.open(path, fs.OpenMode.READ_ONLY);

    try {
      const buffer: ArrayBuffer = new ArrayBuffer(stats.size);
      let offset: number = 0;

      while (offset < stats.size) {
        const readLength: number = await fs.read(file.fd, buffer, {
          offset: offset,
          length: stats.size - offset
        });
        if (readLength <= 0) {
          break;
        }
        offset += readLength;
      }

      if (offset !== stats.size) {
        throw new Error(`File read incomplete: ${offset}/${stats.size}`);
      }

      return new Uint8Array(buffer);
    } finally {
      await fs.close(file.fd);
    }
  }

  /**
   * 写入二进制文件。
   */
  private async writeFileBytes(path: string, data: Uint8Array): Promise<void> {
    const file = await fs.open(path,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);

    try {
      const buffer: ArrayBuffer = new ArrayBuffer(data.length);
      const view: Uint8Array = new Uint8Array(buffer);
      view.set(data);

      let offset: number = 0;
      while (offset < data.length) {
        const writeLength: number = await fs.write(file.fd, buffer, {
          offset: offset,
          length: data.length - offset
        });
        if (writeLength <= 0) {
          break;
        }
        offset += writeLength;
      }

      if (offset !== data.length) {
        throw new Error(`File write incomplete: ${offset}/${data.length}`);
      }
    } finally {
      await fs.close(file.fd);
    }
  }

  /**
   * 将标题、歌手、专辑、歌词和封面写入 FLAC 文件。
   * 非 FLAC 文件直接跳过；标签写入失败不影响歌曲下载。
   */
  private async embedFlacMetadataIfNeeded(
    audioFilePath: string,
    song: Song,
    artistNames: string,
    albumName: string,
    lyricContent: string,
    coverUrl: string
  ): Promise<void> {
    const audioData: Uint8Array = await this.readFileBytes(audioFilePath);
    if (!this.isFlacData(audioData)) {
      return;
    }

    const tag: AudioTag = new AudioTag();
    tag.title = song.name || '';
    tag.artist = artistNames || '';
    tag.album = albumName || '';
    tag.lyrics = lyricContent || '';

    let hasNewCover: boolean = false;
    if (coverUrl.length > 0) {
      const coverTempPath: string = `${audioFilePath}.cover`;
      try {
        await this.downloadUrlToFile(coverUrl, coverTempPath);
        const coverData: Uint8Array = await this.readFileBytes(coverTempPath);
        if (coverData.length > 0) {
          tag.cover = coverData;
          hasNewCover = true;
        }
      } catch (coverErr) {
        // 封面下载失败时仍写入其他标签，并保留原 FLAC 封面。
        LogUtil.warn('SongDownloadManager',
          'Failed to download cover: ' + (coverErr as Error).message);
      } finally {
        try {
          await fs.unlink(coverTempPath);
        } catch (e) {
          // 忽略
        }
      }
    }

    // preserveOriginalFields=true：空字段保留原标签；有封面时优先使用新封面。
    let taggedData: Uint8Array | null =
      await buildFlacWithTagAutoCover(audioData, tag, true);

    // 如果 WebP/HEIC 转码失败，则退回为不替换封面，只写入文字标签。
    if (taggedData === null && hasNewCover) {
      const fallbackTag: AudioTag = new AudioTag();
      fallbackTag.title = tag.title;
      fallbackTag.artist = tag.artist;
      fallbackTag.album = tag.album;
      fallbackTag.lyrics = tag.lyrics;
      taggedData = await buildFlacWithTagAutoCover(audioData, fallbackTag, true);
      LogUtil.warn('SongDownloadManager', 'Cover conversion failed, metadata written without replacing cover');
    }

    if (taggedData === null) {
      throw new Error('Failed to build FLAC metadata');
    }

    const taggedTempPath: string = `${audioFilePath}.tagged`;
    try {
      await this.writeFileBytes(taggedTempPath, taggedData);
      await fs.unlink(audioFilePath);
      await fs.moveFile(taggedTempPath, audioFilePath);
    } finally {
      try {
        await fs.unlink(taggedTempPath);
      } catch (e) {
        // 忽略
      }
    }

    LogUtil.info('SongDownloadManager', `FLAC metadata embedded: ${song.name}`);
  }

  /**
   * 将标题、歌手、专辑、歌词和封面写入 MP3 的 ID3v2.3 标签。
   * 非 MP3 文件直接跳过；标签写入失败不影响歌曲下载。
   */
  private async embedMp3MetadataIfNeeded(
    audioFilePath: string,
    song: Song,
    artistNames: string,
    albumName: string,
    lyricContent: string,
    coverUrl: string
  ): Promise<void> {
    const audioData: Uint8Array = await this.readFileBytes(audioFilePath);
    if (!this.isMp3Data(audioData)) {
      return;
    }

    const tag: AudioTag = new AudioTag();
    tag.title = song.name || '';
    tag.artist = artistNames || '';
    tag.album = albumName || '';
    tag.lyrics = lyricContent || '';

    let hasNewCover: boolean = false;
    if (coverUrl.length > 0) {
      const coverTempPath: string = `${audioFilePath}.cover`;
      try {
        await this.downloadUrlToFile(coverUrl, coverTempPath);
        const coverData: Uint8Array = await this.readFileBytes(coverTempPath);
        const normalizedCover: Uint8Array | null = await this.normalizeCoverForMp3(coverData);
        if (normalizedCover !== null && normalizedCover.length > 0) {
          tag.cover = normalizedCover;
          hasNewCover = true;
        } else {
          LogUtil.warn('SongDownloadManager', 'Unsupported or failed cover image, keep original MP3 cover');
        }
      } catch (coverErr) {
        // 封面下载失败时仍写入其他标签，并保留原 MP3 封面。
        LogUtil.warn('SongDownloadManager',
          'Failed to download cover: ' + (coverErr as Error).message);
      } finally {
        try {
          await fs.unlink(coverTempPath);
        } catch (e) {
          // 忽略
        }
      }
    }

    let taggedData: Uint8Array | null = this.buildMp3WithTag(audioData, tag);

    // 如果新封面导致标签构建失败，则退回为只写文字标签并保留原封面。
    if (taggedData === null && hasNewCover) {
      const fallbackTag: AudioTag = new AudioTag();
      fallbackTag.title = tag.title;
      fallbackTag.artist = tag.artist;
      fallbackTag.album = tag.album;
      fallbackTag.lyrics = tag.lyrics;
      taggedData = this.buildMp3WithTag(audioData, fallbackTag);
      LogUtil.warn('SongDownloadManager', 'MP3 cover write failed, metadata written without replacing cover');
    }

    if (taggedData === null) {
      throw new Error('Failed to build MP3 ID3 metadata');
    }

    const taggedTempPath: string = `${audioFilePath}.tagged`;
    try {
      await this.writeFileBytes(taggedTempPath, taggedData);
      await fs.unlink(audioFilePath);
      await fs.moveFile(taggedTempPath, audioFilePath);
    } finally {
      try {
        await fs.unlink(taggedTempPath);
      } catch (e) {
        // 忽略
      }
    }

    LogUtil.info('SongDownloadManager', `MP3 ID3 metadata embedded: ${song.name}`);
  }

  /**
   * 下载并保存歌曲（内部实现）
   * @param songId 歌曲ID
   * @param song 歌曲数据
   * @param onProgress 进度回调
   * @returns Promise<void>
   */
  private async downloadSongInternal(
    songId: ID,
    song: Song,
    onProgress?: (progress: number) => void
  ): Promise<void> {
    this.checkInitialized();

    // 确保下载目录已初始化
    if (!this.baseUri) {
      await this.initDownloadDirectory();
      if (!this.baseUri) {
        throw new Error('Failed to initialize download directory');
      }
    }

    LogUtil.info('SongDownloadManager', 'Base URI:', this.baseUri);

    // 创建音乐目录
    const musicDir = await this.createDirectory('Music');
    const cacheDir = ContextHelper.getContext()?.cacheDir;
    if (!cacheDir) {
      throw new Error('Cache directory not available');
    }

    LogUtil.info('SongDownloadManager', 'Music Directory:', musicDir);
    if (!musicDir) {
      throw new Error('Failed to create music directory');
    }

    // 获取歌曲下载URL
    const br = PreferencesCache.downloadLevel();
    const downloadSong = await SourceAdapter.getSongDetail(song, br);
    const url = downloadSong?.meta?.url || '';
    if (!url) {
      throw new Error('No download link found');
    }

    // 从下载详情中提取封面和专辑信息。
    // coverUrl 对应：downloadSong?.album?.cover
    const coverUrl: string = downloadSong?.album?.cover || '';
    const albumName: string = downloadSong?.album?.name || '';
    const lyricContent: string = song.meta?.lyric?.normal || '';

    const ext = getFileExtension(url);
    // 使用 & 连接歌手名，避免 / 被解析为目录分隔符
    // 同时替换文件名中的非法字符
    const artistNames = song.artists.map(item => item.name).join(" & ");
    const safeArtistNames = this.sanitizeFileName(artistNames);
    const safeSongName = this.sanitizeFileName(song.name);
    const fileName = `${safeArtistNames}-${safeSongName}${ext}`;

    // 完整文件路径
    const uri = musicDir + '/' + fileName;
    const filePath = new fileUri.FileUri(uri).path;
    const tempFilePath = cacheDir + '/' + fileName;

    LogUtil.info('SongDownloadManager', 'Downloading song:', tempFilePath, 'from URL:', url);

    // 先删除临时文件
    try {
      await fs.unlink(tempFilePath);
    } catch (e) {
      // 忽略删除文件错误
    }

    // 使用 Promise 包装下载过程，确保错误能正确传播
    return new Promise<void>((resolve, reject) => {
      DownloadManager.downloadFile({
        url: url,
        fileName: tempFilePath,
        background: true,
        autoRetry: false, // 由 SongDownloadManager 控制重试
        onProgress: (progress) => {
          // 触发进度回调
          if (onProgress) {
            onProgress(progress);
          }
        },
        onComplete: async () => {
          try {
            // 验证临时文件是否存在
            const tempFileExists = await fs.access(tempFilePath);
            if (!tempFileExists) {
              throw new Error('Temporary file does not exist after download');
            }

            // 验证临时文件大小
            const tempStats = await fs.stat(tempFilePath);
            if (tempStats.size === 0) {
              throw new Error('Downloaded file is empty (0 bytes)');
            }

            LogUtil.info('SongDownloadManager', `Temp file verified: ${tempFilePath}, size: ${tempStats.size} bytes`);

            // 根据实际文件内容写入内置标签：FLAC 使用 Vorbis Comment，MP3 使用 ID3v2.3。
            // 封面、歌词、标题、歌手写入失败不影响歌曲下载和移动。
            try {
              await this.embedFlacMetadataIfNeeded(
                tempFilePath,
                song,
                artistNames,
                albumName,
                lyricContent,
                coverUrl
              );
              await this.embedMp3MetadataIfNeeded(
                tempFilePath,
                song,
                artistNames,
                albumName,
                lyricContent,
                coverUrl
              );
            } catch (metadataErr) {
              LogUtil.warn('SongDownloadManager',
                'Failed to embed audio metadata: ' + (metadataErr as Error).message);
            }

            // 移动文件到目标目录
            await fs.moveFile(tempFilePath, filePath);

            // 验证目标文件是否存在
            const fileExists = await fs.access(filePath);
            if (!fileExists) {
              throw new Error('Failed to move file to destination');
            }

            // 验证目标文件大小
            const finalStats = await fs.stat(filePath);
            if (finalStats.size === 0) {
              throw new Error('Destination file is empty after move');
            }

            LogUtil.info('SongDownloadManager', `File moved and verified: ${filePath}, size: ${finalStats.size} bytes`);

            // 保存歌词文件（同时保留外部 .lrc，提升本地播放器兼容性）
            if (lyricContent.length > 0) {
              try {
                const lyricFilePath = filePath.replace(/\.[^/.]+$/, '.lrc');
                LogUtil.info('SongDownloadManager', 'Creating lyric file:', lyricFilePath);
                const lyric = await fs.open(lyricFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
                await fs.write(lyric.fd, lyricContent);
                await fs.close(lyric.fd);
              } catch (lyricErr) {
                // 歌词保存失败不影响主流程
                LogUtil.warn('SongDownloadManager', 'Failed to save lyric file: ' + (lyricErr as Error).message);
              }
            }

            // 创建下载项并保存到偏好设置
            const downloadItem: SongDownloadItem = {
              song,
              path: filePath,
              downloadTime: Date.now(),
              lastPlayTime: Date.now(),
              size: finalStats.size
            };

            await PreferencesUtil.put(
              this.getFullKey(songId.toString()),
              JSON.stringify(downloadItem),
              this.config.preferenceName
            );

            LogUtil.info('SongDownloadManager', 'Download completed successfully:', song.name);
            resolve();
          } catch (err) {
            const error = err as Error;
            LogUtil.error('SongDownloadManager', 'Error in onComplete: ' + error.message);
            // 清理可能存在的不完整文件
            try {
              await fs.unlink(tempFilePath);
            } catch (e) {
              // 忽略
            }
            try {
              await fs.unlink(filePath);
            } catch (e) {
              // 忽略
            }
            reject(new Error('File processing failed: ' + error.message));
          }
        },
        onError: (err: Error) => {
          LogUtil.error('SongDownloadManager', 'Download error: ' + fileName + ' - ' + err.message);
          // 清理可能存在的不完整文件
          fs.unlink(tempFilePath).catch(() => {});
          reject(new Error('Download failed: ' + err.message));
        }
      }).catch((err: Error) => {
        LogUtil.error('SongDownloadManager', 'DownloadManager.downloadFile rejected: ' + err.message);
        reject(err);
      });
    });
  }

  /**
   * 清理文件名中的非法字符
   * @param name 原始文件名
   * @returns 清理后的文件名
   */
  private sanitizeFileName(name: string): string {
    if (!name) {
      return 'unknown';
    }
    // 替换 Windows 和 Unix 文件系统中的非法字符
    // 非法字符: / \ : * ? " < > |
    let result = name;
    result = result.replace(/\//g, '_');
    result = result.replace(/\\/g, '_');
    result = result.replace(/:/g, '_');
    result = result.replace(/\*/g, '_');
    result = result.replace(/\?/g, '_');
    result = result.replace(/"/g, '_');
    result = result.replace(/</g, '_');
    result = result.replace(/>/g, '_');
    result = result.replace(/\|/g, '_');
    // 移除首尾空格
    result = result.trim();
    // 如果结果为空，返回默认值
    if (result.length === 0) {
      return 'unknown';
    }
    return result;
  }

  /**
   * 创建目录
   * @param dirName 目录名称
   * @returns Promise<string> 创建的目录URI
   */
  private async createDirectory(dirName: string): Promise<string> {
    try {
      if (!this.baseUri) {
        await this.initDownloadDirectory();
      }

      const dirPath = new fileUri.FileUri(this.baseUri + '/' + dirName).path;
      // try {
      //   fs.mkdirSync(dirPath);
      // } catch (err) {
      //   // 如果目录已存在，则忽略错误 (17是目录已存在的错误码)
      //   if (err.code !== 17) {
      //     return '';
      //   }
      // }

      // 首先判断目录是否存在
      // try {
      //   fs.accessSync(dirPath);
      // } catch (err) {
      //   // 如果目录不存在，则创建目录
      //   fs.mkdirSync(dirPath);
      // }
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath);
      }

      return this.baseUri + '/' + dirName;
    } catch (err) {
      return '';
    }
  }

  /**
   * 从下载目录获取歌曲
   * @param songId 歌曲ID
   * @returns SongDownloadItem | null 歌曲下载项或null
   */
  public getSong(songId: string): SongDownloadItem | null {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(songId);
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);

      if (!data) {
        return null;
      }

      const downloadItem: SongDownloadItem = JSON.parse(data);

      // 检查文件是否存在
      try {
        fs.accessSync(downloadItem.path);
      } catch (err) {
        // 文件不存在，删除记录
        this.removeSong(songId);
        return null;
      }

      return downloadItem;
    } catch (error) {
      return null;
    }
  }

  /**
   * 更新歌曲的最后播放时间
   * @param songId 歌曲ID
   */
  public updateLastPlayTime(songId: string): void {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(songId);
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);

      if (!data) {
        return;
      }

      const downloadItem: SongDownloadItem = JSON.parse(data);
      downloadItem.lastPlayTime = Date.now();

      PreferencesUtil.put(fullKey, JSON.stringify(downloadItem), this.config.preferenceName);
    } catch (error) {
      // 忽略错误
    }
  }

  /**
   * 检查歌曲是否已下载
   * @param songId 歌曲ID
   * @returns boolean 是否已下载
   */
  public hasSong(songId: string): boolean {
    this.checkInitialized();

    const fullKey = this.getFullKey(songId);
    if (!PreferencesUtil.hasSync(fullKey, this.config.preferenceName)) {
      return false;
    }

    // 进一步检查文件是否存在
    try {
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);
      if (!data) {
        return false;
      }

      const downloadItem: SongDownloadItem = JSON.parse(data);
      LogUtil.info('SongDownloadManager ', 'Checking song existence: ', downloadItem.path);
      const fileExists = fs.accessSync(downloadItem.path);
      if (!fileExists) {
        // 文件不存在，删除记录
        this.removeSong(songId);
        return false;
      }
      return true;
    } catch (error) {
      // 文件不存在，删除记录
      this.removeSong(songId);
      return false;
    }
  }

  /**
   * 删除下载的歌曲
   * @param songId 歌曲ID
   * @returns Promise<boolean> 是否删除成功
   */
  public async removeSong(songId: string): Promise<boolean> {
    this.checkInitialized();

    try {
      const fullKey = this.getFullKey(songId);
      // 获取下载项以便删除文件
      const data = PreferencesUtil.getStringSync(fullKey, undefined, this.config.preferenceName);
      if (data) {
        const downloadItem: SongDownloadItem = JSON.parse(data);
        // 删除文件
        try {
          await fs.unlink(downloadItem.path);
        } catch (e) {
          // 忽略删除文件错误
        }
      }

      // 删除偏好设置中的条目
      await PreferencesUtil.delete(fullKey, this.config.preferenceName);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取下载数量
   * @returns number 下载数量
   */
  public getDownloadCount(): number {
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
   * 获取所有下载的歌曲
   * @returns SongDownloadItem[] 下载的歌曲列表
   */
  public getAllDownloads(): SongDownloadItem[] {
    this.checkInitialized();

    const result: SongDownloadItem[] = [];
    const allData = PreferencesUtil.getAllSync(this.config.preferenceName);
    if (!allData) {
      return result;
    }

    const keys = Object.keys(allData).filter(key =>
    key.startsWith(this.config.prefix || DEFAULT_CONFIG.prefix || '')
    );

    for (const key of keys) {
      try {
        const downloadItem: SongDownloadItem = JSON.parse(allData[key]);
        // 检查文件是否存在
        try {
          fs.accessSync(downloadItem.path);
          result.push(downloadItem);
        } catch (err) {
          // 文件不存在，删除记录
          const songId = key.replace(this.config.prefix || '', '');
          this.removeSong(songId);
        }
      } catch (error) {
        // 忽略解析错误
      }
    }

    return result;
  }

  /**
   * 计算所有下载的总大小
   * @returns number 下载的总大小（字节）
   */
  public getTotalSize(): number {
    this.checkInitialized();

    let totalSize = 0;
    const downloads = this.getAllDownloads();

    for (const item of downloads) {
      totalSize += item.size;
    }

    return totalSize;
  }

  /**
   * 清除所有下载
   * @returns Promise<boolean> 是否清除成功
   */
  public async clearAllDownloads(): Promise<boolean> {
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
        try {
          const downloadItem: SongDownloadItem = JSON.parse(allData[key]);
          // 删除文件
          await fs.unlink(downloadItem.path);
        } catch (error) {
          // 忽略删除文件错误
        }

        // 删除偏好设置中的条目
        await PreferencesUtil.delete(key, this.config.preferenceName);
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取当前下载目录URI
   * @returns string 下载目录URI
   */
  public getBaseUri(): string {
    return this.baseUri;
  }

  /**
   * 批量下载歌曲
   * @param songs 歌曲列表
   * @returns boolean 是否成功加入队列
   */
  public batchDownloadSongs(songs: Song[]): boolean {
    this.checkInitialized();

    // 过滤掉已在队列中的歌曲
    const newSongs = songs.filter(song => !this.downloadQueue.has(song.id.toString()));

    if (newSongs.length === 0) {
      ToastUtil.showShort('所有歌曲已在下载队列中');
      return false;
    }

    // 创建所有下载任务
    const tasks: DownloadTask[] = [];
    for (let i = 0; i < newSongs.length; i++) {
      const song = newSongs[i];
      const task: DownloadTask = {
        song: song,
        songId: song.id.toString(),
        retryCount: 0,
        isPaused: false
      };
      tasks.push(task);
    }

    // 计算可以立即启动的任务数量
    const availableSlots = this.MAX_CONCURRENT_DOWNLOADS - this.activeTasks.size;
    const tasksToStart = Math.min(availableSlots, tasks.length);

    // 启动前几个任务（不使用 await，并发执行）
    for (let i = 0; i < tasksToStart; i++) {
      if (!this.globalPaused) {
        this.startDownloadTask(tasks[i]);
      }
    }

    // 剩余任务加入等待队列
    for (let i = tasksToStart; i < tasks.length; i++) {
      const task = tasks[i];
      this.waitingQueue.push(task);
      this.updateQueue(task.songId, {
        song: task.song,
        progress: 0,
        status: 'waiting',
        retryCount: 0,
        queuePosition: this.waitingQueue.length
      });
    }

    // 更新等待队列位置
    this.updateWaitingQueuePositions();

    ToastUtil.showShort(`已添加 ${newSongs.length} 首歌曲到下载队列`);
    LogUtil.info('SongDownloadManager', `Batch download: ${newSongs.length} songs, ${tasksToStart} started, ${tasks.length - tasksToStart} waiting`);

    return true;
  }
}

// 导出单例实例
export const SongDownloadManager = SongDownloadManagerClass.getInstance();