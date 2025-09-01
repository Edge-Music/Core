import { LogUtil } from "@pura/harmony-utils";
import { avPlayerManager } from "./AVPlayerManager";
import { PlaylistManager } from "./PlaylistManager";
import { PreferencesCache } from "./PreferenceCache";

type Trend = '+' | '-';
const TAG = 'RealTimeTrendDetector';
const WINDOW_SIZE = 5;
const MIN_TREND_DIFF = 3;
const MAX_COUNT = 5;


class StrictTrendDetector {
  private readonly windowSize: number = WINDOW_SIZE;
  private readonly minTrendDiff: number = MIN_TREND_DIFF;
  private dataWindow1: number[] = [];
  private trendSequence: Trend[] = [];

  private dataWindow2: number[] = [];
  private currentCount: number = 0;
  private lastHandledAction: '+' | '-' | null = null;
  private currentSign: '+' | '-' | null = null;

  private flipState: 'up' | 'down' | 'none' = 'none'

  monitorPhoneOrientation(newValue: number) {
    // 将新值添加到窗口数组
    this.dataWindow2.push(newValue);

    // 确保窗口大小不超过10个值
    if (this.dataWindow2.length > MAX_COUNT) {
      this.dataWindow2.shift();
    }

    // 确定当前值的符号
    const currentSign = newValue >= 0 ? '+' : '-';

    // 如果符号改变，重置计数
    if (currentSign !== this.currentSign) {
      this.currentSign = currentSign;
      this.currentCount = 1;
      return;
    }

    // 增加连续计数
    this.currentCount++;

    // 检查是否满足连续10个负值条件
    if (this.currentSign === '-' && this.currentCount >= MAX_COUNT) {
      // 只有当上次操作不是handle(0)时才执行
      if (this.lastHandledAction !== '-') {
        this.adjustVolume('paused');
        this.lastHandledAction = '-';
        // 重置计数以避免重复触发
        this.currentCount = 0;
      }
      return;
    }

    // 检查是否满足连续10个正值条件
    if (this.currentSign === '+' && this.currentCount >= MAX_COUNT) {
      // 只有当上次操作不是handle(100)时才执行
      if (this.lastHandledAction !== '+') {
        this.adjustVolume('playing');
        this.lastHandledAction = '+';
        // 重置计数以避免重复触发
        this.currentCount = 0;
      }
    }
  }

  update(newValue: number): void {
    // 更新数据窗口
    this.dataWindow1.push(newValue);
    if (this.dataWindow1.length > this.windowSize) {
      this.dataWindow1.shift();
    }

    // 至少需要2个点才能开始检测
    if (this.dataWindow1.length >= 2) {
      this.detectTrendStrictly();
    }
  }

  private detectTrendStrictly(): void {
    // 当前需要检测的趋势方向（交替变化）
    const expectedTrend: Trend | null = this.trendSequence.length % 2 === 1 ? '+' : '-';

    // 尝试在接下来的3个点内找到符合预期的趋势
    const maxLookAhead = Math.min(3, this.dataWindow1.length - 1);
    let trendFound: Trend | null = null;

    // 优先检查长区间（3点），再检查短区间（2点）
    for (let points = 3; points >= 2; points--) {
      if (this.dataWindow1.length < points) continue;

      const startIdx = this.dataWindow1.length - points;
      const diff = this.dataWindow1[this.dataWindow1.length - 1] - this.dataWindow1[startIdx];

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
      LogUtil.info(TAG, `趋势序列更新: [${this.trendSequence.join('→')}], 数组: ${this.dataWindow1.join('→')}`);

      // 完整模式检测
      if (this.trendSequence.length === 3 && this.checkFullPattern()) {
        this.triggerAction();
      }
    } else {
      // 未找到符合要求的趋势，重置检测
      if (this.trendSequence.length > 0) {
        LogUtil.info(TAG, `趋势中断，期待 ${expectedTrend} 但未找到，重置检测`);
        this.trendSequence = []
        this.dataWindow1 = []
      }
    }
  }

  private checkFullPattern(): boolean {
    const target: Trend[] = ['-', '+', '-'];
    return this.trendSequence.every((val, idx) => val === target[idx]);
  }

  private triggerAction(): void {
    if(this.flipState === 'up'){
      this.playNext();
    }
    LogUtil.info(TAG, `检测到完整波动模式: [${this.trendSequence.join('→')}], 数组: ${this.dataWindow1.join('→')}`);
    this.resetDetection();
  }

  private resetDetection(): void {
    this.dataWindow1 = [];
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

  private async adjustVolume(desiredState: string): Promise<void> {
    const player = await avPlayerManager.getAVPlayerInstance()
    if(player.state === 'playing' && desiredState === 'paused') {
      avPlayerManager.pause()
      this.flipState = 'down'
    }
    if(player.state != 'playing' && desiredState === 'playing' && this.flipState === 'down') {
      avPlayerManager.play()
      this.flipState = 'up'
    }
  }
}

export default new StrictTrendDetector();
