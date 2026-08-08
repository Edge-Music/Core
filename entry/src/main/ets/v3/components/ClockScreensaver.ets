/**
 * 时间屏保（播放页「更多」菜单开启）
 *  - 分栏（宽屏/横屏）：复用 Playing4Landscape 主题三的横屏时钟样式——
 *    大字 TextClock（yxs 时钟字体，偏好与横屏页共享 Font4Theme3/FontSize4Theme3）
 *    + 日期 + 顶部歌曲胶囊（点击展开歌词/进度/播控，仿灵动岛）。
 *  - 滑动分页（竖屏）：锁屏样式——大时钟 + 日期 + 玻璃播放卡
 *    （封面/歌名/当前歌词/进度/播控）。
 * 退出逻辑：下滑退出（带跟手位移/回弹）；长按时钟弹出字体/字号设置面板。
 * 屏保期间保持屏幕常亮（setWindowKeepScreenOn），退出后恢复。
 */
import { avPlayerManager } from '../../util/AVPlayerManager'
import { PlaylistManager, PlayMode } from '../../util/PlaylistManager'
import { Song } from '../../type/Adapter'
import { cover } from '../../util/AdapterHelper'
import { SourceAdapter } from '../../adapter'
import { EventHelper } from '../../util/EventHelper'
import { PreferencesCache } from '../../util/PreferenceCache'
import { LyricsLine } from '../../util/LyricsManager'
import { audio } from '@kit.AudioKit'
import { window } from '@kit.ArkUI'
import { text } from '@kit.ArkGraphics2D'
import { ToastUtil } from '@pura/harmony-utils'
import { AmbientBackground } from './AmbientBackground'
import { V3Color, V3Theme } from '../theme/Tokens'

@Component
export struct ClockScreensaver {
  // true = 滑动分页（竖屏）布局；false = 分栏横屏时钟布局
  @Prop isSwiper: boolean
  onExit?: () => void

  @StorageProp('current_playing_song') song: Song | null = null
  @StorageProp('current_playing_playMode') playMode: number = PlayMode.LOOP
  @StorageProp('current_parsed_lyrics') parsedLyrics: LyricsLine[] = []
  @StorageProp('current_lyrics_index') lyricIndex: number = 0
  @StorageProp('v3_theme_mode') mode: string = 'dark'
  @StorageProp('v3_ambient_glow') glow: string = V3Color.ACCENT_GLOW
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0

  @State currentTimeMs: number = 0
  @State durationMs: number = 0
  @State isPlaying: boolean = false
  // 进度拖动中：期间冻结定时器回写，避免滑块被拉回
  @State seeking: boolean = false
  @State fav: boolean = false
  @State playScale: number = 1
  // 横屏歌曲胶囊展开态
  @State capsuleExpanded: boolean = false
  // 与横屏播放页主题三共享的时钟字体/字号偏好
  @State clockFont: string = '-1'
  @State clockFontSize: number = 100
  // 时钟设置面板（长按时钟弹出）
  @State showClockSetting: boolean = false
  // 下滑退出的跟手位移
  @State exitDy: number = 0
  // 防烧屏压暗：长时间未操作自动压暗（设置页可关，默认开启）
  @State saverDim: boolean = false
  @State dimEnabled: boolean = true
  // 可选时钟字体（'-1' = 系统默认，其余对应 yxs0~yxs8，同横屏播放页主题三）
  private fontIds: string[] = ['-1', '0', '1', '2', '3', '4', '5', '6', '7', '8']
  // 未操作压暗时长（3 分钟）
  private static readonly DIM_TIMEOUT: number = 180000
  private dimTimer: number = -1

  private timer: number = -1
  private player = avPlayerManager
  private keepScreenOnWindow: window.Window | null = null
  // 持有回调引用才能在退出屏保时摘除，否则每次进出屏保都往播放器回调数组里累加一份
  private handlePlay: () => void = () => {
    this.isPlaying = true
  }
  private handlePause: () => void = () => {
    this.isPlaying = false
  }

  aboutToAppear(): void {
    // 加载横屏时钟字体（与 Playing4Landscape 同一套 yxs 字体族）
    try {
      const fontCollection = text.FontCollection.getGlobalInstance()
      fontCollection.loadFontSync('yxs0', $rawfile('hwbsj.ttf'))
      fontCollection.loadFontSync('yxs1', $rawfile('HarmonyClock_01.ttf'))
      fontCollection.loadFontSync('yxs2', $rawfile('HarmonyClock_02.ttf'))
      fontCollection.loadFontSync('yxs3', $rawfile('HarmonyClock_03.ttf'))
      fontCollection.loadFontSync('yxs4', $rawfile('HarmonyClock_04.ttf'))
      fontCollection.loadFontSync('yxs5', $rawfile('HarmonyClock_05.ttf'))
      fontCollection.loadFontSync('yxs6', $rawfile('HarmonyClock_06.ttf'))
      fontCollection.loadFontSync('yxs7', $rawfile('HarmonyClock_07.ttf'))
      fontCollection.loadFontSync('yxs8', $rawfile('HarmonyClock_08.ttf'))
    } catch (e) {
      // 字体已加载或加载失败时静默降级为系统字体
    }
    this.clockFont = PreferencesCache.getUserPreference('Font4Theme3', '-1')
    this.clockFontSize = Number(PreferencesCache.getUserPreference('FontSize4Theme3', '100'))
    this.fav = this.song?.meta?.isFavorite ?? false
    // 防烧屏压暗开关（设置页「通用」，默认开启）
    this.dimEnabled = PreferencesCache.getUserPreference('v3_saver_dim', '1') === '1'
    this.resetDimTimer()

    this.player.getAVPlayerInstance().then((p) => {
      this.currentTimeMs = p.getCurrentPosition()
      this.durationMs = p.getDurationMs()
      this.isPlaying = p.getState() === audio.AudioState.STATE_RUNNING
    })
    this.player.addListener('onPlay', this.handlePlay)
    this.player.addListener('onPause', this.handlePause)
    this.timer = setInterval(async () => {
      const p = await this.player.getAVPlayerInstance()
      this.durationMs = p.getDurationMs()
      // 拖动进度中不要回写，否则每 500ms 把滑块拉回播放器的旧位置，表现为拖不动
      if (!this.seeking) {
        this.currentTimeMs = p.getCurrentPosition()
      }
    }, 500)

    // 屏保期间保持屏幕常亮
    try {
      const stage = AppStorage.get('windowStage') as window.WindowStage
      stage.getMainWindow().then((win: window.Window) => {
        this.keepScreenOnWindow = win
        win.setWindowKeepScreenOn(true)
      })
    } catch (e) {
      // 无法设置常亮时不影响屏保主功能
    }

    ToastUtil.showShort('下滑退出屏保，长按时钟设置字体')
  }

  aboutToDisappear(): void {
    this.player.removeListener('onPlay', this.handlePlay)
    this.player.removeListener('onPause', this.handlePause)
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
    if (this.dimTimer !== -1) {
      clearTimeout(this.dimTimer)
      this.dimTimer = -1
    }
    try {
      this.keepScreenOnWindow?.setWindowKeepScreenOn(false)
    } catch (e) {
      // ignore
    }
  }

  // 防烧屏：重置未操作计时，到时自动压暗
  private resetDimTimer(): void {
    if (this.dimTimer !== -1) {
      clearTimeout(this.dimTimer)
      this.dimTimer = -1
    }
    if (!this.dimEnabled) {
      return
    }
    this.dimTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 800, curve: Curve.EaseInOut }, () => {
        this.saverDim = true
      })
    }, ClockScreensaver.DIM_TIMEOUT)
  }

  // 任意操作点亮并重新计时三分钟
  private relight(): void {
    this.resetDimTimer()
    if (this.saverDim) {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.saverDim = false
      })
    }
  }

  private artistNames(): string {
    return this.song?.artists?.map((a) => a.name).join(' / ') ?? '未知艺术家'
  }

  private currentLyric(): string {
    if (this.parsedLyrics && this.lyricIndex >= 0 && this.lyricIndex < this.parsedLyrics.length) {
      return this.parsedLyrics[this.lyricIndex].text ?? ''
    }
    return ''
  }

  private formatTime(milliseconds: number): string {
    if (isNaN(milliseconds) || milliseconds < 0) {
      return '0:00'
    }
    const seconds = Math.floor(milliseconds / 1000)
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  private toggle(): void {
    if (this.isPlaying) {
      this.player.pause()
    } else {
      this.player.play()
    }
  }

  private next(): void {
    const s = PlaylistManager.playNext()
    if (s) {
      PlaylistManager.playSong(s)
    }
  }

  private prev(): void {
    const s = PlaylistManager.playPrevious()
    if (s) {
      PlaylistManager.playSong(s)
    }
  }

  // 红心收藏：真实同步到数据源（与播放页一致，乐观更新 + 失败回滚）
  private toggleFav(): void {
    const s: Song | null = this.song
    if (!s) {
      return
    }
    if (!s.source) {
      ToastUtil.showShort('无法操作：该歌曲缺少数据源')
      return
    }
    const next: boolean = !this.fav
    this.fav = next
    SourceAdapter.likeSong(s, next).then((ok: boolean) => {
      if (!ok) {
        this.fav = !next
        ToastUtil.showShort('操作失败，请稍后重试')
        return
      }
      if (s.meta) {
        s.meta.isFavorite = next
      }
      EventHelper.postFavoriteToggle(this.fav)
      ToastUtil.showShort(next ? '已收藏到「我喜欢的音乐」' : '已取消收藏')
    }).catch(() => {
      this.fav = !next
      ToastUtil.showShort('操作失败，请稍后重试')
    })
  }

  // ========== 通用小部件 ==========

  @Builder
  PlayModeButton() {
    Stack() {
      if (this.playMode === PlayMode.RANDOM) {
        SymbolGlyph($r('sys.symbol.shuffle')).fontSize(24).fontColor([V3Theme.tx2(this.mode)])
      } else if (this.playMode === PlayMode.SINGLE) {
        SymbolGlyph($r('sys.symbol.repeat_1')).fontSize(24).fontColor([V3Theme.tx2(this.mode)])
      } else {
        SymbolGlyph($r('sys.symbol.repeat')).fontSize(24).fontColor([V3Theme.tx2(this.mode)])
      }
    }
    .width(36)
    .height(36)
    .onClick(() => {
      PlaylistManager.switchPlayMode()
    })
  }

  // 播放/暂停键：无背景，与其余播控键统一尺寸（按压缩放反馈）
  @Builder
  PlainPlayButton(size: number) {
    Stack() {
      SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
        .fontSize(size)
        .fontColor([V3Theme.tx1(this.mode)])
    }
    .width(36)
    .height(36)
    .scale({ x: this.playScale, y: this.playScale })
    .onClick(() => {
      this.toggle()
    })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
          this.playScale = 0.85
        })
      } else if (e.type === TouchType.Up) {
        this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
          this.playScale = 1
        })
      }
    })
  }

  @Builder
  HeartButton(size: number) {
    SymbolGlyph(this.fav ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
      .fontSize(size)
      .fontColor([this.fav ? V3Theme.accentFallback(this.mode) : V3Theme.tx2(this.mode)])
      .width(36)
      .height(36)
      .onClick(() => {
        this.toggleFav()
      })
  }

  // 统一播控行：列表循环/上一首/播放暂停/下一首/收藏（统一 36 触控区 + 24 图标）
  @Builder
  ControlsRow() {
    Row() {
      this.PlayModeButton()
      SymbolGlyph($r('sys.symbol.backward_end_fill'))
        .fontSize(24)
        .fontColor([V3Theme.tx1(this.mode)])
        .width(36)
        .height(36)
        .onClick(() => {
          this.prev()
        })
      this.PlainPlayButton(24)
      SymbolGlyph($r('sys.symbol.forward_end_fill'))
        .fontSize(24)
        .fontColor([V3Theme.tx1(this.mode)])
        .width(36)
        .height(36)
        .onClick(() => {
          this.next()
        })
      this.HeartButton(24)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ top: 12 })
  }

  // 进度行：当前时间 + 可拖 Slider + 总时长（同横屏主题三内联样式）
  @Builder
  ProgressRow() {
    Row() {
      Text(this.formatTime(this.currentTimeMs))
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
        .width(38)
      Slider({
        value: this.currentTimeMs,
        max: this.durationMs > 0 ? this.durationMs : 100,
        step: 1,
        style: SliderStyle.InSet
      })
        .trackThickness(8)
        .selectedColor(V3Theme.tx2(this.mode))
        .trackColor(V3Theme.track(this.mode))
        .layoutWeight(1)
        // 用 SliderChangeMode 区分拖动中/结束，比 onTouch(Up) 更准确：
        // 点击轨道跳转不会产生 Touch.Up 序列，原写法会漏掉 seek
        .onChange((value: number, mode: SliderChangeMode) => {
          this.currentTimeMs = value
          if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
            this.seeking = true
          } else {
            this.player.seek(value)
            this.seeking = false
          }
        })
      Text(this.formatTime(this.durationMs))
        .fontSize(12)
        .fontColor(V3Theme.tx3(this.mode))
        .width(38)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(24)
  }

  // ========== 分栏（横屏）布局：Playing4Landscape 主题三样式 ==========

  // 顶部歌曲胶囊（仿灵动岛）：收起=小封面+歌名；展开=大封面+歌名歌手+歌词+进度+播控。
  // 材质对齐全局液态玻璃语言（glass1 + BACKGROUND_THICK + glassBorder）
  @Builder
  SongCapsule() {
    Column() {
      Row({ space: this.capsuleExpanded ? 8 : 4 }) {
        Image(cover(this.song?.album?.cover ?? '', 512))
          .aspectRatio(1)
          .width(this.capsuleExpanded ? 74 : 26)
          .clip(true)
          .borderRadius(this.capsuleExpanded ? 12 : 9)
        Column() {
          // 无歌曲时 song?.name 为 undefined，直接拼接会把 "undefined" 显示出来
          Text((this.song?.name ?? '暂无播放') + (this.capsuleExpanded ? `-${this.artistNames()}` : ''))
            .fontColor(V3Theme.tx1(this.mode))
            .height(26)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          if (this.capsuleExpanded) {
            Text(this.currentLyric())
              .fontSize(14)
              .height(22)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .fontColor(V3Theme.tx2(this.mode))
            this.ProgressRow()
          }
        }
        .layoutWeight(1)
        .alignItems(this.capsuleExpanded ? HorizontalAlign.Start : HorizontalAlign.Center)
      }
      .width('100%')

      if (this.capsuleExpanded) {
        this.ControlsRow()
      }
    }
    .width(this.capsuleExpanded ? 340 : 170)
    .margin({ top: this.topRect + 16 })
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 30, color: V3Color.SHADOW_AMBIENT, offsetX: 0, offsetY: 6 })
    .padding(this.capsuleExpanded ? 12 : 4)
    .borderRadius(this.capsuleExpanded ? 20 : 17)
    .animation({
      duration: 300,
      curve: Curve.EaseInOut
    })
    // 子级 TapGesture：点胶囊展开/消费点击，空白区域点击才收起（根节点 TapGesture）
    .gesture(
      TapGesture({ count: 1 })
        .onAction(() => {
          if (!this.capsuleExpanded) {
            this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.capsuleExpanded = true
            })
          }
        })
    )
  }

  // 时钟 + 日期（字体/字号与横屏播放页主题三共享偏好；长按弹出设置面板）
  // 竖屏字号上限 100：竖屏宽度有限，超过会换行溢出
  @Builder
  ClockText(fmt: string, portrait: boolean) {
    Column() {
      if (this.clockFont === '-1') {
        TextClock()
          .format(fmt)
          .fontFeature("\"ss01\" off")
          .fontSize(portrait ? Math.min(this.clockFontSize, 100) : this.clockFontSize)
          .fontWeight(portrait ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(V3Theme.tx1(this.mode))
      } else {
        TextClock()
          .format(fmt)
          .fontFeature("\"ss01\" off")
          .fontSize(portrait ? Math.min(this.clockFontSize, 100) : this.clockFontSize)
          .fontFamily('yxs' + this.clockFont)
          .fontColor(V3Theme.tx1(this.mode))
      }
      TextClock()
        .format('M月d日 EEEE')
        .fontSize(portrait ? 16 : 18)
        .fontColor(V3Theme.tx2(this.mode))
        .margin({ top: portrait ? 6 : 8 })
    }
    // 长按时钟：弹出字体/字号设置面板
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
            this.showClockSetting = true
          })
        })
    )
  }

  // 字体预览项（'10:08' 样张，选中描边高亮）
  @Builder
  FontItem(id: string) {
    Column() {
      if (id === '-1') {
        Text('10:08')
          .fontColor(V3Theme.tx1(this.mode))
      } else {
        Text('10:08')
          .fontFamily('yxs' + id)
          .fontColor(V3Theme.tx1(this.mode))
      }
    }
    .height('100%')
    .aspectRatio(1)
    .borderRadius(20)
    .borderWidth(this.clockFont === id ? 2 : 0)
    .borderColor(V3Theme.accentFallback(this.mode))
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.clockFont = id
      PreferencesCache.setUserPreference('Font4Theme3', id)
    })
  }

  // 时钟设置面板：横向字体样张列表 + 字号滑杆 + 确定（样式对齐横屏主题三设置区）
  @Builder
  ClockSettingPanel() {
    Column({ space: 14 }) {
      List({ space: 16 }) {
        ForEach(this.fontIds, (id: string) => {
          ListItem() {
            this.FontItem(id)
          }
        }, (id: string) => id)
      }
      .width('100%')
      .height(72)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)

      Row() {
        Text('字体大小')
          .fontSize(14)
          .fontColor(V3Theme.tx2(this.mode))
        Slider({
          value: $$this.clockFontSize,
          min: 50,
          max: 150,
          step: 1,
          style: SliderStyle.InSet
        })
          .selectedColor('rgba(255, 255, 255, 1.00)')
          .trackColor('rgba(177, 177, 177, 0.30)')
          .blockColor('rgba(164, 164, 164, 1.00)')
          .layoutWeight(1)
          .margin({ left: 12, right: 12 })
          // 仅在拖动结束时落盘：Moving 阶段每帧写偏好会造成持续磁盘 IO
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              PreferencesCache.setUserPreference('FontSize4Theme3', String(Math.floor(value)))
            }
          })
        Button('确定')
          .fontColor($r('sys.color.font'))
          .backgroundColor('rgba(177, 177, 177, 0.30)')
          .onClick(() => {
            this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
              this.showClockSetting = false
            })
          })
      }
      .width('100%')
    }
    .width('92%')
    .constraintSize({ maxWidth: 560 })
    .padding(16)
    .borderRadius(20)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .margin({ bottom: this.bottomRect + 24 })
    .transition(TransitionEffect.OPACITY.animation({ duration: 250, curve: Curve.EaseInOut })
      .combine(TransitionEffect.translate({ y: 120 })))
  }

  @Builder
  LandscapeClock() {
    Stack({ alignContent: Alignment.Top }) {
      // 大字时钟 + 日期
      Column() {
        Blank()
        this.ClockText('HH:mm:ss', false)
        Blank()
      }
      .width('100%')
      .height('100%')

      this.SongCapsule()
    }
    .width('100%')
    .height('100%')
  }

  // ========== 滑动分页（竖屏）布局：锁屏样式 ==========

  @Builder
  PortraitClock() {
    Column() {
      Blank()

      // 大时钟 + 日期（锁屏样式，长按设置字体/字号）
      this.ClockText('HH:mm', true)

      Blank()

      // 玻璃播放卡：封面 + 歌名歌手 + 当前歌词 + 进度 + 播控
      Column() {
        Image(cover(this.song?.album?.cover ?? '', 600))
          .width('100%')
          .aspectRatio(1)
          .borderRadius(22)
          .objectFit(ImageFit.Cover)
          .shadow({ radius: 40, color: 'rgba(0,0,0,0.35)', offsetX: 0, offsetY: 16 })

        Text(this.song ? `${this.song.name} - ${this.artistNames()}` : '暂无播放')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .margin({ top: 18 })

        Text(this.currentLyric())
          .fontSize(13)
          .fontColor(V3Theme.tx2(this.mode))
          .width('100%')
          .height(20)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })

        this.ProgressRow()

        this.ControlsRow()
      }
      .width('88%')
      .constraintSize({ maxWidth: 420 })
      .padding({ left: 18, right: 18, top: 18, bottom: 22 })
      .borderRadius(32)
      .backgroundColor(V3Theme.glass1(this.mode))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: V3Theme.blurMode(this.mode) })
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
      .shadow({ radius: 40, color: V3Color.SHADOW_AMBIENT, offsetX: 0, offsetY: 8 })

      Blank()

      Text('下滑退出屏保')
        .fontSize(12)
        .fontColor(V3Theme.txFaint(this.mode))
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.topRect + 24, bottom: this.bottomRect + 20 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack() {
        AmbientBackground({
          coverUrl: this.song?.album?.cover ?? '',
          blurRadius: 56,
          brightnessVal: 0.74,
          saturateVal: 0.62,
          showGlow: true,
          mode: this.mode
        })

        if (this.isSwiper) {
          this.PortraitClock()
        } else {
          this.LandscapeClock()
        }
      }
      .width('100%')
      .height('100%')
      // 下滑退出时的跟手位移
      .translate({ y: this.exitDy })

      // 防烧屏压暗遮罩：不拦截触摸（Transparent），轻触即点亮
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.saverDim ? 0.78 : 0)
        .animation({ duration: 800, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.Transparent)

      // 长按时钟弹出的字体/字号设置面板
      if (this.showClockSetting) {
        this.ClockSettingPanel()
      }
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    // 空白区域点击：收起展开的歌曲胶囊（胶囊自身 TapGesture 优先，点胶囊不触发）
    .gesture(
      TapGesture({ count: 1 })
        .onAction(() => {
          if (this.capsuleExpanded) {
            this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.capsuleExpanded = false
            })
          }
        })
    )
    // 任意触摸（含按钮/滑杆/拖动）：点亮并重新计时
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.relight()
      }
    })
    // 退出逻辑：下滑退出屏保（带阻尼跟手；未过阈值回弹）。
    // 垂直 Pan 与卡片内水平 Slider/点击互不冲突
    .gesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 12 })
        .onActionUpdate((e: GestureEvent) => {
          // 仅响应下滑，阻尼 0.5
          this.exitDy = Math.max(0, e.offsetY) * 0.5
        })
        .onActionEnd((e: GestureEvent) => {
          if (e.offsetY > 120) {
            if (this.onExit) {
              this.onExit()
            }
          } else {
            this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
              this.exitDy = 0
            })
          }
        })
    )
  }
}
