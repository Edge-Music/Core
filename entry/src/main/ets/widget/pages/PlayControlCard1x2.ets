import ActionUtils from '../model/ActionUtils';
import { PlayActionType } from '../model/FormCardConstant';

let storageUpdateCall = new LocalStorage();

@Entry(storageUpdateCall)
@Component
struct PlayControlCard1x2 {
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

  requestData() {
    ActionUtils.updateControlCardAction(this, this.formId);
  }

  build() {
    Column(){
      Row() {
        Image(this.loaded ? 'memory://' + this.imgName : $r('app.media.default_cover'))
          .height('100%')
          .borderRadius(8)
          .margin({ top: 2 })
          .shadow({
            radius: 10,
            color: 'rgba(0,0,0,0.35)',
            offsetX: 0,
            offsetY: 3
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
          .onClick(() => {
            ActionUtils.playByAction(this, PlayActionType.NEXT, this.formId);
          })
      }
      .height('100%')
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding(8)
      .onClick(() => {
        ActionUtils.jumpPlayPage(this);
      })
    }
    // 未加载时显示干净的深色底
    .backgroundColor(this.loaded ? 'rgba(0,0,0,0)' : 'rgba(26,26,26,1)')
    // 预模糊封面
    .backgroundImage(this.loaded && this.blurImg ? `memory://${this.blurImg}` : undefined)
    .backgroundImageSize(ImageSize.Cover)
    // 光感晕（仅加载后显示）
    .radialGradient({
      center: ['35%', '30%'],
      radius: '75%',
      colors: [
        [this.loaded ? `#${this.accentColorHex}25` : 'rgba(0,0,0,0)', 0.0],
        [this.loaded ? `#${this.accentColorHex}00` : 'rgba(0,0,0,0)', 1.0]
      ]
    })
    // scrim（4-stop 双色）
    .linearGradient({
      direction: GradientDirection.Bottom,
      repeating: false,
      colors: [
        [this.loaded ? `#${this.imageColorHex}CC` : 'rgba(26,26,26,0.8)', 0.0],
        [this.loaded ? `#${this.accentColorHex}50` : 'rgba(20,20,20,0.85)', 0.3],
        [this.loaded ? `#${this.imageColorHex}80` : 'rgba(15,15,15,0.9)', 0.6],
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
      radius: this.loaded ? 32 : 0,
      color: this.loaded ? `#${this.imageColorHex}48` : 'rgba(0,0,0,0)',
      offsetX: 0,
      offsetY: 6
    })
  }
}