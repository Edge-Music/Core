import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { LogUtil } from '@pura/harmony-utils';
import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit';
import { ColorExtractor, ExtractedColor } from './ColorExtractor';
import { ColorConverter, RGB } from './ColorConverter';

const TAG = 'ImageUtils';

/** 模糊封面落盘结果：打开的文件句柄（调用方负责关闭）+ 文件名（卡片用 memory:// 引用） */
export interface BlurTempFile {
  file: fileIo.File;
  fileName: string;
}

export class ImageDealData {
  imageColor: string = 'rgba(0, 0, 2, 1.00)';
  imageColorHex: string = '';
  blurPixelMap: PixelMap | undefined = undefined;
  blurPixelMapForCard: PixelMap | undefined = undefined;
}

class ImageUtils {
  public async getBlurPixelMap(pixelMap: PixelMap, blur: number): Promise<PixelMap> {
    let filter = effectKit.createEffect(pixelMap);
    filter.blur(blur);
    let blurPixelMap: PixelMap = await filter.getEffectPixelMap();
    return blurPixelMap;
  }

  public async compressImage(sourcePixelMap: image.PixelMap, maxCompressedImageSize: number): Promise<PixelMap> {
    LogUtil.info(TAG, 'compressImage');
    let compressedImageData: ArrayBuffer = await this.packing(sourcePixelMap);
    if (compressedImageData.byteLength <= maxCompressedImageSize * 1024) {
      LogUtil.info(TAG, 'compressImage first');
      return sourcePixelMap;
    }
    let imageScale = 1;
    while (compressedImageData.byteLength > maxCompressedImageSize * 1024) {
      if (imageScale > 0) {
        imageScale = imageScale - 0.05;
        await sourcePixelMap.scale(imageScale, imageScale);
        compressedImageData = await this.packing(sourcePixelMap);
      } else {
        break;
      }
    }
    let afterCompressionSize = (compressedImageData.byteLength / 1024).toFixed(1);
    LogUtil.info(TAG, `compressImage afterCompressionSize:` + afterCompressionSize);
    if (compressedImageData.byteLength > maxCompressedImageSize * 1024) {
      LogUtil.info(TAG, 'compress iamge failed');
    }
    return sourcePixelMap;
  }

  async packing(sourcePixelMap: image.PixelMap): Promise<ArrayBuffer> {
    const imagePackerApi = image.createImagePacker();
    const packOpts: image.PackingOption = { format: 'image/' + 'jpeg', quality: 100 };
    const data: ArrayBuffer = await imagePackerApi.packToData(sourcePixelMap, packOpts);
    return data;
  }

  /**
   * 将模糊封面 PixelMap 编码为 jpeg 写入临时文件，返回打开的文件句柄与文件名。
   * 调用方负责在 formProvider.updateForm 推送完成后关闭文件（fd 生命周期由调用方管理）。
   * 失败返回 null（不阻断主流程，取色/封面照常推送）。
   * @param context 上下文（取 tempDir）
   * @param blurPixelMap 模糊封面 PixelMap（如 blurPixelMapForCard）
   * @param suffix 文件名后缀，用于区分多张模糊图
   */
  public async writeBlurToTemp(context: Context, blurPixelMap: PixelMap | undefined, suffix: string = 'blur'): Promise<BlurTempFile | null> {
    if (!blurPixelMap) {
      return null;
    }
    try {
      const buffer: ArrayBuffer = await this.packing(blurPixelMap);
      const tempDir = context.getApplicationContext().tempDir;
      const fileName = 'blur_' + suffix + '_' + Date.now() + '.jpg';
      const tmpFile = tempDir + '/' + fileName;
      const imgFile = fileIo.openSync(tmpFile, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      try {
        await fileIo.write(imgFile.fd, buffer);
        const result: BlurTempFile = { file: imgFile, fileName: fileName };
        return result;
      } catch (err) {
        LogUtil.error(TAG, `writeBlurToTemp write failed: ${JSON.stringify(err)}`);
        fileIo.closeSync(imgFile);
        return null;
      }
    } catch (err) {
      LogUtil.error(TAG, `writeBlurToTemp err: ${JSON.stringify(err)}`);
      return null;
    }
  }

  public getImageDealDataByArr(buffer: ArrayBuffer): Promise<ImageDealData> {
    return new Promise(async (resolve, reject) => {
      try {
        let pixelMap = image.createImageSource(buffer).createPixelMapSync();
        if (buffer.byteLength > 2048 * 1024) {
          pixelMap = await this.compressImage(pixelMap, 2048);
        }
        let imageData = new ImageDealData();
        // 复用 3.0 光感取色：ColorExtractor 取候选色 -> pickBackground 选适合满铺背景的色。
        // 注意：卡片背景是 linearGradient 满铺（非小面积高光 accent），选色策略偏向
        // 「饱和但有深度」的中深色，避免中明度纯色刺眼、文字不清。
        const colors = await ColorExtractor.extractColors(pixelMap, 5);
        const imageColorHex = this.pickBackground(colors); // #RRGGBB
        let imageColor = '';
        if (imageColorHex) {
          const rgb = ColorConverter.hexToRgb(imageColorHex);
          imageColor = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 1)`;
        }
        LogUtil.info(TAG, `getImageDealDataByArr imageColor :${imageColor}`);
        LogUtil.info(TAG, `getImageDealDataByArr imageColorHex :${imageColorHex}`);
        imageData.imageColor = imageColor;
        imageData.imageColorHex = imageColorHex.replace('#', '');
        imageData.blurPixelMap = await this.getBlurPixelMap(pixelMap, 15);
        imageData.blurPixelMapForCard = await this.getBlurPixelMap(pixelMap, 100);
        LogUtil.info(TAG, `getImageDealDataByArr success`);
        resolve(imageData);
      } catch (err) {
        LogUtil.info(TAG, `getImageDealDataByArr err :${JSON.stringify(err)}`)
        reject(err);
      }
    });
  }

  /**
   * 从候选色中挑选一个适合「满铺卡片背景」的色。
   *
   * 与小面积 accent 不同：背景色要大面积平铺，文字（白色）叠在上面。因此：
   *  - 偏好中深明度（0.22~0.40）：够深才压得住白字，又不到死黑无色彩；
   *  - 要有一定饱和度（色彩感），但纯黄/纯青等跳眼色相需适度降权；
   *  - 占比大的色更可能与封面同源，给加分（避免选到采样噪点色）。
   */
  private pickBackground(colors: ExtractedColor[]): string {
    if (!colors || colors.length === 0) {
      return '';
    }
    let best: RGB | null = null;
    let bestScore: number = -Infinity;
    for (const c of colors) {
      const rgb: RGB = ColorConverter.hexToRgb(c.hex);
      const lum: number = this.luminance(rgb);
      const sat: number = this.saturation(rgb);
      const hue: number = this.huePenalty(rgb);

      // 明度分：中深区间(0.30)最优，远离则递减；过亮(>0.5)扣重，过暗(<0.12)也扣
      const lumScore: number = 1 - Math.min(1, Math.abs(lum - 0.30) / 0.30);
      // 饱和度分：0.4~0.7 区间最佳（有色彩但不刺），过低灰、过高跳都减分
      const satScore: number = 1 - Math.min(1, Math.abs(sat - 0.55) / 0.45);
      // 占比分：候选色 count 字段越大代表占比越高，归一加成
      const propScore: number = Math.min(1, (c.count || 0) / 100);

      const score: number = lumScore * 0.45 + satScore * 0.35 + propScore * 0.20 - hue;
      if (score > bestScore) {
        bestScore = score;
        best = rgb;
      }
    }
    if (!best) {
      return '';
    }
    // 背景用途：只对过亮/过暗做收敛，不强行提亮到中等（那是 accent 的策略）
    const normalized: RGB = this.clampForBackground(best);
    return ColorConverter.rgbToHex(normalized.r, normalized.g, normalized.b);
  }

  /**
   * 背景色明度收敛：过亮压暗、过暗微提，落在 0.22~0.45 的「深而有彩」区间。
   * 不做激进提亮，保留封面原本的明度气质。
   */
  private clampForBackground(rgb: RGB): RGB {
    const lum: number = this.luminance(rgb);
    let target: number = lum;
    if (lum > 0.45) {
      target = 0.45 - (lum - 0.45) * 0.5; // 过亮向 0.45 收，但保留一定明度差
    } else if (lum < 0.18) {
      target = lum + (0.18 - lum) * 0.6;   // 过暗微提，别提过头变灰
    }
    if (target === lum) {
      return { r: rgb.r, g: rgb.g, b: rgb.b };
    }
    const scale: number = target / Math.max(lum, 0.01);
    return {
      r: Math.min(255, Math.round(rgb.r * scale)),
      g: Math.min(255, Math.round(rgb.g * scale)),
      b: Math.min(255, Math.round(rgb.b * scale))
    };
  }

  /**
   * 跳眼色相惩罚：纯黄/品红/纯青等高视觉刺激色相当满铺背景时易刺眼，给负权。
   * 返回 0~0.3 的惩罚值，越跳眼越大。
   */
  private huePenalty(rgb: RGB): number {
    const hsv = ColorConverter.rgbToHsv(rgb.r, rgb.g, rgb.b);
    const h: number = hsv.h;
    const s: number = hsv.s / 100;
    // 无饱和度的灰阶不惩罚（由 satScore 处理）
    if (s < 0.15) {
      return 0;
    }
    // 纯黄(55±15) / 品红(300±20) 区间，高饱和时最跳
    const inYellow: boolean = h >= 40 && h <= 70;
    const inMagenta: boolean = h >= 280 && h <= 320;
    if (inYellow || inMagenta) {
      return 0.25 * Math.min(1, s);
    }
    return 0;
  }

  /** 感知亮度 0~1 */
  private luminance(rgb: RGB): number {
    return (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255;
  }

  /** 饱和度 0~1 */
  private saturation(rgb: RGB): number {
    const max: number = Math.max(rgb.r, rgb.g, rgb.b);
    const min: number = Math.min(rgb.r, rgb.g, rgb.b);
    if (max === 0) {
      return 0;
    }
    return (max - min) / max;
  }
}

export default new ImageUtils();