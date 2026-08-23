/**
 * 日志模块配置（所有字段均有默认值，可通过 Log.init 的 Partial<LogConfig> 覆盖）
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

export class LogConfig {
  /** 是否同步输出 hilog */
  enableHilog: boolean = true;
  /** 是否落盘记录 */
  enableFile: boolean = true;
  /** 最低记录级别 */
  minLevel: LogLevel = LogLevel.DEBUG;
  /** 单个日志文件大小上限（KB），超过则切分 */
  maxFileSizeKB: number = 1024;
  /** 普通运行日志保留天数 */
  maxRetentionDays: number = 7;
  /** 日志目录总大小上限（MB），超出按最旧优先删除 */
  maxTotalSizeMB: number = 20;
  /** hilog 业务领域 */
  domain: number = 0x0000;
}

export function levelName(level: LogLevel): string {
  switch (level) {
    case LogLevel.DEBUG:
      return 'DEBUG';
    case LogLevel.INFO:
      return 'INFO';
    case LogLevel.WARN:
      return 'WARN';
    case LogLevel.ERROR:
      return 'ERROR';
    default:
      return 'UNKNOWN';
  }
}
