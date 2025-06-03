import { ImageKnifeComponent } from "@ohos/imageknife";

@Component
export struct Avatar {
  @Prop url: ResourceStr = ''
  @Prop radius: number | string = "50%"

  build() {
    Image(this.url ?? $r('app.media.ic_placeholder'))
      .borderRadius(this.radius)
      .clip(true)
    // ImageKnifeComponent({
    //   imageKnifeOption: {
    //     loadSrc: this.url,
    //     objectFit: ImageFit.Cover,
    //     placeholderSrc: $r('app.media.ic_placeholder'),
    //   }
    // })
    //   .borderRadius(this.radius)
    //   .clip(true)
  }
}