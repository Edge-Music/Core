import ActionUtils from '../model/ActionUtils';
import { PlayActionType } from '../model/FormCardConstant';

const ControlAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': 'musicCover', 'align': HorizontalAlign.End }
};

interface LyricsLineData {
  time: number;
  text: string;
}

let storageUpdateCall = new LocalStorage();

@Entry(storageUpdateCall)
@Component
struct PlayControlCardLargeLyrics {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('isPlay') isPlay: boolean = false;
  @LocalStorageProp('title') title: string = '暂无播放';
  @LocalStorageProp('imgName') imgName: ResourceStr = $r('app.media.default_cover');
  @LocalStorageProp('singer') singer: string = '未知歌手';
  @LocalStorageProp('songId') songId: string = '';
  @LocalStorageProp('isNeedRequestUpdate') @Watch('requestData') isNeedRequestUpdate: boolean = false;
  @LocalStorageProp('imageColor') imageColor: string = 'rgba(30,30,30,1)';
  @LocalStorageProp('imageColorHex') imageColorHex: string = '1E1E1E';
  @LocalStorageProp('accentColor') accentColor: string = 'rgba(60,60,60,1)';
  @LocalStorageProp('accentColorHex') accentColorHex: string = '3C3C3C';
  @LocalStorageProp('loaded') loaded: boolean = false;
  @LocalStorageProp('blurImg') blurImg: string = '';
  @LocalStorageProp('parsedLyrics') parsedLyrics: LyricsLineData[] = [];
  @LocalStorageProp('currentLyricsIndex') currentLyricsIndex: number = 0;

  requestData() {
    ActionUtils.updateControlCardAction(this, this.formId);
  }

  getLyricText(offset: number): string {
    if (!this.parsedLyrics || this.parsedLyrics.length === 0) {
      return offset === 0 ? (this.title ? `${this.title} - ${this.singer}` : '') : '';
    }
    const index = this.currentLyricsIndex + offset;
    if (index < 0 || index >= this.parsedLyrics.length) {
      return '';
    }
    return this.parsedLyrics[index]?.text || '';
  }

  build() {
    Column() {
      // 歌词区域（上方主体，layoutWeight 撑满剩余空间）
      Column() {
        Text(this.getLyricText(0))
          .fontSize(24)
          .fontWeight(700)
          .fontColor(Color.White)
          .lineHeight(28)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textShadow({
            radius: 8,
            color: `#${this.accentColorHex}40`,
            offsetX: 0,
            offsetY: 0
          })

        Text(this.getLyricText(1))
          .fontSize(13)
          .fontWeight(700)
          .fontColor('#99FFFFFF')
          .lineHeight(30)
          .margin({ top: 12 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, bottom: 10 })

      // 底部控制栏
      Row() {
        Row() {
          Image(this.loaded ? 'memory://' + this.imgName : $r('app.media.default_cover'))
            .height(36)
            .width(36)
            .borderRadius(10)
            .shadow({
              radius: 12,
              color: 'rgba(0,0,0,0.4)',
              offsetX: 0,
              offsetY: 4
            })
          Column() {
            Text(this.title)
              .fontSize(13)
              .fontColor(Color.White)
              .fontWeight(700)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.singer)
              .fontSize(11)
              .fontColor('#99FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
              .width('100%')
          }
          .margin({ left: 10 })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('40%')

        Row() {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize(24)
            .fontColor(['#E5FFFFFF'])
            .onClick(() => {
              ActionUtils.playByAction(this, PlayActionType.PREVIOUS, this.formId);
            })

          SymbolGlyph(this.isPlay ? $r('sys.symbol.pause_round_triangle_fill') : $r('sys.symbol.play_round_triangle_fill'))
            .fontSize(28)
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
            .fontColor(['#E5FFFFFF'])
            .margin({ left: 20, right: 20 })
            .onClick(() => {
              if (this.isPlay) {
                ActionUtils.playByAction(this, PlayActionType.PAUSE, this.formId);
              } else {
                ActionUtils.playByAction(this, PlayActionType.PLAY, this.formId);
              }
            })

          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(24)
            .fontColor(['#E5FFFFFF'])
            .onClick(() => {
              ActionUtils.playByAction(this, PlayActionType.NEXT, this.formId);
            })
        }
      }
      .width('100%')
      .height(54)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignRules(ControlAlignRules)
      .backgroundColor('rgba(0,0,0,0.3)')
      .padding({ top: 9, left: 10, right: 10, bottom: 9 })
    }
    .height('100%')
    .width('100%')
    // 未加载时显示干净的深色底
    .backgroundColor(this.loaded ? 'rgba(0,0,0,0)' : 'rgba(26,26,26,1)')
    // 预模糊封面铺底（与 PlayControlCard2x4 一致）
    .backgroundImage(this.loaded && this.blurImg ? `memory://${this.blurImg}` : undefined)
    .backgroundImageSize(ImageSize.Cover)
    // 光感晕 - accent 色从封面区域扩散（仅加载后显示）
    .radialGradient({
      center: ['25%', '30%'],
      radius: '65%',
      colors: [
        [this.loaded ? `#${this.accentColorHex}30` : 'rgba(0,0,0,0)', 0.0],
        [this.loaded ? `#${this.accentColorHex}00` : 'rgba(0,0,0,0)', 1.0]
      ]
    })
    // scrim 渐变（4-stop，双色，压暗让白字可读）
    .linearGradient({
      direction: GradientDirection.Bottom,
      repeating: false,
      colors: [
        [this.loaded ? `#${this.imageColorHex}CC` : 'rgba(26,26,26,0.8)', 0.0],
        [this.loaded ? `#${this.accentColorHex}66` : 'rgba(20,20,20,0.85)', 0.3],
        [this.loaded ? `#${this.imageColorHex}99` : 'rgba(15,15,15,0.9)', 0.6],
        [this.loaded ? `#${this.imageColorHex}D9` : 'rgba(10,10,10,0.95)', 1.0]
      ]
    })
    // 玻璃折射边框
    .border({
      width: 1,
      color: this.loaded ? 'rgba(255,255,255,0.18)' : 'rgba(255,255,255,0.08)'
    })
    // 氛围投影（封面色发光悬浮，仅加载后显示）
    .shadow({
      radius: this.loaded ? 40 : 0,
      color: this.loaded ? `#${this.imageColorHex}50` : 'rgba(0,0,0,0)',
      offsetX: 0,
      offsetY: 8
    })
    .onClick(() => {
      ActionUtils.jumpPlayPage(this);
    })
  }
}
