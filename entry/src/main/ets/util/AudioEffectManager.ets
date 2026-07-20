/**
 * OMSP 3.0 · 音效管理器（单例）
 * 从旧 view/Playing.ets 抽取 EQ / DRC / 声道平衡 的读写与下发逻辑，
 * 统一收口到此处，供 3.0 音效面板（EffectsSheet）与设置页复用。
 * 底层仍复用 avPlayerManager 的 setEqualizer / toggleEqualizer /
 * setChannelVolumes / setDrcEnabled / setDrcParams 能力。
 */
import { avPlayerManager } from './AVPlayerManager'
import { PreferencesCache } from './PreferenceCache'

const BAND_COUNT: number = 10

/** EQ 频段标签（10 段） */
export const EQ_BANDS: string[] = ['31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k']

export interface EqPresetItem {
  id: string
  label: string
  gains: number[]
}

/** EQ 预设（与旧实现保持一致的曲线） */
export const EQ_PRESETS: EqPresetItem[] = [
  { id: 'Default', label: '标准', gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
  { id: 'Pop', label: '流行', gains: [3, 2, 1, 0, -1, -1, 0, 1, 2, 3] },
  { id: 'Rock', label: '摇滚', gains: [5, 4, 3, 1, -1, -1, 1, 3, 4, 4] },
  { id: 'Jazz', label: '爵士', gains: [3, 2, 1, 2, 1, 1, 2, 2, 3, 2] },
  { id: 'Classical', label: '古典', gains: [3, 3, 2, 1, 0, 0, 1, 2, 2, 3] },
  { id: 'Dance', label: '舞曲', gains: [6, 5, 2, 0, 1, 2, 3, 2, 4, 5] },
  { id: 'Ballads', label: '民谣', gains: [2, 1, 1, 2, 3, 2, 1, 2, 3, 3] },
  { id: 'RnB', label: 'R&B', gains: [5, 4, 2, 1, -2, -1, 1, 2, 4, 5] },
  { id: 'Voice', label: '人声', gains: [-2, -2, 0, 1, 2, 4, 4, 3, 1, 0] },
  { id: 'Electronic', label: '电子', gains: [6, 4, 0, -2, -2, 0, 2, 4, 6, 5] }
]

export interface DrcPresetItem {
  id: string
  label: string
  threshold: number
  ratio: number
  attack: number
  release: number
  makeup: number
}

/** DRC 动态范围压缩预设（与旧实现一致的参数） */
export const DRC_PRESETS: DrcPresetItem[] = [
  { id: 'Default', label: '通用标准', threshold: -12, ratio: 2.0, attack: 10, release: 100, makeup: 0 },
  { id: 'Speech', label: '人声对白', threshold: -24, ratio: 4.0, attack: 5, release: 80, makeup: 6 },
  { id: 'Vocal', label: '流行歌唱', threshold: -20, ratio: 3.0, attack: 20, release: 300, makeup: 3 },
  { id: 'Night', label: '深夜模式', threshold: -35, ratio: 10.0, attack: 5, release: 500, makeup: 12 },
  { id: 'Mastering', label: '母带柔化', threshold: -10, ratio: 1.5, attack: 30, release: 400, makeup: 1 },
  { id: 'Punch', label: '打击增强', threshold: -18, ratio: 4.0, attack: 30, release: 50, makeup: 4 },
  { id: 'Broadcast', label: '广播电台', threshold: -20, ratio: 6.0, attack: 15, release: 200, makeup: 6 },
  { id: 'Limiter', label: '安全限幅', threshold: -0.5, ratio: 20.0, attack: 0.1, release: 50, makeup: 0 }
]

class AudioEffectManagerImpl {
  // ========== EQ ==========
  isEqEnabled(): boolean {
    return PreferencesCache.getUserPreference('eq_enabled', '0') === '1'
  }

  getEqGains(): number[] {
    const raw: string = PreferencesCache.getUserPreference('eq_gains_db', '')
    if (!raw) {
      return new Array<number>(BAND_COUNT).fill(0)
    }
    const parts: number[] = raw.split(',').map((v) => {
      const n: number = parseFloat(v)
      return isNaN(n) ? 0 : n
    })
    if (parts.length !== BAND_COUNT) {
      return new Array<number>(BAND_COUNT).fill(0)
    }
    return parts
  }

  getEqPresetId(): string {
    return PreferencesCache.getUserPreference('eq_preset', 'Default')
  }

  setEqEnabled(enabled: boolean): void {
    PreferencesCache.setUserPreference('eq_enabled', enabled ? '1' : '0')
    avPlayerManager.toggleEqualizer(enabled)
    if (enabled) {
      avPlayerManager.setEqualizer(this.getEqGains())
    }
  }

  /** 设置单一频段增益（dB），并即时下发 */
  setEqBand(index: number, db: number): void {
    const gains: number[] = this.getEqGains()
    if (index < 0 || index >= BAND_COUNT) {
      return
    }
    gains[index] = Math.max(-12, Math.min(12, db))
    PreferencesCache.setUserPreference('eq_gains_db', gains.join(','))
    PreferencesCache.setUserPreference('eq_preset', 'Custom')
    if (this.isEqEnabled()) {
      avPlayerManager.setEqualizer(gains)
    }
  }

  applyEqPreset(id: string): void {
    const preset: EqPresetItem | undefined = EQ_PRESETS.find((p) => p.id === id)
    if (!preset) {
      return
    }
    PreferencesCache.setUserPreference('eq_gains_db', preset.gains.join(','))
    PreferencesCache.setUserPreference('eq_preset', id)
    if (!this.isEqEnabled()) {
      PreferencesCache.setUserPreference('eq_enabled', '1')
      avPlayerManager.toggleEqualizer(true)
    }
    avPlayerManager.setEqualizer(preset.gains)
  }

  resetEq(): void {
    const flat: number[] = new Array<number>(BAND_COUNT).fill(0)
    PreferencesCache.setUserPreference('eq_gains_db', flat.join(','))
    PreferencesCache.setUserPreference('eq_preset', 'Default')
    if (this.isEqEnabled()) {
      avPlayerManager.setEqualizer(flat)
    }
  }

  // ========== 声道平衡 ==========
  getVolLeft(): number {
    return parseFloat(PreferencesCache.getUserPreference('vol_left', '1.0'))
  }

  getVolRight(): number {
    return parseFloat(PreferencesCache.getUserPreference('vol_right', '1.0'))
  }

  /** 平衡值 -1（全左）~ 0（居中）~ +1（全右） */
  getBalance(): number {
    const l: number = this.getVolLeft()
    const r: number = this.getVolRight()
    if (l >= r) {
      return -(1 - r)
    }
    return 1 - l
  }

  setBalance(balance: number): void {
    const b: number = Math.max(-1, Math.min(1, balance))
    // 恒定一侧为 1.0，另一侧按比例衰减，保证主观音量不掉
    const left: number = b <= 0 ? 1.0 : 1.0 - b
    const right: number = b >= 0 ? 1.0 : 1.0 + b
    PreferencesCache.setUserPreference('vol_left', left.toString())
    PreferencesCache.setUserPreference('vol_right', right.toString())
    avPlayerManager.setChannelVolumes(left, right)
  }

  resetBalance(): void {
    PreferencesCache.setUserPreference('vol_left', '1.0')
    PreferencesCache.setUserPreference('vol_right', '1.0')
    avPlayerManager.setChannelVolumes(1.0, 1.0)
  }

  // ========== DRC ==========
  isDrcEnabled(): boolean {
    return PreferencesCache.getUserPreference('drc_enabled', '0') === '1'
  }

  getDrcPresetId(): string {
    return PreferencesCache.getUserPreference('drc_preset', 'Default')
  }

  private currentDrcParams(): DrcPresetItem {
    const id: string = this.getDrcPresetId()
    const found: DrcPresetItem | undefined = DRC_PRESETS.find((p) => p.id === id)
    return found ?? DRC_PRESETS[0]
  }

  setDrcEnabled(enabled: boolean): void {
    PreferencesCache.setUserPreference('drc_enabled', enabled ? '1' : '0')
    avPlayerManager.setDrcEnabled(enabled)
    if (enabled) {
      const p: DrcPresetItem = this.currentDrcParams()
      avPlayerManager.setDrcParams(p.threshold, p.ratio, p.attack, p.release, p.makeup)
    }
  }

  applyDrcPreset(id: string): void {
    const preset: DrcPresetItem | undefined = DRC_PRESETS.find((p) => p.id === id)
    if (!preset) {
      return
    }
    PreferencesCache.setUserPreference('drc_preset', id)
    if (!this.isDrcEnabled()) {
      PreferencesCache.setUserPreference('drc_enabled', '1')
      avPlayerManager.setDrcEnabled(true)
    }
    avPlayerManager.setDrcParams(preset.threshold, preset.ratio, preset.attack, preset.release, preset.makeup)
  }

  // ========== 统一下发（换歌 / 初始化时调用） ==========
  applyAll(): void {
    // 声道
    avPlayerManager.setChannelVolumes(this.getVolLeft(), this.getVolRight())
    // EQ
    const eqOn: boolean = this.isEqEnabled()
    avPlayerManager.toggleEqualizer(eqOn)
    if (eqOn) {
      avPlayerManager.setEqualizer(this.getEqGains())
    }
    // DRC
    const drcOn: boolean = this.isDrcEnabled()
    avPlayerManager.setDrcEnabled(drcOn)
    if (drcOn) {
      const p: DrcPresetItem = this.currentDrcParams()
      avPlayerManager.setDrcParams(p.threshold, p.ratio, p.attack, p.release, p.makeup)
    }
  }
}

export const AudioEffectManager = new AudioEffectManagerImpl()
