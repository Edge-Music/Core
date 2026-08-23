import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';
import { hilog, hiAppEvent } from '@kit.PerformanceAnalysisKit';
import { LogFileWriter } from './LogFileWriter';

/**
 * 崩溃复盘支持：cleanExit 标记维护 + hiAppEvent 订阅 APP_CRASH 系统崩溃事件。
 *
 * 设计说明：
 * - 不使用 errorManager 拦截崩溃（注册后进程不会被系统杀死，不是真实崩溃）。
 * - 应用真实崩溃后进程被系统杀掉；下次启动时 hiAppEvent 观察者会收到上次
 *   崩溃的 APP_CRASH 事件（含异常类型、原因、堆栈），据此写入 crash 文件与 pending.flag。
 * - 是否进入复盘页由 preferences 的 cleanExit 标记判定：启动写 false，
 *   UIAbility.onDestroy 正常退出时写 true。
 */

const PREF_NAME = 'app_log_prefs';
const KEY_CLEAN_EXIT = 'cleanExit';
const KEY_VERSION_CODE = 'versionCode';
const PENDING_FLAG = 'pending.flag';

export interface CrashInfo {
  time: string;
  name: string;
  message: string;
  stack: string;
  filePath: string;
}

export class CrashHandler {
  private writer: LogFileWriter;
  private prefs: preferences.Preferences | null = null;

  constructor(context: Context, writer: LogFileWriter) {
    this.writer = writer;
    try {
      this.prefs = preferences.getPreferencesSync(context, { name: PREF_NAME });
    } catch (e) {
      hilog.error(0x0000, 'AppLog', 'CrashHandler prefs init failed: %{public}s', String(e));
    }
  }

  /** 上次会话是否正常退出（必须在 markSessionStart 之前调用） */
  wasLastSessionCleanExit(): boolean {
    try {
      if (!this.prefs) {
        return true;
      }
      const current = this.currentVersionCode();
      if (current > 0) {
        if (!this.prefs.hasSync(KEY_VERSION_CODE)) {
          // 无历史版本记录（本功能首次随包发布，含从旧版本覆盖升级）：
          // 无法区分上次是更新还是崩溃。更新时旧进程被系统直接杀掉（不走 onDestroy），
          // cleanExit 必为 false，此时误报复盘页比漏报体验更差，按正常退出处理并记录版本。
          this.prefs.putSync(KEY_VERSION_CODE, current);
          this.prefs.flush();
          return true;
        }
        const last = this.prefs.getSync(KEY_VERSION_CODE, current) as number;
        if (last !== current) {
          // 版本号变化 = 上次退出是应用更新导致的进程终止，并非崩溃
          this.prefs.putSync(KEY_VERSION_CODE, current);
          this.prefs.flush();
          hilog.info(0x0000, 'AppLog', 'app version changed: %{public}d -> %{public}d, skip crash report page',
            last, current);
          return true;
        }
      }
      return this.prefs.getSync(KEY_CLEAN_EXIT, true) as boolean;
    } catch (e) {
      // 忽略，按正常处理
    }
    return true;
  }

  /** 当前应用 versionCode，失败返回 -1 */
  private currentVersionCode(): number {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.versionCode;
    } catch (e) {
      return -1;
    }
  }

  /** 本次运行开始：cleanExit = false */
  markSessionStart(): void {
    this.putCleanExit(false);
  }

  /** 正常退出：cleanExit = true */
  markCleanExit(): void {
    this.putCleanExit(true);
  }

  private putCleanExit(value: boolean): void {
    try {
      if (this.prefs) {
        this.prefs.putSync(KEY_CLEAN_EXIT, value);
        this.prefs.flush();
      }
    } catch (e) {
      // 忽略
    }
  }

  /** 订阅系统 APP_CRASH 崩溃事件（真实崩溃后，下次启动时回调收到事件） */
  registerCrashWatcher(): void {
    try {
      const watcher: hiAppEvent.Watcher = {
        name: 'appLogCrashWatcher',
        appEventFilters: [
          {
            domain: hiAppEvent.domain.OS,
            names: [hiAppEvent.event.APP_CRASH]
          }
        ],
        onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
          try {
            for (const group of appEventGroups) {
              for (const info of group.appEventInfos) {
                this.handleCrashEvent(info);
              }
            }
          } catch (e) {
            hilog.error(0x0000, 'AppLog', 'handle crash event failed: %{public}s', String(e));
          }
        }
      };
      hiAppEvent.addWatcher(watcher);
    } catch (e) {
      hilog.error(0x0000, 'AppLog', 'CrashHandler register watcher failed: %{public}s', String(e));
    }
  }

  /** 解析 APP_CRASH 事件参数并写 crash 文件 */
  private handleCrashEvent(info: hiAppEvent.AppEventInfo): void {
    const params = info.params as Record<string, Object>;
    const timeMs = Number(params['time'] ?? Date.now());
    const crashType = String(params['crash_type'] ?? 'Crash');
    const bundleVersion = String(params['bundle_version'] ?? '');

    let name = crashType;
    let message = '';
    let stack = '';
    const exception = params['exception'] as Record<string, Object> | undefined;
    if (exception) {
      name = String(exception['name'] ?? name);
      message = String(exception['message'] ?? '');
      const stackRaw = exception['stack'];
      stack = typeof stackRaw === 'string' ? stackRaw : JSON.stringify(stackRaw);
    }

    // 已存在同一时间戳的 crash 文件则跳过，避免同一事件重复落盘
    const date = new Date(timeMs);
    const fileName = `crash_${LogFileWriter.timestampStr(date)}.txt`;
    const path = `${this.writer.getCrashDir()}/${fileName}`;
    try {
      if (fs.accessSync(path)) {
        return;
      }
    } catch (e) {
      // 忽略
    }

    const content = 'time: ' + LogFileWriter.dateTimeStr(date) + '\n' +
      'name: ' + name + '\n' +
      'message: ' + message + '\n' +
      'device: ' + deviceInfo.productModel + ' / ' + deviceInfo.osFullName +
      (bundleVersion ? ' / app ' + bundleVersion : '') + '\n' +
      'stack:\n' + stack + '\n';
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      try {
        fs.writeSync(file.fd, content);
      } finally {
        fs.closeSync(file);
      }
      // 创建 pending.flag，表示有未读崩溃
      const flag = fs.openSync(`${this.writer.getCrashDir()}/${PENDING_FLAG}`,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
      fs.closeSync(flag);
    } catch (e) {
      hilog.error(0x0000, 'AppLog', 'writeCrashFile failed: %{public}s', String(e));
    }
  }

  /** 是否有未读崩溃 */
  hasPendingCrash(): boolean {
    try {
      return fs.accessSync(`${this.writer.getCrashDir()}/${PENDING_FLAG}`);
    } catch (e) {
      return false;
    }
  }

  /** 复盘页消费后删除 pending.flag */
  consumePendingCrash(): void {
    try {
      fs.unlinkSync(`${this.writer.getCrashDir()}/${PENDING_FLAG}`);
    } catch (e) {
      // 忽略
    }
  }

  /** 读取最近一次崩溃文件摘要 */
  getCrashSummary(): CrashInfo | null {
    try {
      const dir = this.writer.getCrashDir();
      if (!fs.accessSync(dir)) {
        return null;
      }
      const names = fs.listFileSync(dir)
        .filter((n: string) => n.startsWith('crash_') && n.endsWith('.txt'))
        .sort();
      if (names.length === 0) {
        return null;
      }
      const path = `${dir}/${names[names.length - 1]}`;
      const content = fs.readTextSync(path);
      const info: CrashInfo = { time: '', name: '', message: '', stack: '', filePath: path };
      const lines = content.split('\n');
      let stackLines: string[] = [];
      let inStack = false;
      for (const line of lines) {
        if (inStack) {
          stackLines.push(line);
        } else if (line.startsWith('time: ')) {
          info.time = line.substring(6);
        } else if (line.startsWith('name: ')) {
          info.name = line.substring(6);
        } else if (line.startsWith('message: ')) {
          info.message = line.substring(9);
        } else if (line === 'stack:') {
          inStack = true;
        }
      }
      info.stack = stackLines.join('\n').trim();
      return info;
    } catch (e) {
      return null;
    }
  }
}
