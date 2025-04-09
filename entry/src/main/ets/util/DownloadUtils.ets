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

    const download = async (): Promise<string | void> => {
      try {
        const filePath = config.fileName;

        // 首先检查文件是否存在，如果存在则直接返回
        if (await fs.access(filePath)) {
          return filePath;
        }

        const downloadTask = await request.downloadFile(this.context!, {
          url: config.url,
          filePath: filePath,
          background: config.background,
        });

        return new Promise((resolve, _reject) => {
          // 监听下载进度
          downloadTask.on('progress', async (receivedSize: number, totalSize: number) => {
            const progress = (receivedSize / totalSize) * 100;
            if (config.onProgress) {
              config.onProgress(progress);
            }
          });

          // 监听下载完成
          downloadTask.on('complete', () => {
            if (config.onComplete) {
              config.onComplete(filePath);
            }
            resolve(filePath);
          });
        });
      } catch (error) {
        LogUtil.error("DownloadUtils ", error.message)
      }
    };

    // 执行下载，支持重试
    while (true) {
      try {
        return await download();
      } catch (error) {
        const err = error as BusinessError;

        if (autoRetry && retryCount < maxRetries) {
          retryCount++;
          console.info(`Download failed, retrying ${retryCount}/${maxRetries}...`);
          continue;
        }

        if (config.onError) {
          config.onError(err);
        }
      }
    }
  }
}

export const DownloadManager = new DownloadUtils()