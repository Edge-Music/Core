/**
 * 数据源配置云同步管理器（端云文件协同）
 * 参照 AppCloudSync 示例：文件写入 context.cloudFileDir（/data/storage/el2/cloud），
 * 由系统云空间自动同步上云；cloudSync.FileSync 主动触发同步，CloudFileCache 按需下载云文件。
 *
 * 同步逻辑（增量 + 墓碑）：
 * - 云端文件 datasource_sync.json 内含 revision / sources(含 updatedAt) / showIds / tombstones
 * - 合并按 id 取 updatedAt 较大者；墓碑 deletedAt >= updatedAt 时删除生效
 * - 推送前重新读取云端最新文件再合并，防止多设备并发覆盖
 */
import { fileIo as fs, cloudSync, fileUri, ReadOptions } from '@kit.CoreFileKit'
import { common, Want } from '@kit.AbilityKit'
import { buffer, util } from '@kit.ArkTS'
import { AppUtil, LogUtil } from '@pura/harmony-utils'
import { ID, SourceConfig } from '../type/Adapter'
import { PreferencesCache } from './PreferenceCache'

const TAG = 'CloudSyncManager'
const SYNC_FILE_NAME = 'datasource_sync.json'
const FORMAT_VERSION = 1
const SYSCAP_CLOUD_SYNC = 'SystemCapability.FileManagement.DistributedFileService.CloudSync.Core'

/** 删除墓碑：标记某数据源已在云端删除 */
export interface CloudTombstone {
  id: ID
  deletedAt: number
}

/** 云端同步文件结构 */
export interface CloudSyncFile {
  formatVersion: number
  revision: number
  updatedAt: number
  deviceId: string
  sources: SourceConfig[]
  showIds: ID[]
  tombstones: CloudTombstone[]
}

/** 云端状态（供页面展示） */
export interface CloudSyncStatus {
  supported: boolean
  fileExists: boolean
  revision: number
  updatedAt: number
  /** 文件位置：1=仅本地 2=仅云端 3=本地&云端 */
  location: number
  sourceCount: number
}

export class CloudSyncManager {
  private static fileSync: cloudSync.FileSync | null = null
  private static cacheInFlight: boolean = false

  /** 当前设备是否支持端云文件协同 */
  static isSupported(): boolean {
    return canIUse(SYSCAP_CLOUD_SYNC)
  }

  private static cloudDir(): string {
    const context = AppUtil.getContext() as common.UIAbilityContext
    return context.cloudFileDir
  }

  private static filePath(): string {
    return `${CloudSyncManager.cloudDir()}/${SYNC_FILE_NAME}`
  }

  /** 本机标识（用于同步文件元信息，持久化一次生成） */
  private static deviceId(): string {
    let id = PreferencesCache.getCache('cloud_sync_device_id', '')
    if (!id) {
      id = util.generateRandomUUID(false)
      PreferencesCache.setCache('cloud_sync_device_id', id)
    }
    return id
  }

  /** 云端是否已存在同步文件（仅查本地可见性，不触发同步） */
  static hasCloudSyncFile(): boolean {
    if (!CloudSyncManager.isSupported()) {
      return false
    }
    try {
      return fs.accessSync(CloudSyncManager.filePath())
    } catch (e) {
      LogUtil.warn(`[${TAG}]`, `accessSync failed: ${JSON.stringify(e)}`)
      return false
    }
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise((resolve: () => void) => {
      setTimeout(resolve, ms)
    })
  }

  /**
   * 等待云端同步文件出现：每轮触发一次 FileSync 拉取云端元数据后再检查。
   * 重装/新设备上云文件元数据需要系统同步下行，单次立即检查大概率看不到。
   */
  static async waitForCloudFile(maxRetries: number = 4, intervalMs: number = 2500): Promise<boolean> {
    if (!CloudSyncManager.isSupported()) {
      return false
    }
    for (let i = 0; i <= maxRetries; i++) {
      if (CloudSyncManager.hasCloudSyncFile()) {
        return true
      }
      if (i < maxRetries) {
        CloudSyncManager.triggerSync()
        await CloudSyncManager.sleep(intervalMs)
      }
    }
    return false
  }

  /** 文件位置：1=仅本地 2=仅云端 3=本地&云端，-1=不存在/不可用 */
  private static fileLocation(path: string): number {
    try {
      return fs.statSync(path).location
    } catch (e) {
      return -1
    }
  }

  /** 云端文件只有元数据（location==2）时，先缓存到本地再读；失败重试一次 */
  private static async ensureLocalFile(path: string): Promise<boolean> {
    const location = CloudSyncManager.fileLocation(path)
    if (location === 3 || location === 1) {
      return true
    }
    if (location !== 2 || CloudSyncManager.cacheInFlight) {
      return location === 3 || location === 1
    }
    CloudSyncManager.cacheInFlight = true
    try {
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const cache = new cloudSync.CloudFileCache()
          const uri = fileUri.getUriFromPath(path)
          await cache.start(uri)
          if (CloudSyncManager.fileLocation(path) !== 2) {
            return true
          }
        } catch (e) {
          LogUtil.error(`[${TAG}]`, `CloudFileCache.start failed(attempt ${attempt}): ${JSON.stringify(e)}`)
        }
        // 下载未完成时触发一次整机同步后重试
        CloudSyncManager.triggerSync()
        await CloudSyncManager.sleep(2000)
      }
      return CloudSyncManager.fileLocation(path) !== 2
    } finally {
      CloudSyncManager.cacheInFlight = false
    }
  }

  /** 读取并解析云端同步文件；文件损坏时备份改名并返回 null */
  static async readCloudFile(): Promise<CloudSyncFile | null> {
    if (!CloudSyncManager.hasCloudSyncFile()) {
      return null
    }
    const path = CloudSyncManager.filePath()
    try {
      const ok = await CloudSyncManager.ensureLocalFile(path)
      if (!ok) {
        return null
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
      const size = fs.statSync(path).size
      if (size <= 0) {
        fs.closeSync(file)
        return null
      }
      const arrayBuffer = new ArrayBuffer(size)
      const readOptions: ReadOptions = { offset: 0, length: size }
      const readLen = fs.readSync(file.fd, arrayBuffer, readOptions)
      fs.closeSync(file)
      const content = buffer.from(arrayBuffer, 0, readLen).toString()
      const data = JSON.parse(content) as CloudSyncFile
      // 字段兜底，兼容缺失字段的旧文件
      data.sources = data.sources ?? []
      data.showIds = data.showIds ?? []
      data.tombstones = data.tombstones ?? []
      data.revision = data.revision ?? 0
      return data
    } catch (e) {
      LogUtil.error(`[${TAG}]`, `readCloudFile failed: ${JSON.stringify(e)}`)
      try {
        fs.renameSync(path, `${path}.broken_${Date.now()}`)
      } catch (renameErr) {
        LogUtil.warn(`[${TAG}]`, `backup broken file failed: ${JSON.stringify(renameErr)}`)
      }
      return null
    }
  }

  private static writeCloudFile(data: CloudSyncFile): void {
    const path = CloudSyncManager.filePath()
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, JSON.stringify(data))
    fs.closeSync(file)
  }

  /**
   * 增量合并：按 id 取 updatedAt 较大者；墓碑 deletedAt >= updatedAt 时删除生效
   */
  static mergeSources(local: SourceConfig[], cloud: CloudSyncFile | null): SourceConfig[] {
    const map = new Map<ID, SourceConfig>()
    local.forEach((s: SourceConfig) => {
      map.set(s.id, s)
    })
    if (cloud) {
      cloud.sources.forEach((cs: SourceConfig) => {
        const ls = map.get(cs.id)
        if (!ls || (cs.updatedAt ?? 0) >= (ls.updatedAt ?? 0)) {
          map.set(cs.id, cs)
        }
      })
      // 墓碑合并后统一生效
      const tombMap = CloudSyncManager.mergeTombstones(cloud.tombstones, [])
      tombMap.forEach((deletedAt: number, id: ID) => {
        const s = map.get(id)
        if (s && (s.updatedAt ?? 0) <= deletedAt) {
          map.delete(id)
        }
      })
    }
    return Array.from(map.values())
  }

  /** 墓碑并集：同 id 取 deletedAt 较大者 */
  private static mergeTombstones(base: CloudTombstone[], extra: CloudTombstone[]): Map<ID, number> {
    const tombMap = new Map<ID, number>()
    base.concat(extra).forEach((t: CloudTombstone) => {
      const prev = tombMap.get(t.id) ?? 0
      if (t.deletedAt > prev) {
        tombMap.set(t.id, t.deletedAt)
      }
    })
    return tombMap
  }

  /** 展示列表合并：本地 show ∪ 云端 showIds，过滤已不存在的源 */
  private static mergeShowSources(merged: SourceConfig[], cloud: CloudSyncFile | null): SourceConfig[] {
    const idSet = new Set<ID>()
    PreferencesCache.getShowUserDataSource().forEach((s: SourceConfig) => idSet.add(s.id))
    cloud?.showIds?.forEach((id: ID) => idSet.add(id))
    return merged.filter((s: SourceConfig) => idSet.has(s.id))
  }

  /**
   * 拉取：云端文件与本地合并后写回 PreferencesCache（UI 经 AppStorage 自动联动）
   * @returns 合并后的数据源数量；无云端文件返回 -1
   */
  static async pullFromCloud(): Promise<number> {
    const cloud = await CloudSyncManager.readCloudFile()
    if (!cloud) {
      return -1
    }
    const merged = CloudSyncManager.mergeSources(PreferencesCache.getUserDataSource(), cloud)
    PreferencesCache.setUserDataSource(merged)
    PreferencesCache.setShowUserDataSource(CloudSyncManager.mergeShowSources(merged, cloud))
    LogUtil.info(`[${TAG}]`, `pullFromCloud done, merged ${merged.length} sources`)
    return merged.length
  }

  /**
   * 拉取选中的云端源到本地（导入场景：取云端版本覆盖/新增，同时加入展示列表）
   * @returns 实际导入数量
   */
  static async importCloudSources(ids: ID[]): Promise<number> {
    const cloud = await CloudSyncManager.readCloudFile()
    if (!cloud || ids.length === 0) {
      return 0
    }
    const idSet = new Set<ID>(ids)
    const picked = cloud.sources.filter((s: SourceConfig) => idSet.has(s.id))
    if (picked.length === 0) {
      return 0
    }
    const localMap = new Map<ID, SourceConfig>()
    PreferencesCache.getUserDataSource().forEach((s: SourceConfig) => localMap.set(s.id, s))
    picked.forEach((s: SourceConfig) => localMap.set(s.id, s))
    const merged = Array.from(localMap.values())
    PreferencesCache.setUserDataSource(merged)

    const showMap = new Map<ID, SourceConfig>()
    PreferencesCache.getShowUserDataSource().forEach((s: SourceConfig) => showMap.set(s.id, s))
    picked.forEach((s: SourceConfig) => showMap.set(s.id, s))
    PreferencesCache.setShowUserDataSource(Array.from(showMap.values()))
    LogUtil.info(`[${TAG}]`, `importCloudSources done, imported ${picked.length} sources`)
    return picked.length
  }

  /**
   * 推送：重新读取云端最新文件 → 合并本地更改 → revision+1 写回 → 触发系统同步上云
   * @param onlyIds 仅合并这些本地源（不传则合并全部本地源）
   * @param deleteIds 需要在云端删除的源 id（写入墓碑）
   * @returns 写入的 revision；失败返回 -1
   */
  static async pushToCloud(onlyIds?: ID[], deleteIds: ID[] = []): Promise<number> {
    if (!CloudSyncManager.isSupported()) {
      return -1
    }
    try {
      const existing = await CloudSyncManager.readCloudFile()
      const now = Date.now()
      const pushSet = onlyIds && onlyIds.length > 0 ? new Set<ID>(onlyIds) : null

      // 显式推送即「复活」：若某源的墓碑比其 updatedAt 新（此前被云端删除），
      // 则 touch updatedAt 为当前时间并写回本地，避免合并时被旧墓碑再次判删
      const preTombMap = CloudSyncManager.mergeTombstones(existing?.tombstones ?? [], [])
      const localAll = PreferencesCache.getUserDataSource()
      let touched = false
      localAll.forEach((s: SourceConfig) => {
        if (pushSet && !pushSet.has(s.id)) {
          return
        }
        const deletedAt = preTombMap.get(s.id)
        if (deletedAt !== undefined && deletedAt > (s.updatedAt ?? 0)) {
          s.updatedAt = now
          touched = true
        }
      })
      if (touched) {
        PreferencesCache.setUserDataSource(localAll)
      }

      let local = localAll
      if (pushSet) {
        local = localAll.filter((s: SourceConfig) => pushSet.has(s.id))
      }
      const merged = CloudSyncManager.mergeSources(local, existing)

      // 墓碑：历史墓碑 + 本次删除
      const extraTombs: CloudTombstone[] = deleteIds.map((id: ID) => {
        const t: CloudTombstone = { id: id, deletedAt: now }
        return t
      })
      const tombMap = CloudSyncManager.mergeTombstones(existing?.tombstones ?? [], extraTombs)
      // 删除生效于合并结果（无论 updatedAt 新旧，显式删除优先）
      deleteIds.forEach((id: ID) => {
        const idx = merged.findIndex((s: SourceConfig) => s.id === id)
        if (idx !== -1) {
          merged.splice(idx, 1)
        }
      })

      // showIds：合并后仍存在的源
      const showIdSet = new Set<ID>()
      PreferencesCache.getShowUserDataSource().forEach((s: SourceConfig) => showIdSet.add(s.id))
      existing?.showIds?.forEach((id: ID) => showIdSet.add(id))
      deleteIds.forEach((id: ID) => showIdSet.delete(id))
      const mergedIds = new Set<ID>(merged.map((s: SourceConfig) => s.id))
      const showIds: ID[] = Array.from(showIdSet).filter((id: ID) => mergedIds.has(id))

      const revision = (existing?.revision ?? 0) + 1
      const data: CloudSyncFile = {
        formatVersion: FORMAT_VERSION,
        revision: revision,
        updatedAt: now,
        deviceId: CloudSyncManager.deviceId(),
        sources: merged,
        showIds: showIds,
        tombstones: Array.from(tombMap.entries()).map((entry: [ID, number]) => {
          const t: CloudTombstone = { id: entry[0], deletedAt: entry[1] }
          return t
        })
      }
      CloudSyncManager.writeCloudFile(data)
      CloudSyncManager.triggerSync()
      LogUtil.info(`[${TAG}]`, `pushToCloud done, revision=${revision}, sources=${merged.length}`)
      return revision
    } catch (e) {
      LogUtil.error(`[${TAG}]`, `pushToCloud failed: ${JSON.stringify(e)}`)
      return -1
    }
  }

  /** 从云端删除指定数据源（写墓碑并推送） */
  static async deleteCloudSources(ids: ID[]): Promise<number> {
    return CloudSyncManager.pushToCloud(undefined, ids)
  }

  /** 最后一次触发同步的状态与错误码（-1 表示尚未触发过） */
  static lastSyncState: number = -1
  static lastSyncError: number = -1

  /** 触发整机云同步（系统空闲时也会自动同步，这里主动触发一次） */
  static triggerSync(): void {
    if (!CloudSyncManager.isSupported()) {
      return
    }
    try {
      if (!CloudSyncManager.fileSync) {
        CloudSyncManager.fileSync = new cloudSync.FileSync()
        CloudSyncManager.fileSync.on('progress', (pg: cloudSync.SyncProgress) => {
          CloudSyncManager.lastSyncState = pg.state
          CloudSyncManager.lastSyncError = pg.error
          LogUtil.info(`[${TAG}]`, `FileSync progress: state=${pg.state}, error=${pg.error}`)
        })
      }
      CloudSyncManager.fileSync.start()
        .then(() => LogUtil.info(`[${TAG}]`, 'FileSync start success'))
        .catch((e: Error) => LogUtil.warn(`[${TAG}]`, `FileSync start failed: ${JSON.stringify(e)}`))
    } catch (e) {
      LogUtil.warn(`[${TAG}]`, `triggerSync failed: ${JSON.stringify(e)}`)
    }
  }

  /**
   * 上云健康检查：触发同步后轮询文件 location。
   * @returns 'ok' 已上云 / 'not_synced' 一直仅本地（可能未登录账号或未开云空间同步开关）
   *          / 'no_file' 同步文件不存在 / 'unsupported' 设备不支持
   */
  static async checkUploadHealth(): Promise<string> {
    if (!CloudSyncManager.isSupported()) {
      return 'unsupported'
    }
    const path = CloudSyncManager.filePath()
    try {
      if (!fs.accessSync(path)) {
        return 'no_file'
      }
    } catch (e) {
      return 'no_file'
    }
    // 仅云端（元数据已下行）或本地&云端都算正常
    const loc = CloudSyncManager.fileLocation(path)
    if (loc === 2 || loc === 3) {
      return 'ok'
    }
    CloudSyncManager.triggerSync()
    for (let i = 0; i < 6; i++) {
      await CloudSyncManager.sleep(1500)
      const cur = CloudSyncManager.fileLocation(path)
      if (cur === 2 || cur === 3) {
        return 'ok'
      }
    }
    return 'not_synced'
  }

  /** 拉起系统设置（云空间页），供用户开启 设置→云空间 中本应用的同步开关 */
  static async openCloudSpaceSettings(): Promise<boolean> {
    try {
      const context = AppUtil.getContext() as common.UIAbilityContext
      const want: Want = {
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility'
      }
      await context.startAbility(want)
      return true
    } catch (e) {
      LogUtil.error(`[${TAG}]`, `openCloudSpaceSettings failed: ${JSON.stringify(e)}`)
      return false
    }
  }

  /** 云端状态快照（页面展示用） */
  static async getCloudStatus(): Promise<CloudSyncStatus> {
    const status: CloudSyncStatus = {
      supported: CloudSyncManager.isSupported(),
      fileExists: false,
      revision: 0,
      updatedAt: 0,
      location: -1,
      sourceCount: 0
    }
    if (!status.supported) {
      return status
    }
    try {
      status.fileExists = fs.accessSync(CloudSyncManager.filePath())
    } catch (e) {
      status.fileExists = false
    }
    if (status.fileExists) {
      status.location = CloudSyncManager.fileLocation(CloudSyncManager.filePath())
      const cloud = await CloudSyncManager.readCloudFile()
      if (cloud) {
        status.revision = cloud.revision
        status.updatedAt = cloud.updatedAt
        status.sourceCount = cloud.sources.length
      }
    }
    return status
  }
}
