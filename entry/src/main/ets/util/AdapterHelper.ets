import { Playlist } from '../type/Adapter'

export function cover(url?: string | Resource, size = 100): string | Resource{
  if(typeof url === 'string') {
    // 如果使用的是https://ui-avatars.com，则直接返回
    if (url.indexOf('ui-avatars.com') !== -1) {
      return url as string;
    }
    // cover:// 协议无法直接加载（需歌单歌曲上下文，见 playlistCover）
    if (url.indexOf('cover://') === 0) {
      return '';
    }
    return `${url}?param=${size}y${size}`
  } else {
    return url as Resource
  }
}

/**
 * 歌单封面解析：支持 cover://N 协议——N 表示取歌单第 N 首歌的专辑封面。
 * 无 songs 上下文（如榜单未加载详情）时 cover://N 无法解析，回退空串。
 */
export function playlistCover(pl?: Playlist, size = 100): string | Resource {
  if (!pl) {
    return ''
  }
  const c: string | Resource | undefined = pl.cover
  if (typeof c === 'string' && c.indexOf('cover://') === 0) {
    const idx: number = parseInt(c.substring('cover://'.length))
    const songs = pl.songs
    if (songs && !isNaN(idx) && idx >= 0 && idx < songs.length) {
      return cover(songs[idx]?.album?.cover ?? '', size)
    }
    // 兜底：取第一首
    if (songs && songs.length > 0) {
      return cover(songs[0]?.album?.cover ?? '', size)
    }
    return ''
  }
  return cover(c, size)
}

/**
 * 判断歌单是否有可解析的真实封面。
 * 用于决定是否回退到颜色块占位（如 key_ 特殊歌单、cover://N 无 songs 上下文时）。
 * 注意：cover('') 会返回 '?param=...' 非空串，故不能仅凭 playlistCover 结果判空。
 */
export function hasResolvableCover(pl?: Playlist): boolean {
  if (!pl) {
    return false
  }
  const c: string | Resource | undefined = pl.cover
  if (c === undefined || c === null) {
    return false
  }
  if (typeof c !== 'string') {
    return true // Resource 封面
  }
  if (c.length === 0) {
    return false
  }
  if (c.indexOf('cover://') === 0) {
    const songs = pl.songs
    if (!songs || songs.length === 0) {
      return false
    }
    const idx: number = parseInt(c.substring('cover://'.length))
    const target = (!isNaN(idx) && idx >= 0 && idx < songs.length) ? songs[idx] : songs[0]
    const ac = target?.album?.cover
    return typeof ac === 'string' ? ac.length > 0 : !!ac
  }
  return true
}

/**
 * 歌单「N 首」展示文本。
 * key_ 开头的特殊歌单（今日推荐/私人FM 等）常无 size 或为 0（动态内容未加载），
 * 此时返回空串，由调用方隐藏计数，避免出现无意义的「0 首」。
 */
export function playlistCountText(pl?: Playlist): string {
  if (!pl) {
    return ''
  }
  const n: number = pl.size ?? (pl.songs ? pl.songs.length : 0)
  const isKey: boolean = typeof pl.id === 'string' && (pl.id as string).startsWith('key_')
  if (isKey && (!n || n <= 0)) {
    return ''
  }
  return `${n} 首`
}

export function shuffle<T>(arr: T[], count: number = arr.length): T[] {
  const shuffled = [...arr].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}