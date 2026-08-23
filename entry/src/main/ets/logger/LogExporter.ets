import { zlib } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { LogFileWriter } from './LogFileWriter';

/**
 * 导出（zip 打包）与一键清除。
 */
export class LogExporter {
  private writer: LogFileWriter;

  constructor(writer: LogFileWriter) {
    this.writer = writer;
  }

  /**
   * 打包 logs 目录（含所有 .log 与 crash/*.txt）为 export/app_logs_<时间戳>.zip。
   * 返回 zip 沙箱路径，由页面层决定是否拉起分享。
   */
  async exportLogs(): Promise<string> {
    this.writer.ensureDirs();
    const zipName = `app_logs_${LogFileWriter.timestampStr(new Date())}.zip`;
    const zipPath = `${this.writer.getExportDir()}/${zipName}`;
    if (fs.accessSync(zipPath)) {
      fs.unlinkSync(zipPath);
    }
    const options: zlib.Options = {
      level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
      memLevel: zlib.MemLevel.MEM_LEVEL_DEFAULT,
      strategy: zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY
    };
    // compressFile 支持压缩目录（API 11+）
    await zlib.compressFile(this.writer.getLogDir(), zipPath, options);
    return zipPath;
  }

  /** 一键清除所有日志文件并重建目录结构 */
  async clearAllLogs(): Promise<void> {
    this.writer.clearAll();
  }

  /**
   * 将已导出的沙箱 zip 拷贝到文件保存控件（DocumentViewPicker）返回的用户目录 uri。
   * 由页面层拉起保存控件拿到 uri 后调用。
   */
  async copyZipToUri(zipPath: string, targetUri: string): Promise<void> {
    const src = fs.openSync(zipPath, fs.OpenMode.READ_ONLY);
    try {
      const dst = fs.openSync(targetUri,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.copyFileSync(src.fd, dst.fd);
      } finally {
        fs.closeSync(dst);
      }
    } finally {
      fs.closeSync(src);
    }
  }
}
