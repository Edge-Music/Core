import { fileIo as fs } from '@kit.CoreFileKit';
import { AudioTag } from './AudioTag';
import { concatBytes } from './ByteReader';
import { parseId3v2, buildId3v2 } from './Id3v2';
import { parseFlac, buildFlacWithTag } from './FlacTag';

/**
 * 音频标签读写服务：支持 MP3(ID3v2.3) 与 FLAC(Vorbis Comment)
 */
export class AudioTagService {
  /**
   * 读取文件全部字节
   */
  private static readFileBytes(uri: string): Uint8Array | null {
    let file: fs.File | null = null;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const size: number = Number(stat.size);
      if (size <= 0) {
        return null;
      }
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, buffer);
      return new Uint8Array(buffer);
    } catch (err) {
      console.error(`AudioTagService readFileBytes failed: ${JSON.stringify(err)}`);
      return null;
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (e) {
          console.error(`AudioTagService close failed: ${JSON.stringify(e)}`);
        }
      }
    }
  }

  /**
   * 读取音频文件标签
   */
  static readTag(uri: string): AudioTag | null {
    const data: Uint8Array | null = AudioTagService.readFileBytes(uri);
    if (data === null || data.length < 8) {
      return null;
    }
    if (AudioTagService.isFlacData(data)) {
      const result: [AudioTag, number] = parseFlac(data);
      if (result[1] < 0) {
        return null;
      }
      return result[0];
    }
    const result: [AudioTag, number] = parseId3v2(data);
    return result[0];
  }

  private static isFlacData(data: Uint8Array): boolean {
    return data.length >= 4 &&
      data[0] === 0x66 && data[1] === 0x4C && data[2] === 0x61 && data[3] === 0x43;
  }

  /**
   * 构建带标签的音频字节数组，不直接写入文件，供保存到用户指定位置使用
   */
  static exportTag(uri: string, tag: AudioTag): Uint8Array | null {
    const data: Uint8Array | null = AudioTagService.readFileBytes(uri);
    if (data === null || data.length < 8) {
      return null;
    }
    if (AudioTagService.isFlacData(data)) {
      return buildFlacWithTag(data, tag);
    }
    const parseResult: [AudioTag, number] = parseId3v2(data);
    const audioStart: number = parseResult[1];
    const newTag: Uint8Array = buildId3v2(tag);
    return concatBytes([newTag, data.slice(audioStart)]);
  }
}
