import { StyleConstants } from "../constants/StyleConstants"

@Component
export struct HeaderPlaceholder {
  @StorageProp('topRect') topRect: number = 0
  @StorageProp('decorHeight') decorHeight: number = 0

  @Prop offsetY: number = 0

  build() {
    ListItem() {
      Row().width('100%').height((this.topRect > this.decorHeight ? this.topRect : this.decorHeight) + StyleConstants.TITLE_HEIGHT + this.offsetY)
    }
  }
}