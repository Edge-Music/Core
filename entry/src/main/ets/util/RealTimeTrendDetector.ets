import { LogUtil } from "@pura/harmony-utils";
import { PlaylistManager } from "./PlaylistManager";

type Trend = '+' | '-';
const TAG = 'RealTimeTrendDetector';

class StrictTrendDetector {
  private readonly windowSize: number;
  private readonly minTrendDiff: number;
  private dataWindow: number[];
  private trendSequence: Trend[]; // 当前正在构建的趋势序列

  constructor(windowSize: number = 5, minTrendDiff: number = 3) {
    this.windowSize = windowSize;
    this.minTrendDiff = minTrendDiff;
    this.dataWindow = [];
    this.trendSequence = [];
  }

  update(newValue: number): void {
    // 更新数据窗口
    this.dataWindow.push(newValue);
    if (this.dataWindow.length > this.windowSize) {
      this.dataWindow.shift();
    }

    // 至少需要2个点才能开始检测
    if (this.dataWindow.length >= 2) {
      this.detectTrendStrictly();
    }
  }

  private detectTrendStrictly(): void {
    // 当前需要检测的趋势方向（交替变化）
    const expectedTrend: Trend | null = this.trendSequence.length % 2 === 1 ? '+' : '-';

    // 尝试在接下来的3个点内找到符合预期的趋势
    const maxLookAhead = Math.min(3, this.dataWindow.length - 1);
    let trendFound: Trend | null = null;

    // 优先检查长区间（3点），再检查短区间（2点）
    for (let points = 3; points >= 2; points--) {
      if (this.dataWindow.length < points) continue;

      const startIdx = this.dataWindow.length - points;
      const diff = this.dataWindow[this.dataWindow.length - 1] - this.dataWindow[startIdx];

      if (Math.abs(diff) >= this.minTrendDiff) {
        const currentTrend = diff > 0 ? '+' : '-';

        // 必须符合交替趋势要求
        if (expectedTrend === null || currentTrend === expectedTrend) {
          trendFound = currentTrend;
          break;
        }
      }
    }

    // 结果处理
    if (trendFound) {
      this.trendSequence.push(trendFound);
      LogUtil.info(TAG, `趋势序列更新: [${this.trendSequence.join('→')}], 数组: ${this.dataWindow.join('→')}`);

      // 完整模式检测
      if (this.trendSequence.length === 3 && this.checkFullPattern()) {
        this.triggerAction();
      }
    } else {
      // 未找到符合要求的趋势，重置检测
      if (this.trendSequence.length > 0) {
        LogUtil.info(TAG, `趋势中断，期待 ${expectedTrend} 但未找到，重置检测`);
        this.trendSequence = []
        this.dataWindow = []
      }
    }
  }

  private checkFullPattern(): boolean {
    const target: Trend[] = ['-', '+', '-'];
    return this.trendSequence.every((val, idx) => val === target[idx]);
  }

  private triggerAction(): void {
    this.playNext();
    LogUtil.info(TAG, `检测到完整波动模式: [${this.trendSequence.join('→')}], 数组: ${this.dataWindow.join('→')}`);
    this.resetDetection();
  }

  private resetDetection(): void {
    this.dataWindow = [];
    this.trendSequence = [];
    // this.coolDownCounter = this.coolDownPeriod;
  }

  private playNext(): void {
    const nextSong = PlaylistManager.playNext();
    if (nextSong) {
      PlaylistManager.playSong(nextSong);
      LogUtil.info(TAG, `切歌成功: ${nextSong.name}`);
    } else {
      LogUtil.info(TAG, '播放列表已到末尾');
    }
  }
}

export default new StrictTrendDetector();
