/**
 * 音乐标签数据模型
 */
export class AudioTag {
  title: string = '';
  artist: string = '';
  album: string = '';
  lyrics: string = '';
  cover: Uint8Array | null = null;

  static copyOf(src: AudioTag): AudioTag {
    const tag: AudioTag = new AudioTag();
    tag.title = src.title;
    tag.artist = src.artist;
    tag.album = src.album;
    tag.lyrics = src.lyrics;
    tag.cover = src.cover;
    return tag;
  }

  cloneEmpty(): AudioTag {
    return new AudioTag();
  }
}
