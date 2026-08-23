/**
 * OMSP 3.0 · 云端同步（端云文件协同，复用 CloudSyncManager / PreferencesCache）
 * 两种模式：
 * - manage（默认）：本地与云端数据源对比列表，支持 拉取选中 / 推送选中 / 从云端删除选中
 * - import（本地无数据源且云端存在同步文件时从首页跳入）：勾选云端源导入本地
 */
import { ID, SourceConfig, Song } from '../../type/Adapter'
import { PreferencesCache } from '../../util/PreferenceCache'
import { CloudSyncManager, CloudSyncFile, CloudTombstone } from '../../util/CloudSyncManager'
import { EventHelper } from '../../util/EventHelper'
import { AmbientBackground } from '../components/AmbientBackground'
import { ToastUtil, DialogUtil } from '@pura/harmony-utils'
import { DialogAction } from '@pura/harmony-utils/src/main/ets/entity/constraint'
import { V3Color, V3Radius, V3Theme } from '../theme/Tokens'

/** 跳转参数 */
interface CloudSyncPageParam {
  mode?: string
}

/** 列表行状态：仅本地 / 仅云端 / 本地较新 / 云端较新 / 一致 */
type RowStatus = 'local' | 'cloud' | 'local_newer' | 'cloud_newer' | 'same'

interface SyncRow {
  id: ID
  name: string
  url: string
  status: RowStatus
  selected: boolean
}

@Component
export struct ImmersiveCloudSync {
  @Consume('NavPathStack') pageStack: NavPathStack
  @StorageLink('current_playing_song') song: Song | null = null
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('bottomRect') bottomRect: number = 0
  @StorageProp('current_width_breakpoint') widthBp: WidthBreakpoint = WidthBreakpoint.WIDTH_SM
  @StorageProp('v3_theme_mode') mode: string = 'dark'

  @State importMode: boolean = false
  @State supported: boolean = true
  @State loading: boolean = true
  @State busy: boolean = false
  @State rows: SyncRow[] = []
  @State cloudRevision: number = 0
  @State cloudUpdatedAt: number = 0
  @State cloudLocation: number = -1 // 1=仅本地 2=仅云端 3=本地&云端
  @State cloudFileExists: boolean = false

  aboutToAppear(): void {
    // 读取跳转参数：{ mode: 'import' }
    const params = this.pageStack.getParamByName('ImmersiveCloudSync') as CloudSyncPageParam[]
    const last: CloudSyncPageParam | undefined = params.length > 0 ? params[params.length - 1] : undefined
    this.importMode = last?.mode === 'import'
    this.refresh()
  }

  private isWide(): boolean {
    return this.widthBp >= WidthBreakpoint.WIDTH_LG
  }

  private anim(fn: () => void): void {
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseInOut }, fn)
  }

  /** 拉取云端文件并构建本地/云端对比行 */
  private async refresh(): Promise<void> {
    this.supported = CloudSyncManager.isSupported()
    if (!this.supported) {
      this.loading = false
      return
    }
    this.loading = true
    // 云端文件元数据可能尚未下行（重装/新设备/久未同步），先触发同步并等待重试
    await CloudSyncManager.waitForCloudFile(this.importMode ? 4 : 2, 2000)
    const status = await CloudSyncManager.getCloudStatus()
    this.cloudFileExists = status.fileExists
    this.cloudLocation = status.location
    const cloud: CloudSyncFile | null = status.fileExists ? await CloudSyncManager.readCloudFile() : null
    this.cloudFileExists = cloud !== null
    this.cloudRevision = cloud?.revision ?? 0
    this.cloudUpdatedAt = cloud?.updatedAt ?? 0

    // 墓碑：deletedAt >= updatedAt 的云端源不再展示
    const tombMap = new Map<ID, number>()
    cloud?.tombstones?.forEach((t: CloudTombstone) => {
      tombMap.set(t.id, Math.max(tombMap.get(t.id) ?? 0, t.deletedAt))
    })

    const rows: SyncRow[] = []
    const seen = new Set<ID>()
    if (!this.importMode) {
      PreferencesCache.getUserDataSource().forEach((s: SourceConfig) => {
        seen.add(s.id)
        rows.push({
          id: s.id, name: s.name, url: s.url,
          status: 'local', selected: false
        })
      })
    }
    cloud?.sources?.forEach((cs: SourceConfig) => {
      const deletedAt = tombMap.get(cs.id) ?? -1
      if (deletedAt >= (cs.updatedAt ?? 0)) {
        return
      }
      if (seen.has(cs.id)) {
        const local = PreferencesCache.getUserDataSource().find((s: SourceConfig) => s.id === cs.id)
        const lu = local?.updatedAt ?? 0
        const cu = cs.updatedAt ?? 0
        const row = rows.find((r: SyncRow) => r.id === cs.id)
        if (row) {
          row.status = cu > lu ? 'cloud_newer' : (lu > cu ? 'local_newer' : 'same')
        }
      } else {
        rows.push({
          id: cs.id, name: cs.name, url: cs.url,
          status: 'cloud', selected: this.importMode
        })
      }
    })
    // 默认勾选有差异的行，方便一键同步
    rows.forEach((r: SyncRow) => {
      r.selected = this.importMode ? true : r.status !== 'same'
    })
    this.anim(() => {
      this.rows = rows
      this.loading = false
    })
  }

  private selectedIds(): ID[] {
    return this.rows.filter((r: SyncRow) => r.selected).map((r: SyncRow) => r.id)
  }

  private selectedCount(): number {
    return this.rows.filter((r: SyncRow) => r.selected).length
  }

  /** 拉取选中：取云端版本写入本地（新增或覆盖） */
  private async pullSelected(): Promise<void> {
    const ids = this.selectedIds()
    if (ids.length === 0) {
      ToastUtil.showShort('请先勾选要拉取的数据源')
      return
    }
    this.busy = true
    const count = await CloudSyncManager.importCloudSources(ids)
    this.busy = false
    if (count > 0) {
      // 触发全量数据刷新：推荐/榜单/用户歌单等（启动时无数据源会跳过加载）
      EventHelper.postInitData('')
    }
    ToastUtil.showShort(count > 0 ? `已拉取 ${count} 个数据源到本地` : '云端没有可拉取的数据')
    await this.refresh()
  }

  /** 推送选中：本地更改增量合并到云端文件并触发上云 */
  private async pushSelected(): Promise<void> {
    const ids = this.selectedIds()
    if (ids.length === 0) {
      ToastUtil.showShort('请先勾选要推送的数据源')
      return
    }
    this.busy = true
    const revision = await CloudSyncManager.pushToCloud(ids)
    this.busy = false
    if (revision > 0) {
      ToastUtil.showShort(`已推送到云端（版本 ${revision}）`)
      // 推送后异步检测是否真正上云（未开云空间开关时引导用户开启）
      CloudSyncManager.checkUploadHealth().then((r: string) => {
        if (r === 'not_synced') {
          this.showNotSyncedDialog()
        }
      })
    } else {
      ToastUtil.showShort('推送失败，请检查网络与云空间开关')
    }
    await this.refresh()
  }

  /** 从云端删除选中：写入墓碑并推送，其他设备拉取后同步删除 */
  private deleteSelected(): void {
    const ids = this.selectedIds()
    if (ids.length === 0) {
      ToastUtil.showShort('请先勾选要删除的数据源')
      return
    }
    DialogUtil.showPrimaryDialog({
      title: '从云端删除',
      message: `确定从云端删除选中的 ${ids.length} 个数据源？其他设备同步后也会移除，本地数据不受影响。`,
      primaryButton: '取消',
      secondaryButton: '删除',
      onAction: (action: number) => {
        if (action === DialogAction.TWO) {
          this.busy = true
          CloudSyncManager.deleteCloudSources(ids).then((revision: number) => {
            this.busy = false
            ToastUtil.showShort(revision > 0 ? '已从云端删除' : '删除失败，请检查网络与云空间开关')
            this.refresh()
          })
        }
      }
    })
  }

  /** 导入模式：勾选云端源导入本地 */
  private async importSelected(): Promise<void> {
    const ids = this.selectedIds()
    if (ids.length === 0) {
      ToastUtil.showShort('请先勾选要导入的数据源')
      return
    }
    this.busy = true
    const count = await CloudSyncManager.importCloudSources(ids)
    this.busy = false
    ToastUtil.showShort(`已导入 ${count} 个数据源`)
    if (count > 0) {
      // 触发全量数据刷新：推荐/榜单/用户歌单等（启动时无数据源会跳过加载）
      EventHelper.postInitData('')
    }
    this.pageStack.pop()
  }

  /** 未上云提示弹窗：引导用户去开启云空间同步开关 */
  private showNotSyncedDialog(): void {
    DialogUtil.showPrimaryDialog({
      title: '未检测到上云',
      message: '同步文件一直未上传到云端，可能未登录华为账号或未开启本应用的云空间同步开关。路径：设置 → 云空间 → 使用云空间的应用。',
      primaryButton: '取消',
      secondaryButton: '去开启',
      onAction: (action: number) => {
        if (action === DialogAction.TWO) {
          CloudSyncManager.openCloudSpaceSettings().then((ok: boolean) => {
            if (!ok) {
              ToastUtil.showShort('拉起设置失败，请手动前往 设置→云空间')
            }
          })
        }
      }
    })
  }

  /** 上云健康检查：确认文件是否真正同步到云端；异常时引导用户去开启云空间同步开关 */
  private async checkHealth(): Promise<void> {
    ToastUtil.showShort('正在检测上云状态...')
    const result = await CloudSyncManager.checkUploadHealth()
    if (result === 'ok') {
      ToastUtil.showShort('云端同步正常')
    } else if (result === 'no_file') {
      ToastUtil.showShort('尚未推送过数据，请先推送一次')
    } else if (result === 'unsupported') {
      ToastUtil.showShort('当前设备不支持端云文件协同')
    } else {
      this.showNotSyncedDialog()
    }
  }

  private statusLabel(status: RowStatus): string {
    switch (status) {
      case 'local': return '仅本地'
      case 'cloud': return '仅云端'
      case 'local_newer': return '本地较新'
      case 'cloud_newer': return '云端较新'
      default: return '已同步'
    }
  }

  private statusColor(status: RowStatus): string {
    switch (status) {
      case 'local': return '#D4A962'
      case 'cloud': return '#6E8FB0'
      case 'local_newer': return '#C99A57'
      case 'cloud_newer': return '#7FA8C9'
      default: return '#7FB08A'
    }
  }

  private locationLabel(): string {
    switch (this.cloudLocation) {
      case 1: return '仅本地（待上云）'
      case 2: return '仅云端'
      case 3: return '本地 & 云端'
      default: return '未知'
    }
  }

  private formatTime(ts: number): string {
    if (!ts) {
      return '—'
    }
    const d = new Date(ts)
    const p = (n: number) => n.toString().padStart(2, '0')
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
  }

  // ============ 状态卡片 ============
  @Builder
  StatusCard() {
    Column({ space: 8 }) {
      Row() {
        Text('云端同步文件')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .layoutWeight(1)
        Text(this.cloudFileExists ? `版本 ${this.cloudRevision}` : '未创建')
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
      }
      .width('100%')

      if (this.cloudFileExists) {
        Text(`更新时间：${this.formatTime(this.cloudUpdatedAt)} · ${this.locationLabel()}`)
          .fontSize(12)
          .fontColor(V3Theme.tx2(this.mode))
          .width('100%')
      } else {
        Text('推送一次本地数据源后自动创建')
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .width('100%')
      }

      Row({ space: 10 }) {
        Text('配置通过华为云空间在多台设备间同步，云盘应用中不可见')
          .fontSize(11.5)
          .fontColor(V3Theme.tx3(this.mode))
          .layoutWeight(1)
        Text('上云检测')
          .fontSize(12.5)
          .fontColor(V3Theme.tx2(this.mode))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor(V3Theme.glass2(this.mode))
          .onClick(() => {
            this.checkHealth()
          })
        Text('立即同步')
          .fontSize(12.5)
          .fontColor(V3Theme.accentFallback(this.mode))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor(V3Theme.glass2(this.mode))
          .onClick(() => {
            CloudSyncManager.triggerSync()
            ToastUtil.showShort('已触发云同步')
          })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding(16)
    .borderRadius(V3Radius.CHIP)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 18, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .clip(true)
  }

  // ============ 数据源行 ============
  @Builder
  SyncRowCard(row: SyncRow, index: number) {
    Row({ space: 12 }) {
      Checkbox()
        .select(row.selected)
        .selectedColor(V3Theme.accentFallback(this.mode))
        .onChange((v: boolean) => {
          this.rows[index].selected = v
          this.rows = [...this.rows]
        })
      Column({ space: 4 }) {
        Text(row.name || '未命名')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(V3Theme.tx1(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(row.url)
          .fontSize(12)
          .fontColor(V3Theme.tx3(this.mode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(this.statusLabel(row.status))
        .fontSize(11)
        .fontColor(this.statusColor(row.status))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(8)
        .backgroundColor(V3Theme.glass2(this.mode))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .borderRadius(18)
    .backgroundColor(V3Theme.glass1(this.mode))
    .backgroundBlurStyle(V3Theme.cardBlur(), { colorMode: V3Theme.blurMode(this.mode) })
    .border({ width: 1, color: V3Theme.glassBorder(this.mode) })
    .shadow({ radius: 16, color: V3Theme.cardShadow(this.mode), offsetX: 0, offsetY: 5 })
    .onClick(() => {
      this.rows[index].selected = !this.rows[index].selected
      this.rows = [...this.rows]
    })
  }

  // ============ 操作按钮 ============
  @Builder
  ActionButton(label: string, primary: boolean, danger: boolean, onTap: () => void) {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(danger ? '#C97B7B' : (primary ? '#FFFFFF' : V3Theme.tx1(this.mode)))
      .width('100%')
      .height(50)
      .textAlign(TextAlign.Center)
      .borderRadius(16)
      .backgroundColor(primary ? V3Theme.accentFallback(this.mode) : V3Theme.glass2(this.mode))
      .border({ width: primary ? 0 : 1, color: V3Theme.glassBorder(this.mode) })
      .enabled(!this.busy)
      .opacity(this.busy ? 0.6 : 1)
      .onClick(onTap)
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
          // 顶栏
          Row() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(22)
              .fontColor([V3Theme.tx1(this.mode)])
              .padding(6)
              .onClick(() => {
                this.pageStack.pop()
              })
            Text(this.importMode ? '从云端导入数据源' : '云端同步')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(V3Theme.tx1(this.mode))
              .margin({ left: 8 })
            Blank()
            if (this.selectedCount() > 0) {
              Text(`已选 ${this.selectedCount()} 项`)
                .fontSize(12)
                .fontColor(V3Theme.tx3(this.mode))
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: this.isWide() ? 760 : '100%' })
          .margin({ bottom: 18 })

          Scroll() {
            Column({ space: 14 }) {
              if (!this.supported) {
                Column({ space: 10 }) {
                  Text('当前设备不支持端云文件协同')
                    .fontSize(15)
                    .fontColor(V3Theme.tx1(this.mode))
                  Text('需要 HarmonyOS 6.0 及以上，并在 设置→云空间 中开启本应用的同步开关')
                    .fontSize(12.5)
                    .fontColor(V3Theme.tx3(this.mode))
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .padding({ top: 60, bottom: 40 })
                .alignItems(HorizontalAlign.Center)
              } else if (this.loading) {
                Column({ space: 12 }) {
                  LoadingProgress().width(36).height(36)
                  Text('正在读取云端数据...')
                    .fontSize(13)
                    .fontColor(V3Theme.tx2(this.mode))
                }
                .width('100%')
                .padding({ top: 60, bottom: 40 })
                .alignItems(HorizontalAlign.Center)
              } else {
                if (!this.importMode) {
                  this.StatusCard()
                } else {
                  Text('检测到云端存在数据源配置，勾选后导入本地')
                    .fontSize(13)
                    .fontColor(V3Theme.tx2(this.mode))
                    .width('100%')
                }

                if (this.rows.length > 0) {
                  ForEach(this.rows, (row: SyncRow, index: number) => {
                    this.SyncRowCard(row, index)
                  }, (row: SyncRow) => `${row.id}`)
                } else {
                  Column({ space: 10 }) {
                    SymbolGlyph($r('sys.symbol.externaldrive'))
                      .fontSize(44)
                      .fontColor([V3Theme.tx3(this.mode)])
                    Text(this.importMode ? '云端没有可导入的数据源' : '暂无数据源')
                      .fontSize(15)
                      .fontColor(V3Theme.tx2(this.mode))
                    Text(this.importMode ? '' : '先在「数据源管理」中添加，再推送到云端')
                      .fontSize(12.5)
                      .fontColor(V3Theme.tx3(this.mode))
                  }
                  .width('100%')
                  .padding({ top: 40, bottom: 30 })
                  .alignItems(HorizontalAlign.Center)
                }

                // 操作区
                if (this.rows.length > 0) {
                  Column({ space: 10 }) {
                    if (this.importMode) {
                      this.ActionButton(this.busy ? '导入中...' : '导入所选', true, false, () => {
                        this.importSelected()
                      })
                    } else {
                      this.ActionButton(this.busy ? '处理中...' : '拉取选中到本地', true, false, () => {
                        this.pullSelected()
                      })
                      this.ActionButton('推送选中到云端', false, false, () => {
                        this.pushSelected()
                      })
                      this.ActionButton('从云端删除选中', false, true, () => {
                        this.deleteSelected()
                      })
                    }
                  }
                  .width('100%')
                  .margin({ top: 4 })
                }
              }

              Row().height(this.bottomRect + 20)
            }
            .width('100%')
            .constraintSize({ maxWidth: this.isWide() ? 760 : '100%' })
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
      return false
    })
  }
}
