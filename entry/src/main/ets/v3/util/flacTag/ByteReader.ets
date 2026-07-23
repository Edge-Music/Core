import { util } from '@kit.ArkTS';

/**
 * 二进制数据读取辅助类
 */
export class ByteReader {
  private buf: Uint8Array;
  private pos: number = 0;

  constructor(data: Uint8Array, offset: number = 0) {
    this.buf = data;
    this.pos = offset;
  }

  get remaining(): number {
    return this.buf.length - this.pos;
  }

  get position(): number {
    return this.pos;
  }

  skip(count: number): void {
    this.pos = Math.min(this.pos + count, this.buf.length);
  }

  peekByte(): number {
    if (this.pos >= this.buf.length) {
      return -1;
    }
    return this.buf[this.pos];
  }

  readByte(): number {
    if (this.pos >= this.buf.length) {
      return -1;
    }
    const v: number = this.buf[this.pos];
    this.pos += 1;
    return v;
  }

  readBytes(count: number): Uint8Array {
    const end: number = Math.min(this.pos + count, this.buf.length);
    const slice: Uint8Array = this.buf.slice(this.pos, end);
    this.pos = end;
    return slice;
  }

  readU32BE(): number {
    const b0: number = this.readByte();
    const b1: number = this.readByte();
    const b2: number = this.readByte();
    const b3: number = this.readByte();
    return b0 * 16777216 + b1 * 65536 + b2 * 256 + b3;
  }

  readU32LE(): number {
    const b0: number = this.readByte();
    const b1: number = this.readByte();
    const b2: number = this.readByte();
    const b3: number = this.readByte();
    return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216;
  }

  /** 读取 ID3v2 头部使用的同步安全整数（每字节仅低 7 位有效） */
  readSyncSafeInt(): number {
    const b0: number = this.readByte() & 0x7F;
    const b1: number = this.readByte() & 0x7F;
    const b2: number = this.readByte() & 0x7F;
    const b3: number = this.readByte() & 0x7F;
    return b0 * 2097152 + b1 * 16384 + b2 * 128 + b3;
  }

  readAscii(count: number): string {
    const bytes: Uint8Array = this.readBytes(count);
    let out: string = '';
    for (let i: number = 0; i < bytes.length; i++) {
      out += String.fromCharCode(bytes[i]);
    }
    return out;
  }

  readUtf8(count: number): string {
    const bytes: Uint8Array = this.readBytes(count);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes, { stream: false });
  }

  readU16LE(): number {
    const b0: number = this.readByte();
    const b1: number = this.readByte();
    return b0 + b1 * 256;
  }

  readU16BE(): number {
    const b0: number = this.readByte();
    const b1: number = this.readByte();
    return b0 * 256 + b1;
  }
}

/**
 * 将多个 Uint8Array 拼接为一个
 */
export function concatBytes(parts: Uint8Array[]): Uint8Array {
  let total: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    total += parts[i].length;
  }
  const out: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    out.set(parts[i], offset);
    offset += parts[i].length;
  }
  return out;
}
