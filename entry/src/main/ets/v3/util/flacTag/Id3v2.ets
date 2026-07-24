import { util } from '@kit.ArkTS';
import { AudioTag } from './AudioTag';
import { ByteReader, concatBytes } from './ByteReader';

/**
 * ID3v2.3 / ID3v2.4 标签解析与 ID3v2.3 标签构造（用于 MP3）
 *
 * 关键说明：
 * ID3v2.3 不支持 UTF-8 文本编码标识。写入中文时应使用 encoding=0x01，
 * 并真实写入 UTF-16LE 字节，而不是 UTF-8 字节。
 */
const FRAME_TIT2: string = 'TIT2';
const FRAME_TPE1: string = 'TPE1';
const FRAME_TALB: string = 'TALB';
const FRAME_USLT: string = 'USLT';
const FRAME_APIC: string = 'APIC';

function decodeUtf8(data: Uint8Array): string {
  try {
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(data, { stream: false });
  } catch (err) {
    return '';
  }
}

function decodeLatin1(data: Uint8Array): string {
  let result: string = '';
  for (let i: number = 0; i < data.length; i++) {
    result += String.fromCharCode(data[i]);
  }
  return result;
}

function decodeUtf16Le(data: Uint8Array): string {
  let result: string = '';
  for (let i: number = 0; i + 1 < data.length; i += 2) {
    const code: number = data[i] | (data[i + 1] << 8);
    result += String.fromCharCode(code);
  }
  return result;
}

function decodeUtf16Be(data: Uint8Array): string {
  let result: string = '';
  for (let i: number = 0; i + 1 < data.length; i += 2) {
    const code: number = (data[i] << 8) | data[i + 1];
    result += String.fromCharCode(code);
  }
  return result;
}

function decodeUtf16WithBom(data: Uint8Array): string {
  if (data.length >= 2) {
    // FF FE = UTF-16LE，FE FF = UTF-16BE
    if (data[0] === 0xFF && data[1] === 0xFE) {
      return decodeUtf16Le(data.slice(2));
    }
    if (data[0] === 0xFE && data[1] === 0xFF) {
      return decodeUtf16Be(data.slice(2));
    }

    // 无 BOM 时做一个简单判断：00 xx 通常是 UTF-16BE ASCII。
    if (data[0] === 0x00 && data[1] !== 0x00) {
      return decodeUtf16Be(data);
    }
  }
  // 兼容多数无 BOM 的 ID3v2.3 UTF-16LE 标签。
  return decodeUtf16Le(data);
}

function decodeByEncoding(data: Uint8Array, encoding: number): string {
  if (encoding === 0x00) {
    // ID3v2.3：ISO-8859-1
    return decodeLatin1(data);
  }
  if (encoding === 0x01) {
    // ID3v2.3/v2.4：UTF-16，通常带 BOM
    return decodeUtf16WithBom(data);
  }
  if (encoding === 0x02) {
    // ID3v2.4：UTF-16BE
    return decodeUtf16Be(data);
  }
  // ID3v2.4：UTF-8。对于未知编码也按 UTF-8 尝试，提升容错性。
  return decodeUtf8(data);
}

function trimNullEnd(text: string): string {
  let result: string = text;
  while (result.length > 0 && result.charCodeAt(result.length - 1) === 0) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

function decodeTextFrame(data: Uint8Array): string {
  if (data.length === 0) {
    return '';
  }
  const encoding: number = data[0];
  const body: Uint8Array = data.slice(1);
  return trimNullEnd(decodeByEncoding(body, encoding));
}

function decodeUslt(data: Uint8Array): string {
  // USLT 结构：encoding(1) + language(3) + content descriptor + text
  if (data.length < 4) {
    return '';
  }

  const encoding: number = data[0];
  let pos: number = 4;

  if (encoding === 0x01 || encoding === 0x02) {
    // UTF-16 描述字段以 00 00 结束。
    // 有些文件的描述字段前会带 BOM，先按 BOM 跳过。
    if (encoding === 0x01 && pos + 1 < data.length &&
      ((data[pos] === 0xFF && data[pos + 1] === 0xFE) ||
        (data[pos] === 0xFE && data[pos + 1] === 0xFF))) {
      pos += 2;
    }

    while (pos + 1 < data.length) {
      if (data[pos] === 0x00 && data[pos + 1] === 0x00) {
        pos += 2;
        break;
      }
      pos += 2;
    }
  } else {
    // ISO-8859-1 / UTF-8 描述字段以 00 结束。
    while (pos < data.length && data[pos] !== 0x00) {
      pos++;
    }
    pos++;
  }

  if (pos >= data.length) {
    return '';
  }
  return trimNullEnd(decodeByEncoding(data.slice(pos), encoding));
}

function decodeApic(data: Uint8Array): Uint8Array | null {
  if (data.length < 4) {
    return null;
  }

  const encoding: number = data[0];
  let pos: number = 1;

  // 跳过 MIME 类型
  while (pos < data.length && data[pos] !== 0x00) {
    pos++;
  }
  pos++;

  if (pos >= data.length) {
    return null;
  }

  // 图片类型
  pos++;

  // 跳过描述（按编码处理终止符）
  if (encoding === 0x01 || encoding === 0x02) {
    while (pos + 1 < data.length) {
      if (data[pos] === 0x00 && data[pos + 1] === 0x00) {
        pos += 2;
        break;
      }
      pos += 2;
    }
  } else {
    while (pos < data.length && data[pos] !== 0x00) {
      pos++;
    }
    pos++;
  }

  if (pos >= data.length) {
    return null;
  }
  return data.slice(pos);
}

/**
 * 解析 MP3 文件头部的 ID3v2 标签
 * @returns [标签, 标签区总大小(字节)，无标签时为 0]
 */
export function parseId3v2(data: Uint8Array): [AudioTag, number] {
  const tag: AudioTag = new AudioTag();
  if (data.length < 10 || data[0] !== 0x49 || data[1] !== 0x44 || data[2] !== 0x33) {
    return [tag, 0];
  }

  const majorVersion: number = data[3];
  const reader: ByteReader = new ByteReader(data, 6);
  const tagSize: number = reader.readSyncSafeInt();
  const totalSize: number = tagSize + 10;
  let pos: number = 10;
  const end: number = Math.min(totalSize, data.length);

  while (pos + 10 <= end) {
    const id: string = String.fromCharCode(data[pos], data[pos + 1], data[pos + 2], data[pos + 3]);
    if (data[pos] === 0x00) {
      break;
    }

    let frameSize: number = 0;
    if (majorVersion >= 4) {
      // v2.4 帧大小为同步安全整数
      frameSize = ((data[pos + 4] & 0x7F) * 2097152) +
        ((data[pos + 5] & 0x7F) * 16384) +
        ((data[pos + 6] & 0x7F) * 128) +
        (data[pos + 7] & 0x7F);
    } else {
      // v2.3 帧大小为普通 32 位大端整数
      frameSize = data[pos + 4] * 16777216 +
        data[pos + 5] * 65536 +
        data[pos + 6] * 256 +
        data[pos + 7];
    }

    if (frameSize <= 0 || pos + 10 + frameSize > end) {
      break;
    }

    const frameData: Uint8Array = data.slice(pos + 10, pos + 10 + frameSize);
    if (id === FRAME_TIT2) {
      tag.title = decodeTextFrame(frameData);
    } else if (id === FRAME_TPE1) {
      tag.artist = decodeTextFrame(frameData);
    } else if (id === FRAME_TALB) {
      tag.album = decodeTextFrame(frameData);
    } else if (id === FRAME_USLT) {
      tag.lyrics = decodeUslt(frameData);
    } else if (id === FRAME_APIC) {
      const pic: Uint8Array | null = decodeApic(frameData);
      if (pic !== null && pic.length > 0) {
        tag.cover = pic;
      }
    }

    pos += 10 + frameSize;
  }

  return [tag, totalSize];
}

/**
 * 将 ArkTS 字符串按 UTF-16LE 编码。
 * charCodeAt 返回 UTF-16 code unit，因此可以直接按小端拆成两个字节。
 * 对中文、Emoji 和代理对都有效。
 */
function encodeUtf16Le(text: string): Uint8Array {
  const out: Uint8Array = new Uint8Array(text.length * 2);
  for (let i: number = 0; i < text.length; i++) {
    const code: number = text.charCodeAt(i);
    out[i * 2] = code & 0xFF;
    out[i * 2 + 1] = (code >> 8) & 0xFF;
  }
  return out;
}

function buildTextFrameBody(text: string): Uint8Array {
  // encoding=0x01 + BOM(FF FE) + 真正的 UTF-16LE 字节
  const content: Uint8Array = encodeUtf16Le(text);
  const out: Uint8Array = new Uint8Array(3 + content.length);
  out[0] = 0x01;
  out[1] = 0xFF;
  out[2] = 0xFE;
  out.set(content, 3);
  return out;
}

function buildFrame(id: string, body: Uint8Array): Uint8Array {
  const out: Uint8Array = new Uint8Array(10 + body.length);
  for (let i: number = 0; i < 4; i++) {
    out[i] = id.charCodeAt(i);
  }

  // ID3v2.3 帧大小是普通 32 位大端整数，不是同步安全整数。
  const size: number = body.length;
  out[4] = (size >> 24) & 0xFF;
  out[5] = (size >> 16) & 0xFF;
  out[6] = (size >> 8) & 0xFF;
  out[7] = size & 0xFF;
  out.set(body, 10);
  return out;
}

function buildUsltBody(text: string): Uint8Array {
  // encoding(1) + language(3) + descriptor BOM(2) + empty descriptor(2) + text BOM(2) + UTF-16LE text
  // 注意：FFmpeg 等解析器要求 UTF-16 的描述字段也带 BOM，不能只用 00 00。
  const content: Uint8Array = encodeUtf16Le(text);
  const out: Uint8Array = new Uint8Array(10 + content.length);

  out[0] = 0x01;
  out[1] = 0x65; // e
  out[2] = 0x6E; // n
  out[3] = 0x67; // g

  // 空描述：BOM + UTF-16 null terminator
  out[4] = 0xFF;
  out[5] = 0xFE;
  out[6] = 0x00;
  out[7] = 0x00;

  // 歌词正文：BOM + UTF-16LE
  out[8] = 0xFF;
  out[9] = 0xFE;
  out.set(content, 10);
  return out;
}

function detectApicMime(image: Uint8Array): string {
  // PNG：89 50 4E 47 0D 0A 1A 0A
  if (image.length >= 8 &&
    image[0] === 0x89 &&
    image[1] === 0x50 &&
    image[2] === 0x4E &&
    image[3] === 0x47 &&
    image[4] === 0x0D &&
    image[5] === 0x0A &&
    image[6] === 0x1A &&
    image[7] === 0x0A) {
    return 'image/png';
  }

  // 默认按 JPEG 处理
  return 'image/jpeg';
}

function buildApicBody(image: Uint8Array): Uint8Array {
  const mime: string = detectApicMime(image);
  const out: Uint8Array = new Uint8Array(1 + mime.length + 3 + image.length);

  // 描述字段使用 ISO-8859-1 空描述，兼容性最好。
  out[0] = 0x00;
  for (let i: number = 0; i < mime.length; i++) {
    out[1 + i] = mime.charCodeAt(i);
  }
  out[1 + mime.length] = 0x00;
  out[1 + mime.length + 1] = 0x03; // 图片类型：封面(前)
  out[1 + mime.length + 2] = 0x00; // 空描述
  out.set(image, 1 + mime.length + 3);
  return out;
}

/**
 * 构造 ID3v2.3 标签（仅包含有内容的字段）
 */
export function buildId3v2(tag: AudioTag): Uint8Array {
  const frames: Uint8Array[] = [];

  if (tag.title.length > 0) {
    frames.push(buildFrame(FRAME_TIT2, buildTextFrameBody(tag.title)));
  }
  if (tag.artist.length > 0) {
    frames.push(buildFrame(FRAME_TPE1, buildTextFrameBody(tag.artist)));
  }
  if (tag.album.length > 0) {
    frames.push(buildFrame(FRAME_TALB, buildTextFrameBody(tag.album)));
  }
  if (tag.lyrics.length > 0) {
    frames.push(buildFrame(FRAME_USLT, buildUsltBody(tag.lyrics)));
  }
  if (tag.cover !== null && tag.cover.length > 0) {
    frames.push(buildFrame(FRAME_APIC, buildApicBody(tag.cover)));
  }

  const framesData: Uint8Array = concatBytes(frames);
  const size: number = framesData.length;
  const header: Uint8Array = new Uint8Array(10);

  header[0] = 0x49; // I
  header[1] = 0x44; // D
  header[2] = 0x33; // 3
  header[3] = 0x03; // ID3v2.3
  header[4] = 0x00;
  header[5] = 0x00;

  // ID3 标签头大小使用同步安全整数。
  header[6] = (size >> 21) & 0x7F;
  header[7] = (size >> 14) & 0x7F;
  header[8] = (size >> 7) & 0x7F;
  header[9] = size & 0x7F;

  const result: Uint8Array = new Uint8Array(10 + framesData.length);
  result.set(header, 0);
  result.set(framesData, 10);
  return result;
}