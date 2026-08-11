import ActionUtils from '../model/ActionUtils';
import { CollectAction, PlayActionType } from '../model/FormCardConstant';

const CoverAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
  'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
};

const CollectAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top': { 'anchor': '__container__', 'align': VerticalAlign.Top },
  'right': { 'anchor': '__container__', 'align': HorizontalAlign.End }
};

const TitleAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top': { 'anchor': 'musicCover', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
};

const SingerAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'top': { 'anchor': 'musicTitle', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
};

const PlayAlignRules: Record<string, Record<string, string | VerticalAlign | HorizontalAlign>> = {
  'bottom': { 'anchor': '__container__', 'align': VerticalAlign.Bottom },
  'left': { 'anchor': '__container__', 'align': HorizontalAlign.Start }
};

let storageUpdateCall = new LocalStorage();

@Entry(storageUpdateCall)
@Component
struct PlayControlCard2x2 {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('isPlay') isPlay: boolean = false;
  @LocalStorageProp('title') title: string = '暂无播放';
  @LocalStorageProp('isCollected') isCollected: boolean = false;
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

  // 切歌按钮缩放动效 trigger：值变化即触发一次 ScaleSymbolEffect
  @State prevTrigger: number = 0;
  @State nextTrigger: number = 0;

  requestData() {
    ActionUtils.updateControlCardAction(this, this.formId);
  }

  build() {
    RelativeContainer() {
      // 封面（上方；方形，占左侧约一半，右侧空间留给收藏）
      Image(this.loaded ? 'memory://' + this.imgName : $r('app.media.default_cover'))
        .width('46%')
        .aspectRatio(1)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
        .alignRules(CoverAlignRules)
        .id('musicCover')
        .shadow({
          radius: 12,
          color: 'rgba(0,0,0,0.4)',
          offsetX: 0,
          offsetY: 4
        })

      // 收藏（封面右侧，右上角）
      SymbolGlyph(this.isCollected ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
        .fontSize(20)
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
        .fontColor(['#E5FFFFFF'])
        .alignRules(CollectAlignRules)
        .onClick(() => {
          if (this.isCollected) {
            ActionUtils.collectAction(this, CollectAction.UNCOLLECTED, this.formId, this.songId);
          } else {
            ActionUtils.collectAction(this, CollectAction.COLLECTED, this.formId, this.songId);
          }
        })

      // 歌名（封面下，占满宽度）
      Text(this.title)
        .fontSize(14)
        .fontWeight(700)
        .fontColor(Color.White)
        .maxLines(1)
        .alignRules(TitleAlignRules)
        .id('musicTitle')
        .margin({ top: 8 })
        .width('100%')
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textShadow({
          radius: 6,
          color: 'rgba(255,255,255,0.25)',
          offsetX: 0,
          offsetY: 0
        })

      // 歌手（歌名下）
      Text(this.singer)
        .fontSize(12)
        .fontColor('#99FFFFFF')
        .fontWeight(500)
        .maxLines(1)
        .alignRules(SingerAlignRules)
        .margin({ top: 4 })
        .id('singerText')
        .width('100%')
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 播控（固定底部，不变）
      Row() {
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(28)
          .fontColor(['#E5FFFFFF'])
          .symbolEffect(new ScaleSymbolEffect(EffectScope.WHOLE), this.prevTrigger)
          .onClick(() => {
            this.prevTrigger++;
            ActionUtils.playByAction(this, PlayActionType.PREVIOUS, this.formId);
          })

        SymbolGlyph(this.isPlay ? $r('sys.symbol.pause_round_triangle_fill') : $r('sys.symbol.play_round_triangle_fill'))
          .fontSize(28)
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
          .fontColor(['#E5FFFFFF'])
          .onClick(() => {
            if (this.isPlay) {
              ActionUtils.playByAction(this, PlayActionType.PAUSE, this.formId);
            } else {
              ActionUtils.playByAction(this, PlayActionType.PLAY, this.formId);
            }
          })

        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(28)
          .fontColor(['#E5FFFFFF'])
          .symbolEffect(new ScaleSymbolEffect(EffectScope.WHOLE), this.nextTrigger)
          .onClick(() => {
            this.nextTrigger++;
            ActionUtils.playByAction(this, PlayActionType.NEXT, this.formId);
          })
      }
      .height(30)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignRules(PlayAlignRules)
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .padding(12)
    .onClick(() => {
      ActionUtils.jumpPlayPage(this);
    })
    // 未加载时显示干净的深色底
    .backgroundColor(this.loaded ? 'rgba(0,0,0,0)' : 'rgba(26,26,26,1)')
    // 预模糊封面
    .backgroundImage(this.loaded && this.blurImg ? `memory://${this.blurImg}` : undefined)
    .backgroundImageSize(ImageSize.Cover)
    // 光感晕（仅加载后显示）
    .radialGradient({
      center: ['30%', '25%'],
      radius: '70%',
      colors: [
        [this.loaded ? `#${this.accentColorHex}28` : 'rgba(0,0,0,0)', 0.0],
        [this.loaded ? `#${this.accentColorHex}00` : 'rgba(0,0,0,0)', 1.0]
      ]
    })
    // scrim（4-stop 双色）
    .linearGradient({
      direction: GradientDirection.Bottom,
      repeating: false,
      colors: [
        [this.loaded ? `#${this.imageColorHex}CC` : 'rgba(26,26,26,0.8)', 0.0],
        [this.loaded ? `#${this.accentColorHex}55` : 'rgba(20,20,20,0.85)', 0.3],
        [this.loaded ? `#${this.imageColorHex}88` : 'rgba(15,15,15,0.9)', 0.6],
        [this.loaded ? `#${this.imageColorHex}D9` : 'rgba(10,10,10,0.95)', 1.0]
      ]
    })
    // 玻璃折射边框
    .border({
      width: 1,
      color: this.loaded ? 'rgba(255,255,255,0.18)' : 'rgba(255,255,255,0.08)'
    })
    // 氛围投影（仅加载后显示）
    .shadow({
      radius: this.loaded ? 36 : 0,
      color: this.loaded ? `#${this.imageColorHex}50` : 'rgba(0,0,0,0)',
      offsetX: 0,
      offsetY: 8
    })
  }
}