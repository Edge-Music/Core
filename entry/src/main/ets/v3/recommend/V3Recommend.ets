/**
 * OMSP 3.0 · 轻量推荐引擎（对齐设计规范 §7）
 * 三模式（fresh/familiar/default）按 §7.4 权重表对候选池打分取 Top-N 组成卡片流。
 * 端侧、无大模型：信号=行为(playCount/recency/affinity)+内容(novelty/chartBoost)。
 *
 * WS6 增强：候选池不再局限于已知缓存/历史/队列——`generateAsync` 会从播放历史的
 * 「艺术家 / 歌名关键词 / 当前歌词关键词」派生**种子词**，主动通过 `SourceAdapter.search`
 * **多数据源**扩池；容错优先（Promise.allSettled，单源无 search / 接口挂掉不阻塞整体）。
 */
import { Song, Playlist } from '../../type/Adapter'
import { SourceAdapter } from '../../adapter'
import { PlayRecordManager } from '../../util/PlayRecordManager'
import { PlayRecord } from '../../model/PlayRecord'
import { LyricsLine } from '../../util/LyricsManager'

export interface ModeWeights {
  recency: number
  frequency: number
  affinity: number
  novelty: number
  lyricAffinity: number
  chartBoost: number
  skipPenalty: number
}

interface Scored {
  song: Song
  score: number
  heard: boolean
}

export type RecMode = 'fresh' | 'familiar' | 'default'

// 关键词提取的中文停用词（极简）
const STOPWORDS: string[] = ['的', '了', '我', '你', '他', '她', '在', '是', '不', '和', '就',
  '都', '也', '要', '会', '着', '与', '之', '啊', '呀', '吧', '呢', 'feat', 'Feat', 'FEAT',
  'remix', 'Remix', 'live', 'Live', 'ver', 'Ver', 'Original', 'original']

export class V3Recommend {
  // §7.4 权重表（说明性数值，可后续做成可配置）
  private static weights(mode: RecMode): ModeWeights {
    // lyricAffinity = 内容/歌词语义相似度信号（bigram 余弦，见 contentWeight）
    if (mode === 'familiar') {
      return { recency: 0.30, frequency: 0.30, affinity: 0.25, novelty: 0.02, lyricAffinity: 0.28, chartBoost: 0.03, skipPenalty: 0.20 }
    }
    if (mode === 'fresh') {
      return { recency: 0.05, frequency: 0.05, affinity: 0.15, novelty: 0.40, lyricAffinity: 0.14, chartBoost: 0.10, skipPenalty: 0.05 }
    }
    return { recency: 0.20, frequency: 0.15, affinity: 0.20, novelty: 0.15, lyricAffinity: 0.20, chartBoost: 0.15, skipPenalty: 0.15 }
  }

  /** 供设置页权重可视化读取 */
  static weightsOf(mode: RecMode): ModeWeights {
    return V3Recommend.weights(mode)
  }

  /**
   * 同步生成（仅用本地已知池：缓存 ∪ 历史 ∪ 队列）。作为 generateAsync 的即时兜底。
   */
  static generate(mode: RecMode, topN: number = 30): Song[] {
    const recSongs: Song[] = AppStorage.get<Song[]>('index_recommend_songs') ?? []
    const queue: Song[] = AppStorage.get<Song[]>('current_playing_playlist') ?? []
    const records: PlayRecord[] = PlayRecordManager.getInstance().getAllRecords()
    // 同步版也纳入已预取的模式增量（榜单/key_歌单），让本地即时结果对 fresh/familiar 也够丰富
    const extra: Song[] = V3Recommend.modeExtra(mode)
    const pool: Song[] = V3Recommend.buildPool([recSongs, records.map((r) => r.song), queue, extra])
    return V3Recommend.scorePool(pool, mode, topN)
  }

  /** 模式增量素材（已被 prefetch 写入 AppStorage）：fresh=榜单歌曲 / familiar=推荐算法歌单歌曲 */
  private static modeExtra(mode: RecMode): Song[] {
    if (mode === 'fresh') {
      return AppStorage.get<Song[]>('v3_chart_songs') ?? []
    }
    if (mode === 'familiar') {
      return AppStorage.get<Song[]>('v3_key_songs') ?? []
    }
    return []
  }

  /**
   * 异步生成：本地池 + 主动多源搜索扩池（种子=艺术家/歌名/歌词关键词）。
   * 容错：任一搜索失败/超时不影响其余；无网络或全失败时退化为本地 generate 结果。
   */
  // sharedDiscovered：prefetch 时一次搜索的结果，供三模式共享，避免重复搜索
  static async generateAsync(mode: RecMode, topN: number = 30, sharedDiscovered?: Song[]): Promise<Song[]> {
    await PlayRecordManager.getInstance().initialize()
    // 基础池（所有模式恒有，保证任何数据源都能出结果）：推荐缓存 ∪ 历史 ∪ 队列 ∪ 多源搜索发现
    const recSongs: Song[] = AppStorage.get<Song[]>('index_recommend_songs') ?? []
    const queue: Song[] = AppStorage.get<Song[]>('current_playing_playlist') ?? []
    const records: PlayRecord[] = PlayRecordManager.getInstance().getAllRecords()
    const discovered: Song[] = sharedDiscovered ?? await V3Recommend.searchExpand(records)

    // 模式专属【增量】池（可能为空→优雅降级，仍靠基础池）
    const extra: Song[] = V3Recommend.modeExtra(mode)

    const pool: Song[] = V3Recommend.buildPool([recSongs, records.map((r) => r.song), queue, discovered, extra])
    return V3Recommend.scorePool(pool, mode, topN)
  }

  /**
   * 后台预取：拉取榜单/推荐歌单歌曲 + 预算三种模式结果，写入 AppStorage，供点击秒切。
   * 全程容错（Promise.allSettled / try-catch），任一数据源缺榜单或缺 key_ 歌单都不影响。
   */
  static async prefetchAll(): Promise<void> {
    await PlayRecordManager.getInstance().initialize()
    const records: PlayRecord[] = PlayRecordManager.getInstance().getAllRecords()
    // 1) 榜单歌曲 / 推荐歌单歌曲 / 多源搜索 —— 三者全部并行（互不阻塞）
    const settled = await Promise.allSettled([
      V3Recommend.fetchChartSongs(),
      V3Recommend.fetchKeyPlaylistSongs(),
      V3Recommend.searchExpand(records)
    ])
    const chartSongs: Song[] = settled[0].status === 'fulfilled' ? settled[0].value : []
    const keySongs: Song[] = settled[1].status === 'fulfilled' ? settled[1].value : []
    const discovered: Song[] = settled[2].status === 'fulfilled' ? settled[2].value : []
    AppStorage.setOrCreate('v3_chart_songs', chartSongs)
    AppStorage.setOrCreate('v3_key_songs', keySongs)
    // 2) 预算三模式：**共享同一份搜索结果**，避免重复搜索（同步打分，无额外网络）
    const modes: RecMode[] = ['fresh', 'familiar', 'default']
    for (const m of modes) {
      const list: Song[] = await V3Recommend.generateAsync(m, 30, discovered)
      if (list.length > 0) {
        AppStorage.setOrCreate(`v3_rec_${m}`, list)
      }
    }
  }

  /** 读取预取缓存（点击秒切用）；无缓存返回空 */
  static getCached(mode: RecMode): Song[] {
    return AppStorage.get<Song[]>(`v3_rec_${mode}`) ?? []
  }

  /** 拉取每日榜单前几张的歌曲（fresh 增量），容错 */
  private static async fetchChartSongs(): Promise<Song[]> {
    const charts: Playlist[] = AppStorage.get<Playlist[]>('index_recommend_toplist') ?? []
    if (charts.length === 0) {
      return []
    }
    const picks: Playlist[] = charts.slice(0, 3)
    const settled = await Promise.allSettled(picks.map((pl) => V3Recommend.safeDetail(pl)))
    const out: Song[] = []
    for (const r of settled) {
      if (r.status === 'fulfilled' && r.value) {
        for (const s of r.value) {
          out.push(s)
        }
      }
    }
    return out
  }

  /**
   * 熟悉模式素材：优先取用户「自己创建 / 收藏」的真实歌单（我喜欢的音乐、自建歌单等）里的歌，
   * 打乱后作为 familiar 增量——最贴近用户口味。无个人歌单时回退到算法歌单(key_/daily)。全程容错。
   */
  private static async fetchKeyPlaylistSongs(): Promise<Song[]> {
    // key_ 特殊歌单（全部）+ 随机 3 个自建/收藏歌单
    const picks: Playlist[] = V3Recommend.familiarPicks()
    if (picks.length === 0) {
      return []
    }
    // 节选而非全量：每个歌单随机取一段，避免上千首歌单一次性灌入
    const PER_PLAYLIST: number = 25
    const TOTAL_CAP: number = 80
    const settled = await Promise.allSettled(picks.slice(0, 6).map((pl) => V3Recommend.safeDetail(pl)))
    const seen: Set<string> = new Set()
    const out: Song[] = []
    for (const r of settled) {
      if (r.status === 'fulfilled' && r.value && r.value.length > 0) {
        const part: Song[] = V3Recommend.shuffle(r.value).slice(0, PER_PLAYLIST)
        for (const s of part) {
          const id: string = s?.id?.toString() ?? ''
          if (id && !seen.has(id)) {
            seen.add(id)
            out.push(s)
          }
        }
      }
    }
    return V3Recommend.shuffle(out).slice(0, TOTAL_CAP)
  }

  /** Fisher-Yates 洗牌（泛型，不改原数组） */
  private static shuffle<T>(arr: Array<T>): Array<T> {
    const a: Array<T> = arr.slice()
    for (let i = a.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1))
      const t: T = a[i]
      a[i] = a[j]
      a[j] = t
    }
    return a
  }

  /** 熟悉模式歌单选取：key_ 特殊歌单（全部，最贴合口味）+ 随机 3 个自建/收藏歌单 */
  private static familiarPicks(): Playlist[] {
    const userPl: Playlist[] = AppStorage.get<Playlist[]>('user_playlist') ?? []
    const isKey = (p: Playlist): boolean => {
      const id: string = p.id?.toString() ?? ''
      return id.startsWith('key_') || id.startsWith('daily_songs')
    }
    const keyPls: Playlist[] = userPl.filter((p) => isKey(p))
    const others: Playlist[] = V3Recommend.shuffle(userPl.filter((p) => !isKey(p))).slice(0, 3)
    return keyPls.concat(others)
  }

  /** 单个歌单详情的容错包装：只取可播歌曲，异常返回空 */
  private static async safeDetail(pl: Playlist): Promise<Song[]> {
    try {
      const detail: Playlist = await SourceAdapter.getPlaylistDetail(pl)
      return (detail.songs ?? []).filter((s) => s && s.privilege?.playable !== false)
    } catch (e) {
      return []
    }
  }

  /**
   * 队列将播完时后台续算补充（返回若干首可 insertSongs 的新歌，已排除队列内重复）。
   */
  static async topUp(mode: RecMode, count: number = 20): Promise<Song[]> {
    const queue: Song[] = AppStorage.get<Song[]>('current_playing_playlist') ?? []
    const inQueue: Set<string> = new Set(queue.map((s) => s.id.toString()))
    const gen: Song[] = await V3Recommend.generateAsync(mode, count + queue.length)
    return gen.filter((s) => !inQueue.has(s.id.toString())).slice(0, count)
  }

  /**
   * 流式推荐：不等所有接口 allSettled，各源（用户歌单详情 / 榜单详情 / 多源搜索）独立请求，
   * 哪个先返回就先经 onBatch 压入队列。seenIds 跨批次去重（含调用方传入的已有队列 id）。
   * familiar 偏向用户自建/收藏歌单，fresh 偏向榜单，default 两者兼取；三模式都追加历史搜索扩池。
   */
  static streamRecommend(mode: RecMode, seenIds: Set<string>, onBatch: (songs: Song[]) => void): void {
    const emit = (songs: Song[]): void => {
      const fresh: Song[] = []
      for (const s of songs) {
        const id: string = s?.id?.toString() ?? ''
        if (id && !seenIds.has(id) && s.privilege?.playable !== false) {
          seenIds.add(id)
          fresh.push(s)
        }
      }
      if (fresh.length > 0) {
        onBatch(fresh)
      }
    }

    const charts: Playlist[] = AppStorage.get<Playlist[]>('index_recommend_toplist') ?? []

    // 熟悉/默认：用户歌单 = key_ 特殊歌单(全部) + 随机 3 个自建/收藏，逐个详情返回即节选压入
    if (mode !== 'fresh') {
      for (const pl of V3Recommend.familiarPicks()) {
        V3Recommend.safeDetail(pl).then((songs: Song[]) => emit(V3Recommend.shuffle(songs).slice(0, 25)))
      }
    }

    // 新鲜/默认：榜单逐张详情返回即压入
    if (mode !== 'familiar') {
      for (const pl of charts.slice(0, 3)) {
        V3Recommend.safeDetail(pl).then((songs: Song[]) => emit(songs))
      }
    }

    // 需历史的部分：多源搜索种子 + 历史稀疏兜底（避免熟悉模式差异过大）
    PlayRecordManager.getInstance().initialize().then(() => {
      const records: PlayRecord[] = PlayRecordManager.getInstance().getAllRecords()
      for (const q of V3Recommend.seedQueries(records)) {
        V3Recommend.safeSearch(q).then((songs: Song[]) => emit(songs))
      }
      // 历史过少：用发现页接口兜底（榜单 + 首页推荐歌），保持熟悉模式的连贯与主流度
      if (records.length < 5) {
        if (mode === 'familiar') {
          for (const pl of charts.slice(0, 2)) {
            V3Recommend.safeDetail(pl).then((songs: Song[]) => emit(songs))
          }
        }
        const recSongs: Song[] = AppStorage.get<Song[]>('index_recommend_songs') ?? []
        if (recSongs.length > 0) {
          emit(V3Recommend.shuffle(recSongs).slice(0, 30))
        }
      }
    })
  }

  // ============ 内部：多源搜索扩池（所有种子并行搜索） ============
  private static async searchExpand(records: PlayRecord[]): Promise<Song[]> {
    const seeds: string[] = V3Recommend.seedQueries(records)
    if (seeds.length === 0) {
      return []
    }
    // 每个种子一个搜索 Promise（且 SourceAdapter.search 内部各数据源也并行）；
    // Promise.allSettled 保证任一失败/慢不阻塞其余
    const tasks: Promise<Song[]>[] = seeds.map((q) => V3Recommend.safeSearch(q))
    const settled = await Promise.allSettled(tasks)
    const out: Song[] = []
    for (const r of settled) {
      if (r.status === 'fulfilled' && r.value) {
        for (const s of r.value) {
          if (s && s.privilege?.playable !== false) {
            out.push(s)
          }
        }
      }
    }
    return out
  }

  /** 单次搜索的容错包装：任何异常都吞掉返回空，绝不抛出 */
  private static async safeSearch(query: string): Promise<Song[]> {
    try {
      const res = await SourceAdapter.search(query, 15)
      return res?.songs ?? []
    } catch (e) {
      return []
    }
  }

  /** 从播放历史派生搜索种子词：Top 艺术家 + 近期歌名关键词 + 当前歌词关键词 */
  private static seedQueries(records: PlayRecord[]): string[] {
    const seeds: string[] = []
    const seen: Set<string> = new Set()
    const add = (q: string): void => {
      const k: string = q.trim()
      if (k.length >= 2 && !seen.has(k) && seeds.length < 8) {
        seen.add(k)
        seeds.push(k)
      }
    }

    // 1) Top 艺术家（最可靠、最能扩多样性的信号——按艺术家搜到的是其作品集而非翻唱）
    for (const a of PlayRecordManager.getInstance().getTopArtists(6)) {
      add(a.artistName)
    }

    // 2) 近期歌名主标题只取少量（歌名搜索易聚集大量同名翻唱，故限 2 条，配合同名去重）
    const byRecent: PlayRecord[] = records.slice().sort((a, b) => b.lastPlayTime - a.lastPlayTime)
    for (let i = 0; i < byRecent.length && i < 2; i++) {
      const t: string = V3Recommend.mainTitle(byRecent[i].song.name ?? '')
      add(t)
    }

    // 3) 当前歌词关键词（历史歌词未持久化，用当前解析歌词兜个语义种子）
    for (const kw of V3Recommend.lyricKeywords(2)) {
      add(kw)
    }

    return seeds
  }

  /** 歌名主标题：去括号补充说明，取主体 */
  private static mainTitle(name: string): string {
    let s: string = name
    s = s.replace(/[（(【\[].*?[）)】\]]/g, ' ')
    s = s.replace(/\s*-\s*.*$/, ' ')
    return s.trim()
  }

  /** 从当前解析歌词提取高频有意义词（极简：2-4 字 token 频次，滤停用词） */
  private static lyricKeywords(limit: number): string[] {
    const lines: LyricsLine[] = AppStorage.get<LyricsLine[]>('current_parsed_lyrics') ?? []
    if (lines.length === 0) {
      return []
    }
    const freq: Map<string, number> = new Map()
    for (const ln of lines) {
      const text: string = (ln?.text ?? '').trim()
      if (!text) {
        continue
      }
      // 按非中英数字切分成词块
      const parts: string[] = text.split(/[^一-龥A-Za-z0-9]+/)
      for (const p of parts) {
        if (p.length >= 2 && p.length <= 6 && STOPWORDS.indexOf(p) < 0) {
          freq.set(p, (freq.get(p) ?? 0) + 1)
        }
      }
    }
    const arr: Array<[string, number]> = Array.from(freq.entries())
    arr.sort((a, b) => b[1] - a[1])
    return arr.slice(0, limit).map((x) => x[0])
  }

  // ============ 内部：池构建 + 打分 ============
  private static buildPool(groups: Song[][]): Song[] {
    const pool: Song[] = []
    const seen: Set<string> = new Set()
    for (const arr of groups) {
      for (const s of arr) {
        const id: string = s?.id?.toString() ?? ''
        if (id && !seen.has(id)) {
          seen.add(id)
          pool.push(s)
        }
      }
    }
    return pool
  }

  private static scorePool(pool: Song[], mode: RecMode, topN: number): Song[] {
    if (pool.length === 0) {
      return []
    }
    const records: PlayRecord[] = PlayRecordManager.getInstance().getAllRecords()
    const recSongs: Song[] = AppStorage.get<Song[]>('index_recommend_songs') ?? []

    const playCountMap: Map<string, number> = new Map()
    const recencyMap: Map<string, number> = new Map()
    let maxCount: number = 1
    let minTime: number = Number.MAX_SAFE_INTEGER
    let maxTime: number = 0
    for (const r of records) {
      const id: string = r.song.id.toString()
      playCountMap.set(id, r.playCount)
      recencyMap.set(id, r.lastPlayTime)
      if (r.playCount > maxCount) {
        maxCount = r.playCount
      }
      if (r.lastPlayTime < minTime) {
        minTime = r.lastPlayTime
      }
      if (r.lastPlayTime > maxTime) {
        maxTime = r.lastPlayTime
      }
    }
    const timeSpan: number = maxTime - minTime > 0 ? maxTime - minTime : 1

    const topArtists: Set<string> = new Set()
    for (const a of PlayRecordManager.getInstance().getTopArtists(10)) {
      topArtists.add(a.artistName)
    }
    const recIds: Set<string> = new Set()
    for (const s of recSongs) {
      recIds.add(s.id.toString())
    }

    // 口味画像（内容相似度信号）
    const profile: Map<string, number> = V3Recommend.buildProfile(records)
    const profileNorm: number = V3Recommend.norm(profile)
    const contentW: number = V3Recommend.contentWeight(mode)

    const w: ModeWeights = V3Recommend.weights(mode)
    const scored: Scored[] = pool.map((s: Song): Scored => {
      const id: string = s.id.toString()
      const heard: boolean = playCountMap.has(id)
      const frequency: number = (playCountMap.get(id) ?? 0) / maxCount
      const recency: number = heard ? ((recencyMap.get(id) ?? minTime) - minTime) / timeSpan : 0
      const affinity: number = V3Recommend.artistAffinity(s, topArtists)
      const novelty: number = heard ? 0 : 1
      const chartBoost: number = recIds.has(id) ? 1 : 0
      // 内容相似度：候选文本 vs 口味画像的字符 bigram 余弦
      const contentSim: number = V3Recommend.cosine(profile, profileNorm, V3Recommend.bigrams(V3Recommend.songText(s)))
      const score: number = w.recency * recency
        + w.frequency * frequency
        + w.affinity * affinity
        + w.novelty * novelty
        + w.chartBoost * chartBoost
        + contentW * contentSim
      return { song: s, score, heard }
    })

    scored.sort((a, b) => b.score - a.score)

    // ① 同名去重：同一「归一化标题」最多保留 1 首（去掉大量翻唱/同名版本）
    const deduped: Scored[] = V3Recommend.dedupeByTitle(scored)

    // ② 模式感知重排（让 熟悉/新鲜/默认 结果拉开差异）：
    //   熟悉=优先已听过(懂你在听什么)；新鲜=优先没听过(全是新歌)；默认=分数原序(混合)
    let ordered: Scored[] = deduped
    if (mode === 'familiar') {
      const known: Scored[] = deduped.filter((x) => x.heard)
      const rest: Scored[] = deduped.filter((x) => !x.heard)
      ordered = known.concat(rest)
    } else if (mode === 'fresh') {
      const fresh: Scored[] = deduped.filter((x) => !x.heard)
      const rest: Scored[] = deduped.filter((x) => x.heard)
      ordered = fresh.concat(rest)
    }

    return ordered.slice(0, topN).map((x) => x.song)
  }

  /** 归一化标题：小写、去括号补充、去空白与标点，用于同名去重 */
  private static normTitle(name: string): string {
    let s: string = (name ?? '').toLowerCase()
    s = s.replace(/[（(【\[].*?[）)】\]]/g, '')
    s = s.replace(/[\s\-_,·.!?、，。！？'"]/g, '')
    return s
  }

  /** 同名去重：按已排序数组贪心保留每个归一化标题的最高分那首 */
  private static dedupeByTitle(sorted: Scored[]): Scored[] {
    const out: Scored[] = []
    const titles: Set<string> = new Set()
    for (const x of sorted) {
      const t: string = V3Recommend.normTitle(x.song.name ?? '')
      if (t.length === 0) {
        out.push(x)
        continue
      }
      if (!titles.has(t)) {
        titles.add(t)
        out.push(x)
      }
    }
    return out
  }

  private static artistAffinity(song: Song, topArtists: Set<string>): number {
    if (!song.artists) {
      return 0
    }
    for (const a of song.artists) {
      if (topArtists.has(a.name)) {
        return 1
      }
    }
    return 0
  }

  // ============ 内容相似度（纯端侧、无模型）：字符 bigram 余弦 ============
  // 用「歌名 + 艺术家 + 当前歌词关键词」的字符二元组做轻量语义向量，衡量候选与口味的贴合度。
  private static contentWeight(mode: RecMode): number {
    // 与权重表统一：内容相似度即 lyricAffinity 信号
    return V3Recommend.weights(mode).lyricAffinity
  }

  private static songText(s: Song): string {
    const name: string = s.name ?? ''
    const artists: string = (s.artists ?? []).map((a) => a.name).join('')
    return (name + artists).toLowerCase()
  }

  private static bigrams(text: string): Map<string, number> {
    const m: Map<string, number> = new Map()
    const t: string = text.replace(/\s+/g, '')
    for (let i = 0; i < t.length - 1; i++) {
      const g: string = t.substring(i, i + 2)
      m.set(g, (m.get(g) ?? 0) + 1)
    }
    return m
  }

  /** 从 Top/近期播放构建口味画像 bigram 向量 */
  private static buildProfile(records: PlayRecord[]): Map<string, number> {
    const prof: Map<string, number> = new Map()
    const top: PlayRecord[] = records.slice(0, 25)
    for (const r of top) {
      const bg: Map<string, number> = V3Recommend.bigrams(V3Recommend.songText(r.song))
      const weight: number = Math.min(5, r.playCount)
      bg.forEach((c, g) => prof.set(g, (prof.get(g) ?? 0) + c * weight))
    }
    for (const kw of V3Recommend.lyricKeywords(6)) {
      const bg: Map<string, number> = V3Recommend.bigrams(kw.toLowerCase())
      bg.forEach((c, g) => prof.set(g, (prof.get(g) ?? 0) + c))
    }
    return prof
  }

  private static norm(v: Map<string, number>): number {
    let s: number = 0
    v.forEach((c) => s += c * c)
    return Math.sqrt(s)
  }

  /** 余弦相似度（0~1） */
  private static cosine(a: Map<string, number>, aNorm: number, b: Map<string, number>): number {
    if (aNorm === 0) {
      return 0
    }
    const bNorm: number = V3Recommend.norm(b)
    if (bNorm === 0) {
      return 0
    }
    let dot: number = 0
    // 遍历较小的一侧
    const small: Map<string, number> = a.size <= b.size ? a : b
    const large: Map<string, number> = a.size <= b.size ? b : a
    small.forEach((c, g) => {
      const o: number | undefined = large.get(g)
      if (o !== undefined) {
        dot += c * o
      }
    })
    return dot / (aNorm * bNorm)
  }
}
