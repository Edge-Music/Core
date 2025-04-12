import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { LogUtil } from '@pura/harmony-utils';
import { http } from '@kit.NetworkKit'

const TAG = 'ImageUtils';

export class ImageDealData {
  imageColor: string = 'rgba(0, 0, 2, 1.00)';
  imageColorHex: string = '';
  blurPixelMap: PixelMap | undefined = undefined;
  blurPixelMapForCard: PixelMap | undefined = undefined;
}

/**
 * Color conversion processing class.
 */
class ImageUtils {
  /**
   * Generate an immersive background color for the image.
   * @param rRGB
   * @param gRGB
   * @param bRGB
   * @returns
   */
  public dealColor(rRGB: number, gRGB: number, bRGB: number) {
    let max = Math.max(Math.max(rRGB, gRGB), bRGB);
    let min = Math.min(Math.min(rRGB, gRGB), bRGB);
    let sHSB = max === 0 ? 0 : (max - min) / max;
    let bHSB = max / 255;
    // 针对灰度色（无色彩饱和度）进行特殊处理，避免除 0 引起的错误
    if (max === min) {
      if (bHSB >= 0.4) {
        bHSB = 0.3;
      } else if (bHSB >= 0.2) {
        bHSB -= 0.1;
      } else {
        bHSB = bHSB + 0.2;
      }
      let fixedValue = Math.floor(bHSB * 255.0);
      return [fixedValue, fixedValue, fixedValue];
    }

    // 普通颜色的处理：正常计算色相 hHSB
    let hHSB = 0;
    if (max === rRGB && gRGB >= bRGB) {
      hHSB = 60 * (gRGB - bRGB) / (max - min) + 0;
    }
    if (max === rRGB && gRGB < bRGB) {
      hHSB = 60 * (gRGB - bRGB) / (max - min) + 360;
    }
    if (max === gRGB) {
      hHSB = 60 * (bRGB - rRGB) / (max - min) + 120;
    }
    if (max === bRGB) {
      hHSB = 60 * (rRGB - gRGB) / (max - min) + 240;
    }

    if (bHSB >= 0.4) {
      bHSB = 0.3;
    } else if (bHSB >= 0.2) {
      bHSB -= 0.1;
    } else {
      bHSB = bHSB + 0.2;
    }

    let i: number = Math.floor((hHSB / 60) % 6);
    let f = (hHSB / 60) - i;
    let p = bHSB * (1 - sHSB);
    let q = bHSB * (1 - f * sHSB);
    let t = bHSB * (1 - (1 - f) * sHSB);
    switch (i) {
      case 0:
        rRGB = bHSB;
        gRGB = t;
        bRGB = p;
        break;
      case 1:
        rRGB = q;
        gRGB = bHSB;
        bRGB = p;
        break;
      case 2:
        rRGB = p;
        gRGB = bHSB;
        bRGB = t;
        break;
      case 3:
        rRGB = p;
        gRGB = q;
        bRGB = bHSB;
        break;
      case 4:
        rRGB = t;
        gRGB = p;
        bRGB = bHSB;
        break;
      case 5:
        rRGB = bHSB;
        gRGB = p;
        bRGB = q;
        break;
      default:
        break;
    }
    return [Math.floor(rRGB * 255.0), Math.floor(gRGB * 255.0), Math.floor(bRGB * 255.0)];
  }

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

  public getImageDealDataByArr(buffer: ArrayBuffer): Promise<ImageDealData> {
    return new Promise(async (resolve, reject) => {
      try {
        let pixelMap = image.createImageSource(buffer).createPixelMapSync();
        if (buffer.byteLength > 2048 * 1024) {
          pixelMap = await this.compressImage(pixelMap, 2048);
        }
        let imageData = new ImageDealData();
        let colorPicker = await effectKit.createColorPicker(pixelMap);
        let mainColor = colorPicker.getMainColorSync();
        LogUtil.info(TAG, `getImageDealDataByArr mainColor :${mainColor.red} ${mainColor.green} ${mainColor.blue} ${mainColor.alpha}`);
        let colorArr = this.dealColor(mainColor.red, mainColor.green, mainColor.blue);
        let imageColor = `rgba(${colorArr[0]}, ${colorArr[1]}, ${colorArr[2]}, 1)`;
        let imageColorHex = `${colorArr[0].toString(16).padStart(2, '0')}${colorArr[1].toString(16).padStart(2, '0')}${colorArr[2].toString(16).padStart(2, '0')}`;
        LogUtil.info(TAG, `getImageDealDataByArr imageColor :${imageColor}`);
        LogUtil.info(TAG, `getImageDealDataByArr imageColorHex :${imageColorHex}`);
        if (imageColorHex.length === 5)
          imageColorHex = '0' + imageColorHex;
        imageData.imageColor = imageColor;
        imageData.imageColorHex = imageColorHex;
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
}

export default new ImageUtils();