import { avPlayerManager } from "./AVPlayerManager";
import { audio } from "@kit.AudioKit";

const MAX_COUNT = 5;


class StrictTrendDetector {

  private dataWindow: number[] = [];
  private currentCount: number = 0;
  private lastHandledAction: '+' | '-' | null = null;
  private currentSign: '+' | '-' | null = null;

  private flipState: 'up' | 'down' | 'none' = 'none'

  monitorPhoneOrientation(newValue: number) {
    // 将新值添加到窗口数组
    this.dataWindow.push(newValue);

    // 确保窗口大小不超过10个值
    if (this.dataWindow.length > MAX_COUNT) {
      this.dataWindow.shift();
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

  private async adjustVolume(desiredState: string): Promise<void> {
    const player = await avPlayerManager.getAVPlayerInstance()
    if(player.getState() === audio.AudioState.STATE_RUNNING && desiredState === 'paused') {
      avPlayerManager.pause()
      this.flipState = 'down'
    }
    if(player.getState() === audio.AudioState.STATE_RUNNING && desiredState === 'playing' && this.flipState === 'down') {
      avPlayerManager.play()
      this.flipState = 'up'
    }
  }
}

export default new StrictTrendDetector();
