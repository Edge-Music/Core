import { hilog as sysHilog } from '@kit.PerformanceAnalysisKit';
import { LogConfig, LogLevel } from './LogConfig';
import { LogFileWriter } from './LogFileWriter';
import { CrashHandler, CrashInfo } from './CrashHandler';
import { LogExporter } from './LogExporter';

export { LogConfig, LogLevel } from './LogConfig';
export { CrashInfo } from './CrashHandler';

/** 日志参数类型（对应 hilog 的可变参数） */
export type LogArg = string | number | boolean | object;

/**
 * 日志模块对外唯一入口。
 *
 * 集成方式（拷贝整个 logger/ 目录即可）：
 *   1. UIAbility.onCreate 中调用 Log.init(this.context)；
 *   2. UIAbility.onDestroy 中调用 Log.markCleanExit()；
 *   3. 业务代码中直接使用 Log.d/i/w/e；
 *   4. 可选：Log.init(context, {...}) 覆盖默认配置；导出/清除/崩溃复盘接口见下方静态方法。
 *
 * 替换系统 hilog 的两种方式：
 *   - 简单形式：Log.i('消息') 或 Log.i('消息', 'TAG')；
 *   - hilog 形式（签名一致，支持 %{public}s / %d 等格式串）：
 *     Log.i(0x0000, 'TAG', 'value=%{public}s, count=%d', 'abc', 3)
 *   也可以直接把 `import { hilog } from '@kit.PerformanceAnalysisKit'`
 *   改为 `import { hilog } from '../logger/Logger'`，调用处无需改动。
 *
 * 注意：调用方请勿在日志中打印密码、token、身份证号等敏感信息。
 */
export class Log {
  private static config: LogConfig = new LogConfig();
  private static writer: LogFileWriter | null = null;
  private static crashHandler: CrashHandler | null = null;
  private static exporter: LogExporter | null = null;
  private static lastSessionAbnormal: boolean = false;

  /**
   * 初始化（在 UIAbility.onCreate 中调用）：
   * 判定上次是否异常退出、订阅系统崩溃事件、写入 cleanExit=false、执行启动清理。
   */
  static init(context: Context, config?: Partial<LogConfig>): void {
    try {
      if (config) {
        // ArkTS 受限标准库不允许 Object.assign，逐字段覆盖
        if (config.enableHilog !== undefined) {
          Log.config.enableHilog = config.enableHilog;
        }
        if (config.enableFile !== undefined) {
          Log.config.enableFile = config.enableFile;
        }
        if (config.minLevel !== undefined) {
          Log.config.minLevel = config.minLevel;
        }
        if (config.maxFileSizeKB !== undefined) {
          Log.config.maxFileSizeKB = config.maxFileSizeKB;
        }
        if (config.maxRetentionDays !== undefined) {
          Log.config.maxRetentionDays = config.maxRetentionDays;
        }
        if (config.maxTotalSizeMB !== undefined) {
          Log.config.maxTotalSizeMB = config.maxTotalSizeMB;
        }
        if (config.domain !== undefined) {
          Log.config.domain = config.domain;
        }
      }
      Log.writer = new LogFileWriter(context, Log.config);
      Log.crashHandler = new CrashHandler(context, Log.writer);
      Log.exporter = new LogExporter(Log.writer);
      // 必须在 markSessionStart 之前读取上次的 cleanExit 标记
      Log.lastSessionAbnormal = !Log.crashHandler.wasLastSessionCleanExit();
      Log.crashHandler.registerCrashWatcher();
      Log.crashHandler.markSessionStart();
      Log.writer.cleanup();
      Log.i('Log module initialized', 'AppLog');
    } catch (e) {
      sysHilog.error(0x0000, 'AppLog', 'Log.init failed: %{public}s', String(e));
    }
  }

  /** 上次会话是否异常退出（崩溃或被强杀），用于启动时决定是否进入崩溃复盘页 */
  static wasLastSessionAbnormal(): boolean {
    return Log.lastSessionAbnormal;
  }

  /**
   * 两种调用形式：
   *   Log.d('消息') / Log.d('消息', 'TAG')
   *   Log.d(domain, 'TAG', '格式串 %{public}s %d', arg1, arg2)
   */
  static d(arg1: string | number, arg2?: string, arg3?: string, ...args: LogArg[]): void {
    Log.log(LogLevel.DEBUG, arg1, arg2, arg3, args);
  }

  static i(arg1: string | number, arg2?: string, arg3?: string, ...args: LogArg[]): void {
    Log.log(LogLevel.INFO, arg1, arg2, arg3, args);
  }

  static w(arg1: string | number, arg2?: string, arg3?: string, ...args: LogArg[]): void {
    Log.log(LogLevel.WARN, arg1, arg2, arg3, args);
  }

  static e(arg1: string | number, arg2?: string, arg3?: string, ...args: LogArg[]): void {
    Log.log(LogLevel.ERROR, arg1, arg2, arg3, args);
  }

  private static log(level: LogLevel, arg1: string | number, arg2: string | undefined,
    arg3: string | undefined, args: LogArg[]): void {
    if (typeof arg1 === 'number') {
      // hilog 形式：arg1=domain, arg2=tag, arg3=format
      Log.print(level, Log.formatString(arg3 ?? '', args), arg2 ?? 'AppLog', arg1);
    } else {
      // 简单形式：arg1=msg, arg2=tag
      Log.print(level, arg1, arg2 ?? 'AppLog');
    }
  }

  private static print(level: LogLevel, msg: string, tag: string, domain?: number): void {
    if (level < Log.config.minLevel) {
      return;
    }
    try {
      if (Log.config.enableHilog) {
        Log.printHilog(level, tag, msg, domain ?? Log.config.domain);
      }
      if (Log.config.enableFile && Log.writer) {
        const line = LogFileWriter.formatLine(level, tag, msg);
        Log.writer.append(level, tag, line);
      }
    } catch (e) {
      // 日志模块自身绝不能导致应用崩溃
    }
  }

  private static printHilog(level: LogLevel, tag: string, msg: string, domain: number): void {
    switch (level) {
      case LogLevel.DEBUG:
        sysHilog.debug(domain, tag, '%{public}s', msg);
        break;
      case LogLevel.INFO:
        sysHilog.info(domain, tag, '%{public}s', msg);
        break;
      case LogLevel.WARN:
        sysHilog.warn(domain, tag, '%{public}s', msg);
        break;
      case LogLevel.ERROR:
        sysHilog.error(domain, tag, '%{public}s', msg);
        break;
    }
  }

  /**
   * 支持 hilog 风格的格式串：%{public}s、%{private}s、%s、%d、%i、%f、%j、%o、%%
   * 占位符不足时多余参数追加到末尾。
   */
  static formatString(format: string, args: LogArg[]): string {
    const fmt = format.split('%{public}').join('%').split('%{private}').join('%');
    let result = '';
    let argIndex = 0;
    for (let i = 0; i < fmt.length; i++) {
      const ch = fmt.charAt(i);
      if (ch === '%' && i + 1 < fmt.length) {
        const spec = fmt.charAt(i + 1);
        if (spec === '%') {
          result += '%';
          i++;
          continue;
        }
        if ('sdifjoO'.indexOf(spec) >= 0) {
          const arg = argIndex < args.length ? args[argIndex++] : undefined;
          result += Log.formatArg(spec, arg);
          i++;
          continue;
        }
      }
      result += ch;
    }
    while (argIndex < args.length) {
      result += ' ' + String(args[argIndex++]);
    }
    return result;
  }

  private static formatArg(spec: string, arg: LogArg | undefined): string {
    if (arg === undefined) {
      return 'undefined';
    }
    switch (spec) {
      case 'd':
      case 'i':
        return Math.trunc(Number(arg)).toString();
      case 'f':
        return Number(arg).toString();
      case 'j':
        return JSON.stringify(arg);
      default: // s / o / O
        return String(arg);
    }
  }

  /** 导出全部运行日志，返回 zip 沙箱路径 */
  static exportLogs(): Promise<string> {
    if (!Log.exporter) {
      return Promise.reject(new Error('Log not initialized'));
    }
    return Log.exporter.exportLogs();
  }

  /** 将导出的 zip 拷贝到文件保存控件返回的用户目录 uri（页面层配合 DocumentViewPicker 使用） */
  static copyExportedZipToUri(zipPath: string, targetUri: string): Promise<void> {
    if (!Log.exporter) {
      return Promise.reject(new Error('Log not initialized'));
    }
    return Log.exporter.copyZipToUri(zipPath, targetUri);
  }

  /** 一键清除所有日志（含 error.log 与 crash 记录），不影响后续继续写 */
  static clearAllLogs(): Promise<void> {
    if (!Log.exporter) {
      return Promise.reject(new Error('Log not initialized'));
    }
    return Log.exporter.clearAllLogs();
  }

  /** 是否有未读崩溃记录 */
  static hasPendingCrash(): boolean {
    return Log.crashHandler?.hasPendingCrash() ?? false;
  }

  /** 获取最近一次崩溃摘要 */
  static getCrashSummary(): CrashInfo | null {
    return Log.crashHandler?.getCrashSummary() ?? null;
  }

  /** 复盘页消费后调用，删除 pending.flag */
  static consumePendingCrash(): void {
    Log.crashHandler?.consumePendingCrash();
  }

  /** 正常退出时调用（UIAbility.onDestroy） */
  static markCleanExit(): void {
    Log.crashHandler?.markCleanExit();
  }

  /** 日志目录路径（便于调试查看） */
  static getLogDir(): string {
    return Log.writer?.getLogDir() ?? '';
  }
}

/**
 * 与 @ohos.hilog 同签名的直替对象。
 * 把业务代码里的 `import { hilog } from '@kit.PerformanceAnalysisKit'`
 * 改为 `import { hilog } from '<path>/logger/Logger'`，调用处零改动，
 * 日志即同时输出 hilog 并落盘。
 */
export class HilogReplacement {
  debug(domain: number, tag: string, format: string, ...args: LogArg[]): void {
    Log.d(domain, tag, format, ...args);
  }

  info(domain: number, tag: string, format: string, ...args: LogArg[]): void {
    Log.i(domain, tag, format, ...args);
  }

  warn(domain: number, tag: string, format: string, ...args: LogArg[]): void {
    Log.w(domain, tag, format, ...args);
  }

  error(domain: number, tag: string, format: string, ...args: LogArg[]): void {
    Log.e(domain, tag, format, ...args);
  }

  fatal(domain: number, tag: string, format: string, ...args: LogArg[]): void {
    // 模块没有独立的 FATAL 文件级别，按 ERROR 落盘并输出 hilog
    Log.e(domain, tag, format, ...args);
  }
}

export const hilog: HilogReplacement = new HilogReplacement();

/**
 * 与 @pura/harmony-utils 的 LogUtil 同签名的直替对象。
 * 把业务代码里的 `import { LogUtil } from '@pura/harmony-utils'`
 * 改为 `import { LogUtil } from '<path>/logger/Logger'`，调用处零改动，
 * 日志即同时输出 hilog 并落盘。
 * harmony-utils 形式：LogUtil.info('[TAG]', 'msg', arg1, ...)
 */
export class LogUtilReplacement {
  /** 兼容 harmony-utils 的 init 调用（本模块由 Log.init 统一初始化，此处为空操作） */
  init(_domain?: number, _tag?: string, _debug?: boolean): void {
  }

  debug(...args: LogArg[]): void {
    Log.d(LogUtilReplacement.joinArgs(args), LogUtilReplacement.extractTag(args));
  }

  info(...args: LogArg[]): void {
    Log.i(LogUtilReplacement.joinArgs(args), LogUtilReplacement.extractTag(args));
  }

  warn(...args: LogArg[]): void {
    Log.w(LogUtilReplacement.joinArgs(args), LogUtilReplacement.extractTag(args));
  }

  error(...args: LogArg[]): void {
    Log.e(LogUtilReplacement.joinArgs(args), LogUtilReplacement.extractTag(args));
  }

  /** harmony-utils 惯例：第一个参数若是 `[TAG]` 形式则作为 tag，不参与消息拼接 */
  private static extractTag(args: LogArg[]): string {
    const first = args[0];
    if (typeof first === 'string' && first.startsWith('[') && first.endsWith(']')) {
      return first.substring(1, first.length - 1);
    }
    return 'AppLog';
  }

  private static joinArgs(args: LogArg[]): string {
    let start = 0;
    const first = args[0];
    if (typeof first === 'string' && first.startsWith('[') && first.endsWith(']')) {
      start = 1;
    }
    const parts: string[] = [];
    for (let i = start; i < args.length; i++) {
      const a = args[i];
      parts.push(typeof a === 'string' ? a : JSON.stringify(a));
    }
    return parts.join(' ');
  }
}

export const LogUtil: LogUtilReplacement = new LogUtilReplacement();
