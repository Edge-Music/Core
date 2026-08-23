import { fileIo as fs } from '@kit.CoreFileKit';
import { LogConfig, LogLevel, levelName } from './LogConfig';

/**
 * 日志文件写入器：追加写、按天滚动、按大小切分、启动时清理。
 * 所有文件 IO 均 try-catch 吞掉，日志模块自身绝不能导致应用崩溃。
 */

interface FileEntry {
  path: string;
  size: number;
  mtime: number;
}

export class LogFileWriter {
  private config: LogConfig;
  private logDir: string;
  private crashDir: string;
  private exportDir: string;

  constructor(context: Context, config: LogConfig) {
    this.config = config;
    this.logDir = context.filesDir + '/logs';
    this.crashDir = this.logDir + '/crash';
    this.exportDir = this.logDir + '/export';
    this.ensureDirs();
  }

  getLogDir(): string {
    return this.logDir;
  }

  getCrashDir(): string {
    return this.crashDir;
  }

  getExportDir(): string {
    return this.exportDir;
  }

  ensureDirs(): void {
    try {
      this.mkdirSafe(this.logDir);
      this.mkdirSafe(this.crashDir);
      this.mkdirSafe(this.exportDir);
    } catch (e) {
      // 忽略，保证不崩溃
    }
  }

  private mkdirSafe(path: string): void {
    if (!fs.accessSync(path)) {
      fs.mkdirSync(path, true);
    }
  }

  /**
   * 追加一条日志。ERROR 级别额外写入当日 error 文件。
   */
  append(level: LogLevel, tag: string, formattedLine: string): void {
    const date = LogFileWriter.dateStr(new Date());
    this.appendToFile('app', date, formattedLine);
    if (level === LogLevel.ERROR) {
      this.appendToFile('error', date, formattedLine);
    }
  }

  private appendToFile(prefix: string, date: string, line: string): void {
    try {
      const maxBytes = this.config.maxFileSizeKB * 1024;
      let path = this.pickSegment(prefix, date, maxBytes, line.length);
      let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      try {
        fs.writeSync(file.fd, line + '\n');
      } finally {
        fs.closeSync(file);
      }
    } catch (e) {
      // 磁盘满等异常：降级跳过文件写
    }
  }

  /**
   * 选择当日第一个未超限的分片：主文件超限后依次切分出 .1/.2...
   */
  private pickSegment(prefix: string, date: string, maxBytes: number, extraLen: number): string {
    for (let index = 0; index < 100; index++) {
      const suffix = index === 0 ? '' : `.${index}`;
      const path = `${this.logDir}/${prefix}_${date}${suffix}.log`;
      try {
        if (!fs.accessSync(path)) {
          return path;
        }
        const stat = fs.statSync(path);
        if (stat.size + extraLen <= maxBytes) {
          return path;
        }
      } catch (e) {
        return path;
      }
    }
    return `${this.logDir}/${prefix}_${date}.log`;
  }

  /**
   * 启动时清理：过期日志、目录总大小超限、crash 保留最近 5 份、导出 zip 超 24h 删除。
   */
  cleanup(): void {
    try {
      this.cleanupRetention();
      this.cleanupTotalSize();
      this.cleanupCrash();
      this.cleanupExport();
    } catch (e) {
      // 忽略
    }
  }

  private cleanupRetention(): void {
    const deadline = Date.now() - this.config.maxRetentionDays * 24 * 3600 * 1000;
    for (const entry of this.listDir(this.logDir)) {
      const name = this.baseName(entry.path);
      if ((name.startsWith('app_') || name.startsWith('error_')) && name.endsWith('.log')) {
        if (entry.mtime < deadline) {
          this.deleteSafe(entry.path);
        }
      }
    }
  }

  private cleanupTotalSize(): void {
    const maxBytes = this.config.maxTotalSizeMB * 1024 * 1024;
    const entries: FileEntry[] = [];
    for (const entry of this.listDir(this.logDir)) {
      const name = this.baseName(entry.path);
      if (name.endsWith('.log')) {
        entries.push(entry);
      }
    }
    entries.sort((a, b) => a.mtime - b.mtime);
    let total = 0;
    for (const entry of entries) {
      total += entry.size;
    }
    for (const entry of entries) {
      if (total <= maxBytes) {
        break;
      }
      this.deleteSafe(entry.path);
      total -= entry.size;
    }
  }

  private cleanupCrash(): void {
    const crashes: FileEntry[] = [];
    for (const entry of this.listDir(this.crashDir)) {
      if (this.baseName(entry.path).startsWith('crash_')) {
        crashes.push(entry);
      }
    }
    crashes.sort((a, b) => b.mtime - a.mtime);
    for (let i = 5; i < crashes.length; i++) {
      this.deleteSafe(crashes[i].path);
    }
  }

  private cleanupExport(): void {
    const deadline = Date.now() - 24 * 3600 * 1000;
    for (const entry of this.listDir(this.exportDir)) {
      if (this.baseName(entry.path).endsWith('.zip') && entry.mtime < deadline) {
        this.deleteSafe(entry.path);
      }
    }
  }

  /**
   * 一键清除：删除整个 logs 目录内容并立即重建目录结构。
   */
  clearAll(): void {
    try {
      for (const entry of this.listDir(this.logDir)) {
        this.deleteSafe(entry.path);
      }
      for (const entry of this.listDir(this.crashDir)) {
        this.deleteSafe(entry.path);
      }
      for (const entry of this.listDir(this.exportDir)) {
        this.deleteSafe(entry.path);
      }
      this.ensureDirs();
    } catch (e) {
      // 忽略
    }
  }

  private listDir(dir: string): FileEntry[] {
    const result: FileEntry[] = [];
    try {
      if (!fs.accessSync(dir)) {
        return result;
      }
      const names = fs.listFileSync(dir);
      for (const name of names) {
        const path = dir + '/' + name;
        try {
          const stat = fs.statSync(path);
          if (!stat.isDirectory()) {
            result.push({ path: path, size: stat.size, mtime: stat.mtime * 1000 });
          }
        } catch (e) {
          // 单个文件失败跳过
        }
      }
    } catch (e) {
      // 目录不存在等
    }
    return result;
  }

  private baseName(path: string): string {
    const idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  private deleteSafe(path: string): void {
    try {
      fs.unlinkSync(path);
    } catch (e) {
      // 忽略
    }
  }

  static dateStr(date: Date): string {
    return LogFileWriter.format(date, false);
  }

  /** 人类可读的日期时间：yyyy-MM-dd HH:mm:ss */
  static dateTimeStr(date: Date): string {
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    const ss = date.getSeconds().toString().padStart(2, '0');
    return `${LogFileWriter.dateStr(date)} ${hh}:${mm}:${ss}`;
  }

  static timestampStr(date: Date): string {
    return LogFileWriter.format(date, true);
  }

  /**
   * 格式化日期：date=true -> yyyyMMdd_HHmmss，否则 yyyy-MM-dd
   */
  static format(date: Date, asTimestamp: boolean): string {
    const y = date.getFullYear().toString();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    if (!asTimestamp) {
      return `${y}-${m}-${d}`;
    }
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    const ss = date.getSeconds().toString().padStart(2, '0');
    return `${y}${m}${d}_${hh}${mm}${ss}`;
  }

  /**
   * 日志行统一格式：[2026-08-22 15:30:12.345] [LEVEL] [tag] message
   */
  static formatLine(level: LogLevel, tag: string, msg: string): string {
    const now = new Date();
    const date = LogFileWriter.dateStr(now);
    const hh = now.getHours().toString().padStart(2, '0');
    const mm = now.getMinutes().toString().padStart(2, '0');
    const ss = now.getSeconds().toString().padStart(2, '0');
    const ms = now.getMilliseconds().toString().padStart(3, '0');
    return `[${date} ${hh}:${mm}:${ss}.${ms}] [${levelName(level)}] [${tag}] ${msg}`;
  }
}
