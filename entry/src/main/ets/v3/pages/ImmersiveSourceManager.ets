/**
 * OMSP 3.0 · 数据源管理（全新玻璃风，复用底层 SourceAdapter / PreferencesCache）
 * 列表 CRUD + 内联两步添加向导（① 地址信息 ② 授权：Token / 扫码）。
 * 底层：SourceAdapter.getConnectionStatus/getQRCodeKey/createQRCode/checkQRCodeStatus，
 * PreferencesCache.add/update/deleteUserDataSource + deleteSongsOfAggregationPlaylists + *ShowUserDataSource。
 */
import { SourceConfig, Song } from '../../type/Adapter'
import { SourceAdapter } from '../../adapter'
import { PreferencesCache } from '../../util/PreferenceCache'
import { cover } from '../../util/AdapterHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { ToastUtil, DialogUtil } from '@pura/harmony-utils'
import { DialogAction } from '@pura/harmony-utils/src/main/ets/entity/constraint'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

@Component
export struct ImmersiveSourceManager {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') song: Song | null = null
  @StorageLink('user_data_source') sources: SourceConfig[] = []
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'

  // 向导状态
  @State showWizard: boolean = false
  @State wizardStep: number = 0 // 0=地址信息 1=授权
  @State isEditing: boolean = false
  @State editingId: string = ''
  @State formName: string = ''
  @State formUrl: string = ''
  @State formDesc: string = ''
  @State formToken: string = ''
  @State authTab: string = 'token' // 'token' | 'qr'
  @State submitting: boolean = false
  // 扫码状态
  @State qrImg: string = ''
  @State qrUnikey: string = ''
  @State qrStatus: number = 0 // -1 过期 0 等待扫码 1 待确认 2 成功
  @State qrStatusText: string = '请先生成二维码'
  private qrTimer: number = -1

  aboutToDisappear(): void {
    this.clearQrTimer()
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  // 统一的柔和过渡
  private anim(fn: () => void): void {
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseInOut }, fn)
  }

  private validateUrl(url: string): boolean {
    const p: RegExp = /^(http|https):\/\/[a-zA-Z0-9-.]+(:\d+)?(\/[a-zA-Z0-9-._?&=]*)?$/
    return p.test(url)
  }

  // ============ 向导流程 ============
  private openAdd(): void {
    this.isEditing = false
    this.editingId = `user_data_source_${Date.now()}`
    this.formName = ''
    this.formUrl = ''
    this.formDesc = ''
    this.formToken = ''
    this.authTab = 'token'
    this.anim(() => { this.wizardStep = 0 })
    this.resetQr()
    this.anim(() => { this.showWizard = true })
  }

  private openEdit(s: SourceConfig): void {
    this.isEditing = true
    this.editingId = `${s.id}`
    this.formName = s.name ?? ''
    this.formUrl = s.url ?? ''
    this.formDesc = s.description ?? ''
    this.formToken = s.auth?.token ?? ''
    this.authTab = 'token'
    this.anim(() => { this.wizardStep = 0 })
    this.resetQr()
    this.anim(() => { this.showWizard = true })
  }

  private closeWizard(): void {
    this.clearQrTimer()
    this.anim(() => { this.showWizard = false })
  }

  private nextStep(): void {
    if (!this.formName.trim()) {
      ToastUtil.showShort('请输入数据源名称')
      return
    }
    if (!this.validateUrl(this.formUrl.trim())) {
      ToastUtil.showShort('请输入有效的数据源地址（http/https）')
      return
    }
    this.anim(() => { this.wizardStep = 1 })
  }

  private buildSource(): SourceConfig {
    return {
      id: this.editingId,
      name: this.formName.trim(),
      url: this.formUrl.trim(),
      description: this.formDesc.trim(),
      auth: { token: this.formToken.trim(), signAt: Date.now() }
    } as SourceConfig
  }

  private submit(): void {
    if (!this.formToken.trim()) {
      ToastUtil.showShort('请填写 Token 或扫码登录获取凭证')
      return
    }
    this.submitting = true
    const src: SourceConfig = this.buildSource()
    SourceAdapter.getConnectionStatus(src)
      .then((connected: SourceConfig) => {
        if (this.isEditing) {
          PreferencesCache.updateUserDataSource(connected)
          PreferencesCache.updateShowUserDataSource(connected)
          ToastUtil.showShort('数据源已更新')
        } else {
          PreferencesCache.addUserDataSource(connected)
          PreferencesCache.addShowUserDataSource(connected)
          ToastUtil.showShort('数据源已添加')
        }
        // 后台预热推荐
        SourceAdapter.getRecommendSongs()
        SourceAdapter.getTopList()
        this.submitting = false
        this.closeWizard()
      })
      .catch((e: Error) => {
        this.submitting = false
        ToastUtil.showShort(`连接失败：${e.message}`)
      })
  }

  private deleteSource(s: SourceConfig): void {
    DialogUtil.showPrimaryDialog({
      title: '删除数据源',
      message: `确定删除「${s.name}」？该源的聚合歌单歌曲也会一并移除。`,
      primaryButton: '取消',
      secondaryButton: '删除',
      onAction: (action: number) => {
        if (action === DialogAction.TWO) {
          PreferencesCache.deleteUserDataSource(s.id)
          PreferencesCache.deleteSongsOfAggregationPlaylists(s.id)
          PreferencesCache.deleteShowUserDataSource(s.id)
          ToastUtil.showShort('数据源已删除')
        }
      }
    })
  }

  // ============ 扫码 ============
  private resetQr(): void {
    this.clearQrTimer()
    this.qrImg = ''
    this.qrUnikey = ''
    this.qrStatus = 0
    this.qrStatusText = '请先生成二维码'
  }

  private clearQrTimer(): void {
    if (this.qrTimer !== -1) {
      clearInterval(this.qrTimer)
      this.qrTimer = -1
    }
  }

  private async genQr(): Promise<void> {
    if (!this.validateUrl(this.formUrl.trim())) {
      ToastUtil.showShort('请先在上一步填写有效地址')
      return
    }
    this.qrStatusText = '正在生成二维码...'
    this.qrImg = ''
    try {
      const src: SourceConfig = this.buildSource()
      this.qrUnikey = await SourceAdapter.getQRCodeKey(src)
      const qr = await SourceAdapter.createQRCode(src, this.qrUnikey)
      this.qrImg = qr.qrimg
      this.qrStatus = 0
      this.qrStatusText = '请使用对应 App 扫码登录'
      this.clearQrTimer()
      this.qrTimer = setInterval(() => {
        this.checkQr()
      }, 3000)
    } catch (e) {
      this.qrStatusText = '二维码生成失败，请重试'
    }
  }

  private async checkQr(): Promise<void> {
    if (!this.qrUnikey) {
      return
    }
    try {
      const src: SourceConfig = this.buildSource()
      const res = await SourceAdapter.checkQRCodeStatus(src, this.qrUnikey)
      this.qrStatus = res.status
      if (res.status === -1) {
        this.qrStatusText = '二维码已过期，请重新生成'
        this.clearQrTimer()
      } else if (res.status === 0) {
        this.qrStatusText = '等待扫码...'
      } else if (res.status === 1) {
        this.qrStatusText = '请在手机上确认登录'
      } else if (res.status === 2) {
        this.qrStatusText = '授权成功，凭证已填入'
        this.formToken = res.cookie
        this.clearQrTimer()
      }
    } catch (e) {
      // 忽略单次轮询失败
    }
  }

  // ============ 输入框 ============
  @Builder
  Field(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor(V3Theme.tx2(this.mode))
      TextInput({ text: value, placeholder: placeholder })
        .fontSize(15)
        .fontColor(V3Theme.tx1(this.mode))
        .placeholderColor(V3Theme.tx3(this.mode))
        .backgroundColor(V3Theme.glass2(this.mode))
        .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .height(48)
        .caretColor(V3Theme.accentFallback(this.mode))
        .onChange((v: string) => {
          onChange(v)
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ============ 源列表卡片 ============
  @Builder
  SourceCard(s: SourceConfig) {
    Row({ space: 13 }) {
      if ((s.auth?.user?.avatar ?? '').length > 0) {
        Image(cover(s.auth?.user?.avatar ?? '', 100))
          .width(46)
          .height(46)
          .borderRadius(23)
          .objectFit(ImageFit.Cover)
      } else {
        Text((s.name ?? '源').substring(0, 1))
          .width(46)
          .height(46)
          .borderRadius(23)
          .textAlign(TextAlign.Center)
          .fontSize(18)
          .fontColor('#FFFFFF')
          .backgroundColor(V3Theme.accentFallback(this.mode))
      }
      Column({ space: 4 }) {
        Text(s.auth?.user?.name ?? s.name ?? '未命名')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(s.url ?? '')
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      // 状态点
      Row({ space: 5 }) {
        Row().width(7).height(7).borderRadius(4).backgroundColor('#7FB08A')
        Text('已连接')
          .fontSize(11)
          .fontColor(V3Theme.tx3(this.mode))
      }
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize(18)
        .fontColor([V3Theme.tx2(this.mode)])
        .padding(6)
        .onClick(() => {
          this.openEdit(s)
        })
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(18)
        .fontColor([V3Theme.tx2(this.mode)])
        .padding(6)
        .onClick(() => {
          this.deleteSource(s)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 12, bottom: 12 })
    .borderRadius(18)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 16, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
  }

  // ============ 列表视图 ============
  @Builder
  ListView() {
    Column({ space: 14 }) {
      if (this.sources && this.sources.length > 0) {
        ForEach(this.sources, (s: SourceConfig) => {
          this.SourceCard(s)
        }, (s: SourceConfig) => `${s.id}`)
      } else {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.externaldrive'))
            .fontSize(44)
            .fontColor([V3Theme.tx3(this.mode)])
          Text('还没有数据源')
            .fontSize(15)
            .fontColor(V3Theme.tx2(this.mode))
          Text('添加数据源以搜索、播放与同步歌单')
            .fontSize(12.5)
            .fontColor(V3Theme.tx3(this.mode))
        }
        .width('100%')
        .padding({ top: 60, bottom: 40 })
        .alignItems(HorizontalAlign.Center)
      }

      // 添加按钮
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(18)
          .fontColor([V3Theme.accentFallback(this.mode)])
        Text('添加数据源')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.accentFallback(this.mode))
      }
      .width('100%')
      .height(52)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(V3Theme.isLight(this.mode) ? 'rgba(169,122,52,0.10)' : 'rgba(216,176,114,0.12)')
      .border({ width: 1, color: 'rgba(201,154,87,0.45)' })
      .onClick(() => {
        this.openAdd()
      })

      Row().height(this.bottomRect + 20)
    }
    .width('100%')
    .constraintSize({ maxWidth: this.isWide() ? 760 : '100%' })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: -30 })).animation({ duration: 260, curve: Curve.EaseOut }))
  }

  // ============ 向导视图 ============
  @Builder
  StepDots() {
    Row({ space: 8 }) {
      this.StepDot(0, '地址信息')
      Row().width(24).height(1).backgroundColor(V3Theme.hairline(this.mode))
      this.StepDot(1, '授权登录')
    }
    .margin({ bottom: 24 })
  }

  @Builder
  StepDot(idx: number, label: string) {
    Row({ space: 7 }) {
      Text(`${idx + 1}`)
        .fontSize(13)
        .fontColor(this.wizardStep >= idx ? '#FFFFFF' : V3Theme.tx3(this.mode))
        .width(24)
        .height(24)
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor(this.wizardStep >= idx ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
      Text(label)
        .fontSize(13)
        .fontColor(this.wizardStep >= idx ? V3Theme.tx1(this.mode) : V3Theme.tx3(this.mode))
    }
  }

  @Builder
  WizardStep1() {
    Column({ space: 18 }) {
      this.Field('数据源名称', this.formName, '例如：我的OMSP协议', (v: string) => {
        this.formName = v
      })
      this.Field('数据源地址', this.formUrl, 'https://example.com', (v: string) => {
        this.formUrl = v
      })
      this.Field('描述（可选）', this.formDesc, '备注信息', (v: string) => {
        this.formDesc = v
      })
      Button('下一步')
        .width('100%')
        .height(50)
        .fontColor('#FFFFFF')
        .backgroundColor(V3Theme.accentFallback(this.mode))
        .borderRadius(16)
        .onClick(() => {
          this.nextStep()
        })
    }
    .width('100%')
  }

  @Builder
  AuthTab(key: string, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.authTab === key ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.authTab === key ? '#FFFFFF' : V3Theme.tx2(this.mode))
      .layoutWeight(1)
      .height(38)
      .textAlign(TextAlign.Center)
      .borderRadius(12)
      .backgroundColor(this.authTab === key ? V3Theme.accentFallback(this.mode) : 'rgba(0,0,0,0)')
      .onClick(() => {
        this.anim(() => { this.authTab = key })
      })
  }

  @Builder
  WizardStep2() {
    Column({ space: 18 }) {
      // 授权方式切换
      Row() {
        this.AuthTab('token', 'Token 凭证')
        this.AuthTab('qr', '扫码登录')
      }
      .width('100%')
      .padding(4)
      .borderRadius(15)
      .backgroundColor(V3Theme.glass1(this.mode))
      .border({ width: 1, color: V3Theme.glassBorder(this.mode) })

      if (this.authTab === 'token') {
        this.Field('Token / Cookie', this.formToken, '粘贴登录凭证', (v: string) => {
          this.formToken = v
        })
      } else {
        // 扫码
        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            if (this.qrImg.length > 0) {
              Image(this.qrImg)
                .width(180)
                .height(180)
                .borderRadius(12)
            } else {
              SymbolGlyph($r('sys.symbol.qrcode'))
                .fontSize(52)
                .fontColor([V3Theme.tx3(this.mode)])
            }
          }
          .width(200)
          .height(200)
          .borderRadius(16)
          .backgroundColor(V3Theme.isLight(this.mode) ? '#FFFFFF' : 'rgba(255,255,255,0.9)')
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })

          Text(this.qrStatusText)
            .fontSize(13)
            .fontColor(this.qrStatus === 2 ? '#7FB08A' : V3Theme.tx2(this.mode))

          Button(this.qrImg.length > 0 ? '重新生成二维码' : '生成二维码')
            .fontColor(V3Theme.accentFallback(this.mode))
            .backgroundColor(V3Theme.glass2(this.mode))
            .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
            .borderRadius(14)
            .height(44)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              this.genQr()
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      Row({ space: 12 }) {
        Button('上一步')
          .layoutWeight(1)
          .height(50)
          .fontColor(V3Theme.tx1(this.mode))
          .backgroundColor(V3Theme.glass2(this.mode))
          .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
          .borderRadius(16)
          .onClick(() => {
            this.anim(() => { this.wizardStep = 0 })
          })
        Button(this.submitting ? '连接中...' : (this.isEditing ? '保存' : '完成'))
          .layoutWeight(1)
          .height(50)
          .fontColor('#FFFFFF')
          .backgroundColor(V3Theme.accentFallback(this.mode))
          .borderRadius(16)
          .enabled(!this.submitting)
          .onClick(() => {
            this.submit()
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  WizardView() {
    Column() {
      // 向导头
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([V3Theme.tx1(this.mode)])
          .padding(6)
          .onClick(() => {
            this.closeWizard()
          })
        Text(this.isEditing ? '编辑数据源' : '添加数据源')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .margin({ bottom: 20 })

      this.StepDots()

      if (this.wizardStep === 0) {
        this.WizardStep1()
      } else {
        this.WizardStep2()
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: this.isWide() ? 560 : '100%' })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 30 })).animation({ duration: 260, curve: Curve.EaseOut }))
  }

  build() {
    NavDestination() {
      Stack() {
        AmbientBackground({
          coverUrl: this.song?.album?.cover ?? '',
          mode: this.mode,
          blurRadius: 72,
          brightnessVal: 0.5,
          saturateVal: 0.42,
          showGlow: false,
          dim: 0.32
        })

        Column() {
          // 顶栏（列表态）
          if (!this.showWizard) {
            Row() {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(22)
                .fontColor([V3Theme.tx1(this.mode)])
                .padding(6)
                .onClick(() => {
                  this.pageStack.pop()
                })
              Text('数据源管理')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(V3Theme.tx1(this.mode))
                .margin({ left: 8 })
              Blank()
            }
            .width('100%')
            .constraintSize({ maxWidth: this.isWide() ? 760 : '100%' })
            .margin({ bottom: 18 })
          }

          Scroll() {
            Column() {
              if (this.showWizard) {
                this.WizardView()
              } else {
                this.ListView()
              }
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, top: this.topRect + 14 })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(V3Color.CANVAS)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onBackPressed(() => {
      if (this.showWizard) {
        this.closeWizard()
        return true
      }
      return false
    })
  }
}
