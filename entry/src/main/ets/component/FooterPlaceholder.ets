import { StyleConstants } from "../constants/StyleConstants"

@Component
export struct FooterPlaceholder {
  @StorageProp('bottomRect') bottomRect: number = 0

  build() {
    ListItem() {
      Row() {
        Blank().height(StyleConstants.PLAYER_CONTROL_HEIGHT + this.bottomRect)
      }
    }
  }
}