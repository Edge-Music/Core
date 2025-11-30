import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import request from '@ohos.request';
import { BusinessError } from '@ohos.base';
import { LogUtil } from '@ohos/imageknife';

/**
 * 下载任务配置接口
 */
interface DownloadConfig {
  url: string; // 下载地址
  fileName: string; // 文件名
  autoRetry?: boolean; // 是否自动重试
  maxRetries?: number; // 最大重试次数
  background?: boolean; // 是否后台下载
  onProgress?: (progress: number) => void; // 下载进度回调
  onComplete?: (filePath: string) => void; // 下载完成回调
  onError?: (error: BusinessError) => void; // 错误回调
}

/**
 * 下载工具类
 */
export class DownloadUtils {
  private context: common.UIAbilityContext | undefined;
  private instance: DownloadUtils | null = null;

  public init(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 获取单例实例
   */
  public getInstance() {
    if (this.instance !== null) {
      return this.instance;
    }
    this.instance = new DownloadUtils()
    return this.instance
  }

  /**
   * 下载文件
   * @param config 下载配置
   * @returns Promise<string> 返回文件路径
   */
  public async downloadFile(config: DownloadConfig): Promise<string | void> {
    let retryCount = 0;
    let autoRetry = config.autoRetry !== undefined ? config.autoRetry : true;
    let maxRetries = config.maxRetries !== undefined ? config.maxRetries : 3;

    const download = async (): Promise<string> => {
      const filePath = config.fileName;

      // 首先检查文件是否存在，如果存在则删除文件
      try {
        if (await fs.access(filePath)) {
          await fs.unlink(filePath)
        }
      } catch (e) {
        // 忽略文件不存在的错误
      }

      const downloadTask = await request.downloadFile(this.context!, {
        url: config.url,
        filePath: filePath,
        background: config.background,
      });

      return new Promise((resolve, reject) => {
        let lastReceivedSize = 0;
        let totalFileSize = 0;

        // 监听下载进度
        downloadTask.on('progress', (receivedSize: number, totalSize: number) => {
          lastReceivedSize = receivedSize;
          totalFileSize = totalSize;
          if (totalSize > 0) {
            const progress = (receivedSize / totalSize) * 100;
            if (config.onProgress) {
              config.onProgress(progress);
            }
          }
        });

        // 监听下载完成
        downloadTask.on('complete', async () => {
          try {
            // 验证文件是否存在
            const fileExists = await fs.access(filePath);
            if (!fileExists) {
              const error: BusinessError = {
                code: -1,
                name: 'FileNotFoundError',
                message: 'Downloaded file does not exist'
              };
              reject(error);
              return;
            }

            // 验证文件大小
            const stats = await fs.stat(filePath);
            if (stats.size === 0) {
              const error: BusinessError = {
                code: -2,
                name: 'EmptyFileError',
                message: 'Downloaded file is empty (0 bytes)'
              };
              reject(error);
              return;
            }

            // 如果有总大小信息，验证下载是否完整
            if (totalFileSize > 0 && stats.size < totalFileSize * 0.95) {
              const error: BusinessError = {
                code: -3,
                name: 'IncompleteDownloadError',
                message: `Downloaded file is incomplete: ${stats.size}/${totalFileSize} bytes`
              };
              reject(error);
              return;
            }

            LogUtil.info("DownloadUtils", `Download verified: ${filePath}, size: ${stats.size} bytes`);

            if (config.onComplete) {
              config.onComplete(filePath);
            }
            resolve(filePath);
          } catch (err) {
            const error = err as BusinessError;
            LogUtil.error("DownloadUtils", `File verification failed: ${error.message}`);
            reject(error);
          }
        });

        // 监听下载失败
        downloadTask.on('fail', (err: number) => {
          LogUtil.error("DownloadUtils", `Download failed with error code: ${err}`);
          const error: BusinessError = {
            code: err,
            name: 'DownloadFailedError',
            message: `Download failed with error code: ${err}`
          };
          if (config.onError) {
            config.onError(error);
          }
          reject(error);
        });
      });
    };

    // 执行下载，支持重试
    while (retryCount <= maxRetries) {
      try {
        return await download();
      } catch (error) {
        const err = error as BusinessError;
        LogUtil.error("DownloadUtils", `Download attempt ${retryCount + 1} failed: ${err.message}`);

        if (autoRetry && retryCount < maxRetries) {
          retryCount++;
          LogUtil.info("DownloadUtils", `Retrying download ${retryCount}/${maxRetries}...`);
          // 等待一段时间后重试
          await new Promise<void>((resolve) => setTimeout(resolve, 1000));
          continue;
        }

        if (config.onError) {
          config.onError(err);
        }
        throw new Error(`Download failed after ${retryCount} retries: ${err.message}`);
      }
    }
  }
}

export const DownloadManager = new DownloadUtils()