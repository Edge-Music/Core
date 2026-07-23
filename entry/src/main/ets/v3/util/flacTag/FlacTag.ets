import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { AudioTag } from './AudioTag';
import { ByteReader, concatBytes } from './ByteReader';

/**
 * FLAC Vorbis Comment 与 METADATA_BLOCK_PICTURE 的解析与构造。
 *
 * 端序规则：
 * 1. Metadata Block Header 的 24 位长度：大端。
 * 2. Vorbis Comment 内部的所有 32 位长度：小端。
 * 3. METADATA_BLOCK_PICTURE 内部的所有 32 位数值：大端。
 */
export class FlacBlock {
  type: number = 0;
  data: Uint8Array = new Uint8Array(0);
}

const MAX_METADATA_BLOCK_SIZE: number = 0xFFFFFF;
const FLAC_MAGIC: Uint8Array = new Uint8Array([0x66, 0x4C, 0x61, 0x43]);

function makeU32LE(value: number): Uint8Array {
  const out: Uint8Array = new Uint8Array(4);
  out[0] = value & 0xFF;
  out[1] = (value >> 8) & 0xFF;
  out[2] = (value >> 16) & 0xFF;
  out[3] = (value >> 24) & 0xFF;
  return out;
}

function writeU32BE(target: Uint8Array, offset: number, value: number): void {
  target[offset] = (value >> 24) & 0xFF;
  target[offset + 1] = (value >> 16) & 0xFF;
  target[offset + 2] = (value >> 8) & 0xFF;
  target[offset + 3] = value & 0xFF;
}

function parseBlockHeader(reader: ByteReader): [boolean, number, number] {
  const b: number = reader.readByte();
  const isLast: boolean = (b & 0x80) !== 0;
  const type: number = b & 0x7F;
  const len: number = ((reader.readByte() & 0xFF) << 16) |
    ((reader.readByte() & 0xFF) << 8) |
    (reader.readByte() & 0xFF);
  return [isLast, type, len];
}

/**
 * 严格计算 FLAC 元数据区结束位置，也就是第一个音频帧的位置。
 * 不依赖标签内容是否可解析，避免标签异常时截错音频数据。
 */
export function getFlacAudioStart(fileData: Uint8Array): number {
  if (fileData.length < 42 ||
    fileData[0] !== 0x66 || // f
    fileData[1] !== 0x4C || // L
    fileData[2] !== 0x61 || // a
    fileData[3] !== 0x43) { // C
    return -1;
  }

  let pos: number = 4;
  let blockIndex: number = 0;

  while (pos + 4 <= fileData.length) {
    const first: number = fileData[pos];
    const isLast: boolean = (first & 0x80) !== 0;
    const type: number = first & 0x7F;
    const len: number = (fileData[pos + 1] << 16) |
      (fileData[pos + 2] << 8) |
      fileData[pos + 3];

    // 第一个 Metadata Block 必须是 34 字节 STREAMINFO。
    if (blockIndex === 0 && (type !== 0 || len !== 34)) {
      return -1;
    }
    if (type === 127) {
      return -1;
    }

    pos += 4;
    if (pos + len > fileData.length) {
      return -1;
    }
    pos += len;

    if (isLast) {
      return pos;
    }
    blockIndex++;
  }

  return -1;
}

function readCommentValue(data: Uint8Array, name: string): string {
  const reader: ByteReader = new ByteReader(data);

  if (reader.remaining < 4) {
    return '';
  }
  const vendorLen: number = reader.readU32LE();
  if (vendorLen < 0 || vendorLen > reader.remaining) {
    return '';
  }
  reader.skip(vendorLen);

  if (reader.remaining < 4) {
    return '';
  }
  const count: number = reader.readU32LE();
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  const target: string = name.toUpperCase();

  for (let i: number = 0; i < count; i++) {
    if (reader.remaining < 4) {
      break;
    }
    const len: number = reader.readU32LE();
    if (len <= 0 || reader.remaining < len) {
      break;
    }

    const bytes: Uint8Array = reader.readBytes(len);
    let entry: string = '';
    try {
      entry = decoder.decodeToString(bytes, { stream: false });
    } catch (err) {
      continue;
    }

    const eq: number = entry.indexOf('=');
    if (eq > 0) {
      const key: string = entry.substring(0, eq).toUpperCase();
      if (key === target) {
        return entry.substring(eq + 1);
      }
    }
  }
  return '';
}

function parsePictureBlock(data: Uint8Array): Uint8Array | null {
  const reader: ByteReader = new ByteReader(data);
  if (reader.remaining < 32) {
    return null;
  }

  reader.readU32BE(); // 图片类型
  const mimeLen: number = reader.readU32BE();
  if (mimeLen < 0 || mimeLen > reader.remaining) {
    return null;
  }
  reader.skip(mimeLen);

  if (reader.remaining < 4) {
    return null;
  }
  const descLen: number = reader.readU32BE();
  if (descLen < 0 || descLen > reader.remaining) {
    return null;
  }
  reader.skip(descLen);

  if (reader.remaining < 20) {
    return null;
  }
  reader.readU32BE(); // 宽
  reader.readU32BE(); // 高
  reader.readU32BE(); // 色深
  reader.readU32BE(); // 颜色数

  const picLen: number = reader.readU32BE();
  if (picLen <= 0 || reader.remaining < picLen) {
    return null;
  }
  return reader.readBytes(picLen);
}

/**
 * 解析 FLAC 文件的元数据。
 * @returns [标签, 元数据区总字节数(含 fLaC 魔数)，格式非法时为 -1]
 */
export function parseFlac(fileData: Uint8Array): [AudioTag, number] {
  const tag: AudioTag = new AudioTag();
  const metadataEnd: number = getFlacAudioStart(fileData);
  if (metadataEnd < 0) {
    return [tag, -1];
  }

  const reader: ByteReader = new ByteReader(fileData, 4);
  while (reader.position < metadataEnd && reader.remaining >= 4) {
    const header: [boolean, number, number] = parseBlockHeader(reader);
    const type: number = header[1];
    const len: number = header[2];

    if (len < 0 || reader.remaining < len || reader.position + len > metadataEnd) {
      return [tag, -1];
    }

    const blockData: Uint8Array = reader.readBytes(len);
    if (type === 4) {
      tag.title = readCommentValue(blockData, 'TITLE');
      tag.artist = readCommentValue(blockData, 'ARTIST');
      tag.album = readCommentValue(blockData, 'ALBUM');
      tag.lyrics = readCommentValue(blockData, 'LYRICS');
      if (tag.lyrics.length === 0) {
        tag.lyrics = readCommentValue(blockData, 'UNSYNCEDLYRICS');
      }
    } else if (type === 6) {
      const pic: Uint8Array | null = parsePictureBlock(blockData);
      if (pic !== null && pic.length > 0) {
        tag.cover = pic;
      }
    }
  }

  return [tag, metadataEnd];
}

function encodeComment(entry: string): Uint8Array {
  const encoder: util.TextEncoder = util.TextEncoder.create();
  const content: Uint8Array = encoder.encodeInto(entry);
  const out: Uint8Array = new Uint8Array(4 + content.length);
  out.set(makeU32LE(content.length), 0);
  out.set(content, 4);
  return out;
}

/**
 * 过滤字段值中的控制字符，保留歌词需要的换行符。
 */
function sanitizeFieldValue(value: string): string {
  let result: string = '';
  for (let i: number = 0; i < value.length; i++) {
    const code: number = value.charCodeAt(i);
    if (code === 0x0A) {
      result += '\n';
    } else if (code >= 0x20 && code !== 0x7F) {
      result += value.charAt(i);
    }
  }
  return result;
}

function pushComment(entries: Uint8Array[], name: string, value: string): void {
  const safeValue: string = sanitizeFieldValue(value);
  if (safeValue.length > 0) {
    entries.push(encodeComment(name + '=' + safeValue));
  }
}

function buildVorbisCommentBlock(tag: AudioTag): Uint8Array {
  const encoder: util.TextEncoder = util.TextEncoder.create();
  const vendor: Uint8Array = encoder.encodeInto('reference libFLAC 1.3.2 20170101');
  const entries: Uint8Array[] = [];

  // TITLE、ARTIST、ALBUM 是兼容性最高的 Vorbis Comment 字段名。
  pushComment(entries, 'TITLE', tag.title);
  pushComment(entries, 'ARTIST', tag.artist);
  pushComment(entries, 'ALBUM', tag.album);

  if (tag.lyrics.length > 0) {
    const normalizedLyrics: string = tag.lyrics.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    // 歌词不是统一标准字段，同时写两个常见名称以兼容不同播放器。
    pushComment(entries, 'LYRICS', normalizedLyrics);
    pushComment(entries, 'UNSYNCEDLYRICS', normalizedLyrics);
  }

  /**
   * 关键修复：
   * Vorbis Comment 的正确顺序必须是：
   * vendor_length -> vendor_string -> comment_count -> comments...
   *
   * 原代码错误地拼成：
   * vendor_length -> comment_count -> vendor_string -> comments...
   * 这会导致播放器把 vendor 的一部分当成 comment_count，最终无法识别任何
   * TITLE、ARTIST、ALBUM 和 LYRICS 字段。
   */
  const parts: Uint8Array[] = [];
  parts.push(makeU32LE(vendor.length));
  parts.push(vendor);
  parts.push(makeU32LE(entries.length));
  for (let i: number = 0; i < entries.length; i++) {
    parts.push(entries[i]);
  }
  return concatBytes(parts);
}

function detectImageMime(image: Uint8Array): string {
  // JPEG SOI：FF D8 FF
  if (image.length >= 3 &&
    image[0] === 0xFF &&
    image[1] === 0xD8 &&
    image[2] === 0xFF) {
    return 'image/jpeg';
  }

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

  // WebP：RIFF....WEBP
  if (image.length >= 12 &&
    image[0] === 0x52 && // R
    image[1] === 0x49 && // I
    image[2] === 0x46 && // F
    image[3] === 0x46 && // F
    image[8] === 0x57 && // W
    image[9] === 0x45 && // E
    image[10] === 0x42 && // B
    image[11] === 0x50) { // P
    return 'image/webp';
  }

  // HEIC/HEIF：ISO BMFF，偏移 4 处为 ftyp，brand 位于偏移 8。
  if (image.length >= 12 &&
    image[4] === 0x66 && // f
    image[5] === 0x74 && // t
    image[6] === 0x79 && // y
    image[7] === 0x70) { // p
    const brand: number = (image[8] << 24) |
      (image[9] << 16) |
      (image[10] << 8) |
      image[11];
    if (brand === 0x68656963 || // heic
      brand === 0x68656966 || // heif
      brand === 0x68656978 || // heix
      brand === 0x68657663 || // hevc
      brand === 0x68657678 || // hevx
      brand === 0x6D696631 || // mif1
      brand === 0x6D736631) { // msf1
      return 'image/heic';
    }
  }

  return '';
}

function uint8ArrayToArrayBuffer(data: Uint8Array): ArrayBuffer {
  const buffer: ArrayBuffer = new ArrayBuffer(data.length);
  const view: Uint8Array = new Uint8Array(buffer);
  view.set(data);
  return buffer;
}

/**
 * 使用 Image Kit 将 WebP/HEIC 解码为 PixelMap，再重新编码为 PNG。
 * 返回 null 表示当前设备不支持该图片格式或转换失败。
 */
async function convertImageToPng(imageData: Uint8Array): Promise<Uint8Array | null> {
  let imageSource: image.ImageSource | null = null;
  let pixelMap: image.PixelMap | null = null;
  let imagePacker: image.ImagePacker | null = null;

  try {
    imageSource = image.createImageSource(uint8ArrayToArrayBuffer(imageData));
    if (imageSource === null) {
      return null;
    }

    const decodingOptions: image.DecodingOptions = {
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    };
    pixelMap = await imageSource.createPixelMap(decodingOptions);

    imagePacker = image.createImagePacker();
    if (imagePacker === null) {
      return null;
    }

    const packingOptions: image.PackingOption = {
      format: 'image/png',
      quality: 100
    };
    const pngData: ArrayBuffer = await imagePacker.packToData(pixelMap, packingOptions);
    return new Uint8Array(pngData);
  } catch (err) {
    return null;
  } finally {
    if (pixelMap !== null) {
      try {
        await pixelMap.release();
      } catch (err) {
      }
    }
    if (imageSource !== null) {
      try {
        await imageSource.release();
      } catch (err) {
      }
    }
    if (imagePacker !== null) {
      try {
        await imagePacker.release();
      } catch (err) {
      }
    }
  }
}

async function normalizeCoverForFlac(cover: Uint8Array | null): Promise<Uint8Array | null> {
  if (cover === null || cover.length === 0) {
    return null;
  }

  const mimeType: string = detectImageMime(cover);
  if (mimeType === 'image/webp' || mimeType === 'image/heic') {
    return await convertImageToPng(cover);
  }

  return cover;
}

function cloneAudioTag(tag: AudioTag): AudioTag {
  const cloned: AudioTag = new AudioTag();
  cloned.title = tag.title;
  cloned.artist = tag.artist;
  cloned.album = tag.album;
  cloned.lyrics = tag.lyrics;
  cloned.cover = tag.cover;
  return cloned;
}

function buildPictureBlock(image: Uint8Array): Uint8Array | null {
  const mimeType: string = detectImageMime(image);
  if (mimeType.length === 0) {
    return null;
  }

  const encoder: util.TextEncoder = util.TextEncoder.create();
  const mime: Uint8Array = encoder.encodeInto(mimeType);
  const totalLen: number = 32 + mime.length + image.length;
  if (totalLen > MAX_METADATA_BLOCK_SIZE) {
    return null;
  }

  const out: Uint8Array = new Uint8Array(totalLen);
  let pos: number = 0;

  writeU32BE(out, pos, 3); // 3 = 封面(前)
  pos += 4;
  writeU32BE(out, pos, mime.length);
  pos += 4;
  out.set(mime, pos);
  pos += mime.length;
  writeU32BE(out, pos, 0); // 描述长度
  pos += 4;
  writeU32BE(out, pos, 0); // 宽，0 表示未知
  pos += 4;
  writeU32BE(out, pos, 0); // 高，0 表示未知
  pos += 4;
  writeU32BE(out, pos, 0); // 色深
  pos += 4;
  writeU32BE(out, pos, 0); // 颜色数
  pos += 4;
  writeU32BE(out, pos, image.length);
  pos += 4;
  out.set(image, pos);

  return out;
}

function buildBlockHeader(type: number, len: number, isLast: boolean): Uint8Array {
  const out: Uint8Array = new Uint8Array(4);
  out[0] = (isLast ? 0x80 : 0x00) | (type & 0x7F);
  out[1] = (len >> 16) & 0xFF;
  out[2] = (len >> 8) & 0xFF;
  out[3] = len & 0xFF;
  return out;
}

function mergeTag(originalTag: AudioTag, newTag: AudioTag): AudioTag {
  const merged: AudioTag = new AudioTag();
  merged.title = newTag.title.length > 0 ? newTag.title : originalTag.title;
  merged.artist = newTag.artist.length > 0 ? newTag.artist : originalTag.artist;
  merged.album = newTag.album.length > 0 ? newTag.album : originalTag.album;
  merged.lyrics = newTag.lyrics.length > 0 ? newTag.lyrics : originalTag.lyrics;
  merged.cover = newTag.cover !== null && newTag.cover.length > 0 ? newTag.cover : originalTag.cover;
  return merged;
}

/**
 * 重新构造 FLAC 元数据区：替换 Vorbis Comment 和 PICTURE，保留其他有效元数据块。
 *
 * @param original 原始 FLAC 文件字节
 * @param tag 新标签
 * @param preserveOriginalFields true 时，tag 中的空字段表示保留原值；
 *                               如果需要真正清空字段，请传 false
 */
export function buildFlacWithTag(original: Uint8Array, tag: AudioTag,
  preserveOriginalFields: boolean = true): Uint8Array | null {
  const audioStart: number = getFlacAudioStart(original);
  if (audioStart < 0) {
    return null;
  }

  const parseResult: [AudioTag, number] = parseFlac(original);
  if (parseResult[1] < 0) {
    return null;
  }
  const finalTag: AudioTag = preserveOriginalFields ? mergeTag(parseResult[0], tag) : tag;

  const reader: ByteReader = new ByteReader(original, 4);
  const otherKeepBlocks: FlacBlock[] = [];
  let streamInfoBlock: FlacBlock | null = null;
  let blockIndex: number = 0;

  while (reader.position < audioStart && reader.remaining >= 4) {
    const header: [boolean, number, number] = parseBlockHeader(reader);
    const type: number = header[1];
    const len: number = header[2];

    if (len < 0 || len > MAX_METADATA_BLOCK_SIZE ||
      reader.remaining < len || reader.position + len > audioStart) {
      return null;
    }

    const blockData: Uint8Array = reader.readBytes(len);
    const block: FlacBlock = new FlacBlock();
    block.type = type;
    block.data = blockData;

    if (blockIndex === 0) {
      if (type !== 0 || len !== 34) {
        return null;
      }
      streamInfoBlock = block;
    } else if (type === 0) {
      // FLAC 只能有一个 STREAMINFO。
      return null;
    } else if (type === 1) {
      // 丢弃旧 Padding，最后统一添加新的 Padding。
    } else if (type !== 4 && type !== 6 && type !== 127) {
      // 保留 SEEKTABLE、APPLICATION、CUESHEET 等其他有效块。
      otherKeepBlocks.push(block);
    } else if (type === 127) {
      return null;
    }

    blockIndex++;
  }

  if (streamInfoBlock === null) {
    return null;
  }

  const commentData: Uint8Array = buildVorbisCommentBlock(finalTag);
  if (commentData.length > MAX_METADATA_BLOCK_SIZE) {
    return null;
  }

  const allBlocks: FlacBlock[] = [];
  allBlocks.push(streamInfoBlock);

  const commentBlock: FlacBlock = new FlacBlock();
  commentBlock.type = 4;
  commentBlock.data = commentData;
  allBlocks.push(commentBlock);

  if (finalTag.cover !== null && finalTag.cover.length > 0) {
    const pictureData: Uint8Array | null = buildPictureBlock(finalTag.cover);
    if (pictureData !== null) {
      const pictureBlock: FlacBlock = new FlacBlock();
      pictureBlock.type = 6;
      pictureBlock.data = pictureData;
      allBlocks.push(pictureBlock);
    }
  }

  for (let i: number = 0; i < otherKeepBlocks.length; i++) {
    allBlocks.push(otherKeepBlocks[i]);
  }

  // 4KB Padding 便于下次修改标签；它必须是最后一个 Metadata Block。
  const paddingBlock: FlacBlock = new FlacBlock();
  paddingBlock.type = 1;
  paddingBlock.data = new Uint8Array(4096);
  allBlocks.push(paddingBlock);

  const parts: Uint8Array[] = [];
  parts.push(FLAC_MAGIC);

  for (let i: number = 0; i < allBlocks.length; i++) {
    const block: FlacBlock = allBlocks[i];
    if (block.data.length > MAX_METADATA_BLOCK_SIZE) {
      return null;
    }
    const isLast: boolean = i === allBlocks.length - 1;
    parts.push(buildBlockHeader(block.type, block.data.length, isLast));
    parts.push(block.data);
  }

  parts.push(original.slice(audioStart));
  return concatBytes(parts);
}

/**
 * 自动封面兼容版构建函数。
 *
 * JPEG/PNG 会直接写入 FLAC；
 * WebP/HEIC 会先转换为 PNG，再写入 FLAC，以提升播放器封面兼容性。
 *
 * 注意：图片转码是异步操作，因此调用时必须使用 await。
 */
export async function buildFlacWithTagAutoCover(original: Uint8Array, tag: AudioTag,
  preserveOriginalFields: boolean = true): Promise<Uint8Array | null> {
  const parseResult: [AudioTag, number] = parseFlac(original);
  if (parseResult[1] < 0) {
    return null;
  }

  const finalTag: AudioTag = preserveOriginalFields ? mergeTag(parseResult[0], tag) : cloneAudioTag(tag);
  const hadCover: boolean = finalTag.cover !== null && finalTag.cover.length > 0;
  const normalizedCover: Uint8Array | null = await normalizeCoverForFlac(finalTag.cover);

  // 原来有封面但转码失败时直接失败，避免静默丢失封面。
  if (hadCover && normalizedCover === null) {
    return null;
  }
  finalTag.cover = normalizedCover;

  return buildFlacWithTag(original, finalTag, false);
}
