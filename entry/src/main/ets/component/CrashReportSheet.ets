import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Log, CrashInfo } from '../logger/Logger';

/**
 * 崩溃复盘半模态（bindSheet 内容）。
 * 仅当 hiAppEvent 捕获到真实 APP_CRASH（存在 pending.flag）时才由首页弹出；
 * 强杀/指令结束进程不会产生 crash 记录，不会误弹。
 */
@Component
export struct CrashReportSheet {
  @State crash: CrashInfo | null = null;
  @State showFullStack: boolean = false;
  /** 关闭回调（消费 pending.flag 并收起 Sheet） */
  onClose: () => void = () => {
  };

  aboutToAppear(): void {
    this.loadSummary(0);
  }

  /**
   * 崩溃详情由 hiAppEvent 观察者在启动后异步写入 crash 文件，
   * 首次读取可能尚未就绪，做有限次重试。
   */
  private loadSummary(retried: number): void {
    const summary = Log.getCrashSummary();
    if (summary) {
      this.crash = summary;
      return;
    }
    if (retried < 5) {
      setTimeout(() => {
        this.loadSummary(retried + 1);
      }, 600);
    }
  }

  /** 常见崩溃/异常类型的中文说明，方便阅读 */
  private friendlyType(name: string): string {
    const map = new Map<string, string>([
      ['JsError', 'JS 运行时崩溃'],
      ['NativeCrash', 'Native（C/C++）崩溃'],
      ['Error', '通用运行时错误'],
      ['TypeError', '类型错误（如对空值取属性）'],
      ['ReferenceError', '引用错误（变量未定义）'],
      ['RangeError', '数值越界错误'],
      ['SyntaxError', '语法错误']
    ]);
    const cn = map.get(name);
    return cn ? `${name}（${cn}）` : name;
  }

  build() {
    Column() {
      Text('应用上次异常退出')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 8, bottom: 16 })

      if (this.crash) {
        Scroll() {
          Column({ space: 8 }) {
            this.infoRow('崩溃时间', this.crash.time)
            this.infoRow('异常类型', this.friendlyType(this.crash.name))
            this.infoRow('错误信息', this.crash.message)

            Text(this.showFullStack ? '收起完整堆栈' : '展开完整堆栈')
              .fontColor('#0A59F7')
              .fontSize(14)
              .onClick(() => {
                this.showFullStack = !this.showFullStack;
              })
            if (this.showFullStack) {
              Text(this.crash.stack)
                .fontSize(12)
                .fontColor('#666')
            } else {
              Text(this.crash.stack.split('\n').slice(0, 5).join('\n'))
                .fontSize(12)
                .fontColor('#666')
                .maxLines(5)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        Text('未捕获到崩溃详情')
          .fontSize(15)
          .fontColor('#999')
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
      }

      Button('导出上次运行日志')
        .width('100%')
        .margin({ top: 8 })
        .onClick(() => {
          this.exportWithPicker();
        })

      Button('我知道了')
        .width('100%')
        .margin({ top: 8, bottom: 16 })
        .backgroundColor('#E84026')
        .onClick(() => {
          Log.consumePendingCrash();
          this.onClose();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
  }

  /** 先在沙箱打包 zip，再拉起文件保存控件让用户选择导出位置 */
  private async exportWithPicker(): Promise<void> {
    try {
      const zipPath = await Log.exportLogs();
      const zipName = zipPath.substring(zipPath.lastIndexOf('/') + 1);
      const saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [zipName];
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const docPicker = new picker.DocumentViewPicker(context);
      const uris = await docPicker.save(saveOptions);
      if (uris.length === 0) {
        return;
      }
      await Log.copyExportedZipToUri(zipPath, uris[0]);
      this.getUIContext().getPromptAction().showToast({ message: '日志已导出到所选位置' });
      Log.i(`Logs exported to user location: ${uris[0]}`, 'CrashReport');
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' });
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#888')
        .width(72)
      Text(value)
        .fontSize(14)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
