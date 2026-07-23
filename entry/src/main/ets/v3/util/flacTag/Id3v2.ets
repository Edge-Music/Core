import { util } from '@kit.ArkTS';
import { AudioTag } from './AudioTag';
import { ByteReader, concatBytes } from './ByteReader';

/**
 * ID3v2.3 / ID3v2.4 标签解析与 ID3v2.3 标签构造（用于 MP3）
 */
const FRAME_TIT2: string = 'TIT2';
const FRAME_TPE1: string = 'TPE1';
const FRAME_TALB: string = 'TALB';
const FRAME_USLT: string = 'USLT';
const FRAME_APIC: string = 'APIC';

function decodeTextFrame(data: Uint8Array): string {
  if (data.length === 0) {
    return '';
  }
  const encoding: number = data[0];
  const body: Uint8Array = data.slice(1);
  let text: string = '';
  if (encoding === 1) {
    // UTF-16，带 BOM
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-16le');
    text = decoder.decodeToString(body, { stream: false });
    if (text.length > 0 && text.charCodeAt(0) === 0xFEFF) {
      text = text.substring(1);
    }
  } else if (encoding === 2) {
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-16be');
    text = decoder.decodeToString(body, { stream: false });
  } else {
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    text = decoder.decodeToString(body, { stream: false });
  }
  // 去掉结尾的空字符
  while (text.length > 0 && text.charCodeAt(text.length - 1) === 0) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

function decodeUslt(data: Uint8Array): string {
  if (data.length < 4) {
    return '';
  }
  const encoding: number = data[0];
  const body: Uint8Array = data.slice(4);
  let text: string = '';
  if (encoding === 1) {
    // 跳过内容描述（UTF-16 双字节终止符）
    let i: number = 0;
    while (i + 1 < body.length) {
      if (body[i] === 0 && body[i + 1] === 0) {
        i += 2;
        break;
      }
      i += 2;
    }
    const rest: Uint8Array = body.slice(i);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-16le');
    text = decoder.decodeToString(rest, { stream: false });
    if (text.length > 0 && text.charCodeAt(0) === 0xFEFF) {
      text = text.substring(1);
    }
  } else {
    // 跳过内容描述（单字节终止符）
    let i: number = 0;
    while (i < body.length && body[i] !== 0) {
      i++;
    }
    i++;
    const rest: Uint8Array = body.slice(i);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    text = decoder.decodeToString(rest, { stream: false });
  }
  while (text.length > 0 && text.charCodeAt(text.length - 1) === 0) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

function decodeApic(data: Uint8Array): Uint8Array | null {
  if (data.length < 4) {
    return null;
  }
  const encoding: number = data[0];
  let pos: number = 1;
  // 跳过 MIME 类型
  while (pos < data.length && data[pos] !== 0) {
    pos++;
  }
  pos++;
  if (pos >= data.length) {
    return null;
  }
  // 图片类型
  pos++;
  // 跳过描述（按编码处理终止符）
  if (encoding === 1 || encoding === 2) {
    while (pos + 1 < data.length) {
      if (data[pos] === 0 && data[pos + 1] === 0) {
        pos += 2;
        break;
      }
      pos += 2;
    }
  } else {
    while (pos < data.length && data[pos] !== 0) {
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
    if (data[pos] === 0) {
      break;
    }
    let frameSize: number = 0;
    if (majorVersion >= 4) {
      // v2.4 帧大小为同步安全整数
      frameSize = ((data[pos + 4] & 0x7F) * 2097152) + ((data[pos + 5] & 0x7F) * 16384) +
        ((data[pos + 6] & 0x7F) * 128) + (data[pos + 7] & 0x7F);
    } else {
      frameSize = data[pos + 4] * 16777216 + data[pos + 5] * 65536 + data[pos + 6] * 256 + data[pos + 7];
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

function buildTextFrameBody(text: string): Uint8Array {
  // 编码标识 0x01 + BOM(FF FE) + UTF-16LE
  const encoder: util.TextEncoder = util.TextEncoder.create();
  const content: Uint8Array = encoder.encodeInto(text);
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
  const size: number = body.length;
  out[4] = (size >> 24) & 0xFF;
  out[5] = (size >> 16) & 0xFF;
  out[6] = (size >> 8) & 0xFF;
  out[7] = size & 0xFF;
  out.set(body, 10);
  return out;
}

function buildUsltBody(text: string): Uint8Array {
  // 编码标识 0x01 + 语言 eng + 空描述(00 00) + BOM + UTF-16LE
  const encoder: util.TextEncoder = util.TextEncoder.create();
  const content: Uint8Array = encoder.encodeInto(text);
  const out: Uint8Array = new Uint8Array(9 + content.length);
  out[0] = 0x01;
  out[1] = 0x65; // e
  out[2] = 0x6E; // n
  out[3] = 0x67; // g
  out[6] = 0xFF;
  out[7] = 0xFE;
  out.set(content, 8);
  return out;
}

function buildApicBody(image: Uint8Array): Uint8Array {
  const mime: string = 'image/jpeg';
  const out: Uint8Array = new Uint8Array(1 + mime.length + 3 + image.length);
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
  header[3] = 0x03; // 版本 2.3
  header[4] = 0x00;
  header[5] = 0x00;
  header[6] = (size >> 21) & 0x7F;
  header[7] = (size >> 14) & 0x7F;
  header[8] = (size >> 7) & 0x7F;
  header[9] = size & 0x7F;
  const result: Uint8Array = new Uint8Array(10 + framesData.length);
  result.set(header, 0);
  result.set(framesData, 10);
  return result;
}
