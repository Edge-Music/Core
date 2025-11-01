import { fileUri, picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ID, Song } from '../type/Adapter';
import { LogUtil, PreferencesUtil, ToastUtil } from '@pura/harmony-utils';
import { DownloadManager } from './DownloadUtils';
import { ContextHelper } from './ContextHelper';
import { getFileExtension } from './String';
import { PreferencesCache } from './PreferenceCache';
import { SourceAdapter } from '../adapter';

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

    const ext = getFileExtension(url);
    const fileName = `${song.artists.map(item => item.name).join("/")}-${song.name}${ext}`;

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

    // 使用下载工具类下载文件
    await DownloadManager.downloadFile({
      url: url,
      fileName: tempFilePath,
      background: true,
      onProgress: (progress) => {
        // 触发进度回调
        if (onProgress) {
          onProgress(progress);
        }
      },
        onComplete: async () => {
          try {
            // 移动文件到目标目录
            await fs.moveFile(tempFilePath, filePath);
            const lyricContent = song.meta?.lyric?.normal;
            if (lyricContent) {
              const lyricFilePath = filePath.replace(/\.[^/.]+$/, '.lrc');
              // 创建歌词文件
              LogUtil.info('SongDownloadManager', 'Creating lyric file:', lyricFilePath);
              const lyric = await fs.open(lyricFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
              await fs.write(lyric.fd, lyricContent);
            }
            LogUtil.info('SongDownloadManager', 'File moved to:', filePath);

            // 创建下载项并保存到偏好设置
            const downloadItem: SongDownloadItem = {
              song,
              path: filePath,
              downloadTime: Date.now(),
              lastPlayTime: Date.now(),
              size: song.meta?.size || 0
            };

            await PreferencesUtil.put(
              this.getFullKey(songId.toString()),
              JSON.stringify(downloadItem),
              this.config.preferenceName
            );

            LogUtil.info('SongDownloadManager', 'Download completed successfully:', song.name);
          } catch (err) {
            const error = err as Error;
            LogUtil.error('SongDownloadManager', 'Error in onComplete: ' + error.message);
            throw new Error(error.message);
          }
        },
        onError: (err: Error) => {
          LogUtil.error('SongDownloadManager', 'Download error: ' + fileName + ' - ' + err.message);
          throw new Error('Download failed: ' + err.message);
        }
      });
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