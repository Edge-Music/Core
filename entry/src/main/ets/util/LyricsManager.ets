import { LogUtil } from "@pura/harmony-utils";
import { Song } from "../type/Adapter";
import { avPlayerManager } from "./AVPlayerManager";
import { EventHelper } from "./EventHelper";
import FormUtils from "./FormUtils";
import { PreferencesCache } from "./PreferenceCache";

export class LyricsLine {
  time: number; // 时间点（毫秒）
  text: string; // 原文歌词
  translation?: string; // 翻译
  transliteration?: string; //音译
  showTranslation?: boolean; // 是否显示翻译

  constructor(time: number, text: string, translation?: string, transliteration?: string, showTranslation?: boolean) {
    this.time = time;
    this.text = text;
    this.translation = translation;
    this.transliteration = transliteration;
    this.showTranslation = showTranslation;
  }
}

const TAG = 'LyricsManager'
class LyricsManager {
  private song: Song | undefined
  private originalLyrics: string = ''
  private translatedLyrics: string = ''
  private transliteratedLyrics: string = ''
  private hasTranslation: boolean = false
  private hasTransliteration: boolean = false
  private currentTimeMs: number = 0
  private parsedLyrics: LyricsLine[] = []
  private lyricsTimer: number = -1
  private lastIndex: number = -1
  private currentIndex: number = 0
  private BASE_PRE_TIME: number = 500 // 基础提前时间
  private PRE_HIGHLIGHT_TIME: number = 0 // 提前切换时间
  private isInit: boolean = false
  private currentSongName: string = ''

  async init(){

    this.PRE_HIGHLIGHT_TIME = PreferencesCache.currentLyricsOffsetTime() + this.BASE_PRE_TIME
    this.song = AppStorage.get<Song>('current_playing_song')
    this.originalLyrics = this.song?.meta?.lyric?.normal ?? ''
    this.translatedLyrics = this.song?.meta?.lyric?.translation ?? ''
    this.transliteratedLyrics = this.song?.meta?.lyric?.transliteration ?? ''
    let tmpSongName: string = this.song?.name + ' - ' + this.song?.artists[0].name
    let lyricsLine: LyricsLine = new LyricsLine(0, tmpSongName)
    if(this.currentSongName !== tmpSongName){
      AppStorage.setOrCreate<number>('current_lyrics_index', 0)
      this.currentSongName = tmpSongName
      FormUtils.updateCardCurrentLyrics(tmpSongName)
      // FormUtils.updateCardLyricsIndex(this.currentIndex)
      AppStorage.setOrCreate<string>('test_index', tmpSongName)
      AppStorage.setOrCreate<LyricsLine>('current_line_lyrics', lyricsLine)
      if(EventHelper.getPipLyricListenerCount() > 0){
        EventHelper.postPipLyric(tmpSongName)
      }
    }
    this.parseLyrics()
    this.isInit = true
  }

  setPreTime(preTime: number){
    this.PRE_HIGHLIGHT_TIME = this.BASE_PRE_TIME + preTime
    LogUtil.info(`${TAG}`, ` currentLyricsOffsetTime: ${preTime}`)
  }

  async start(){
    if(!this.isInit){
      this.init()
    }
    this.setLyricsInterval()
  }

  async reset(){
    this.clearLyricsInterval()
    this.song = undefined
    this.originalLyrics = ''
    this.translatedLyrics = ''
    this.transliteratedLyrics = ''
    this.currentTimeMs = 0
    this.parsedLyrics = []
    this.lastIndex = -1
    this.currentIndex = 0
    this.hasTranslation = false
    this.hasTransliteration = false
    this.isInit = false
  }

  async setLyricsInterval(){
    const player = await avPlayerManager.getAVPlayerInstance()
    this.currentTimeMs = player.currentTime

    if(this.lyricsTimer === -1){
      this.lyricsTimer = setInterval(() => {
        this.currentTimeMs = player.currentTime
        this.updateCurrentLyric()
      }, 500)
      console.info(`歌词定时器[${this.lyricsTimer}]设置完成`)
    }
  }

  clearLyricsInterval(){
    if(this.lyricsTimer !== -1){
      const tmpTimer = this.lyricsTimer
      clearInterval(this.lyricsTimer)
      this.lyricsTimer = -1
      console.info(`歌词定时器[${tmpTimer}]清除完成`)
    }
  }

  /**
   * 解析LRC格式原文歌词
   */
  private async parseLyrics() {
    LogUtil.info(`[${TAG}]`, `开始解析[${this.song?.name}]歌词`)
    // 重置状态
    this.currentIndex = 0

    if (this.originalLyrics.trim() === '') {
      this.parsedLyrics = []
      this.hasTranslation = false
      this.hasTransliteration = false
      return
    }

    // 首先解析原始歌词
    this.parsedLyrics = this.parseLyricsText(this.originalLyrics)

    // 检查是否有翻译歌词
    let translationLines: LyricsLine[] = []
    if (this.translatedLyrics && this.translatedLyrics.trim() !== '') {
      this.hasTranslation = true
      translationLines = this.parseLyricsText(this.translatedLyrics)
    }

    // 检查是否有音译歌词
    let transliteratedLines: LyricsLine[] = []
    if (this.transliteratedLyrics && this.transliteratedLyrics.trim() !== '') {
      this.hasTransliteration = true
      transliteratedLines = this.parseLyricsText(this.transliteratedLyrics)
    }

    // 合并原始歌词和翻译歌词/音译歌词
    this.parsedLyrics = this.mergeLyrics(translationLines, transliteratedLines)

    AppStorage.setOrCreate<boolean>('current_lyrics_has_translation', this.hasTranslation)
    AppStorage.setOrCreate<boolean>('current_lyrics_has_transliteration', this.hasTransliteration)
    AppStorage.setOrCreate<Array<LyricsLine>>('current_parsed_lyrics', this.parsedLyrics)
    // FormUtils.updateCardLyrics(this.parsedLyrics)
    LogUtil.info(`[${TAG}]`, `完成解析[${this.song?.name}]歌词`)
    LogUtil.info(`[${TAG}]`, `歌词：${JSON.stringify(this.parsedLyrics)}`)
  }

  /**
   * 解析单个LRC文本 - 增强版，支持共享时间戳格式
   * @param lrcText - LRC格式文本字符串
   * @returns LyricsLine[] - 包含时间戳和对应歌词的数组，按时间戳升序排序
   *
   * 支持格式：
   * 1. 标准格式：[00:12.00]歌词文本
   * 2. 共享时间戳：[00:12.00][00:17.20][00:21.10]歌词文本
   */
  private parseLyricsText(lrcText: string): LyricsLine[] {
    const lines = lrcText.split('\n')
    const timeRegex = /\[(\d{2}):(\d{2})(?:[\.:](\d{2,3}))?\]/g // 使用全局匹配
    const tempLyrics: LyricsLine[] = []

    lines.forEach((line, lineIndex) => {
      try {
        // 跳过空行
        if (!line || line.trim() === '') {
          return
        }

        // 查找所有时间戳
        const timestamps: number[] = []
        let match: RegExpExecArray | null

        // 重置正则表达式的lastIndex
        timeRegex.lastIndex = 0

        while ((match = timeRegex.exec(line)) !== null) {
          const minutes = parseInt(match[1])
          const seconds = parseInt(match[2])
          const ms = match[3] ? parseInt(match[3]) : 0

          // 统一转换为毫秒
          const time = minutes * 60 * 1000 + seconds * 1000 + (ms < 100 ? ms * 10 : ms)
          timestamps.push(time)
        }

        // 提取歌词文本（移除所有时间戳）
        const text = line.replace(/\[(\d{2}):(\d{2})(?:[\.:](\d{2,3}))?\]/g, '').trim()

        // 如果有时间戳且有歌词文本，为每个时间戳创建一个歌词行
        if (timestamps.length > 0 && text) {
          timestamps.forEach(time => {
            tempLyrics.push(new LyricsLine(time, text))
          })
        }
      } catch (error) {
        // 容错处理：跳过无法解析的行
        LogUtil.warn(`${TAG}`, `解析歌词第 ${lineIndex + 1} 行失败: ${line}, 错误: ${error}`)
      }
    })

    // 按时间排序
    return tempLyrics.sort((a, b) => a.time - b.time)
  }

  /**
   * 合并原始歌词和翻译歌词，为原始歌词添加对应的翻译
   * @param transliteratedLyrics - 音译歌词行数组
   * @param translationLyrics - 翻译歌词行数组
   * @returns LyricsLine[] - 合并后的歌词行数组，其中原始歌词行包含了对应的翻译文本
   */
  private mergeLyrics(translationLyrics: LyricsLine[], transliteratedLyrics: LyricsLine[]): LyricsLine[] {
    // 创建结果数组，深拷贝原始歌词避免引用问题
    const mergedLyrics: LyricsLine[] = JSON.parse(JSON.stringify(this.parsedLyrics))

    // 为每一行原始歌词寻找最接近的翻译行
    mergedLyrics.forEach((line, _index) => {
      // 寻找时间最接近的翻译
      let closestTranslation: LyricsLine | null = null
      let closestTransliteration: LyricsLine | null = null
      let minTimeDiff = Number.MAX_VALUE

      if(this.hasTranslation){
        translationLyrics.forEach(transLine => {
          const timeDiff = Math.abs(transLine.time - line.time)
          // 如果找到时间差更小的翻译行
          if (timeDiff < minTimeDiff) {
            minTimeDiff = timeDiff
            closestTranslation = transLine
          }
        })

        // 如果找到匹配的翻译，且时间差在合理范围内（例如50毫秒）
        if (closestTranslation !== null && minTimeDiff <= 50) {
          line.translation = (closestTranslation as LyricsLine).text
        }
      }

      minTimeDiff = Number.MAX_VALUE
      if(this.hasTransliteration){
        transliteratedLyrics.forEach(transLine => {
          const timeDiff = Math.abs(transLine.time - line.time)
          // 如果找到时间差更小的翻译行
          if (timeDiff < minTimeDiff) {
            minTimeDiff = timeDiff
            closestTransliteration = transLine
          }
        })

        // 如果找到匹配的翻译，且时间差在合理范围内（例如50毫秒）
        if (closestTransliteration !== null && minTimeDiff <= 50) {
          line.transliteration = (closestTransliteration as LyricsLine).text
        }
      }

    })

    return mergedLyrics
  }

  private updateCurrentLyric() {
    // 添加预判时间提前高亮
    const adjustedTime = this.currentTimeMs + this.PRE_HIGHLIGHT_TIME

    // 查找当前应显示的歌词
    let newIndex = -1
    for (let i = 0; i < this.parsedLyrics.length; i++) {
      if (i === this.parsedLyrics.length - 1) {
        // 最后一句
        if (adjustedTime >= this.parsedLyrics[i].time) {
          newIndex = i
          this.currentIndex = newIndex
          if(this.currentIndex !== this.lastIndex){
            this.lastIndex = this.currentIndex
            AppStorage.setOrCreate<LyricsLine>('current_line_lyrics', this.parsedLyrics[this.currentIndex])
            AppStorage.setOrCreate<string>('test_index', this.parsedLyrics[this.currentIndex].text)
            AppStorage.setOrCreate<number>('current_lyrics_index', this.currentIndex)
            // FormUtils.updateCardLyricsIndex(this.currentIndex)
            FormUtils.updateCardCurrentLyrics(this.parsedLyrics[this.currentIndex].text)
            if(EventHelper.getPipLyricListenerCount() > 0) {
              EventHelper.postPipLyric(this.parsedLyrics[this.currentIndex].text)
            }
          }
        }
      } else {
        // 非最后一句，检查是否在当前时间范围内
        if (adjustedTime >= this.parsedLyrics[i].time && adjustedTime < this.parsedLyrics[i + 1].time) {
          newIndex = i
          this.currentIndex = newIndex
          if(this.currentIndex !== this.lastIndex){
            this.lastIndex = this.currentIndex
            AppStorage.setOrCreate<LyricsLine>('current_line_lyrics', this.parsedLyrics[this.currentIndex])
            AppStorage.setOrCreate<string>('test_index', this.parsedLyrics[this.currentIndex].text)
            AppStorage.setOrCreate<number>('current_lyrics_index', this.currentIndex)
            // FormUtils.updateCardLyricsIndex(this.currentIndex)
            FormUtils.updateCardCurrentLyrics(this.parsedLyrics[this.currentIndex].text)
            if(EventHelper.getPipLyricListenerCount() > 0) {
              EventHelper.postPipLyric(this.parsedLyrics[this.currentIndex].text)
            }
          }
          break
        }
      }
    }
  }

}

export default new LyricsManager()