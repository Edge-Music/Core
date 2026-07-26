import { FormCarAction, ENTRY_ABILITY, RouterType } from '../model/FormCardConstant';
let storageUpdateCall3 = new LocalStorage();

@Entry(storageUpdateCall3)
@Component
struct RecommendedMusic1x2 {
  @LocalStorageProp('imgBg') imgBg: ResourceStr = '';
  @LocalStorageProp('isLoaded') isLoaded: boolean = false;
  @LocalStorageProp('imageColor') imageColor: string = 'rgba(122,162,202,1)';
  @LocalStorageProp('imageColorHex') imageColorHex: string = '7aa2ca';
  @LocalStorageProp('blurImg') blurImg: string = '';

  build() {
    FormLink({
      action: FormCarAction.ROUTER,
      abilityName: ENTRY_ABILITY,
      params: {
        type: RouterType.PLAYLISTS
      }
    }) {
      Row() {
        Image(this.isLoaded ? `memory://${this.imgBg}` : $r('app.media.default_cover'))
          .height('100%')
          .borderRadius(8)
        Text($r('app.string.my_playlist'))
          .fontSize(14)
          .fontWeight(700)
          .fontColor('#DBFFFFFF')
          .lineHeight(16)
          .maxLines(1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        direction: GradientDirection.Bottom,
        repeating: false,
        // 半透明 scrim：压暗模糊封面让白字可读，同时透出封面色相（blurImg 铺底时生效）
        colors: [[`#cc${this.imageColorHex}`, 0.0], [`#99${this.imageColorHex}`, 0.5],
          [`#d9${this.imageColorHex}`, 0.7]]
      })
      .backgroundImage(this.isLoaded && this.blurImg ? `memory://${this.blurImg}` : undefined)
      .backgroundImageSize(ImageSize.Cover)
      .padding(8)
    }
  }
}

