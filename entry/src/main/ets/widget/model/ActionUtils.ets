import { CallMethod, ENTRY_ABILITY, FormCarAction, PlayActionType, RouterType } from './FormCardConstant';

class ActionUtils {
  /**
   * card music play action
   * @param component
   * @param type '0':pause '1'：play '2'：previous '3'：next
   * @param formId
   */
  public playByAction(component: Object, type: PlayActionType, formId: string) {
    postCardAction(component, {
      action: FormCarAction.CALL,
      abilityName: ENTRY_ABILITY,
      params: {
        method: CallMethod.PLAY_BY_ACTION,
        playActionType: type,
        formId: formId
      }
    });
  }

  public updateControlCardAction(component: Object, formId: string) {
    postCardAction(component, {
      action: FormCarAction.CALL,
      abilityName: ENTRY_ABILITY,
      params: {
        method: CallMethod.REQUEST_UPDATE_CARD,
        formId: formId
      }
    });
  }

  /**
   * card collect action
   * @param component card component
   * @param type '0':uncollected '1':collected
   * @param formId form id
   * @param songId song id
   */
  collectAction(component: Object, type: string, formId: string, songId: string) {
    postCardAction(component, {
      action: FormCarAction.CALL,
      abilityName: ENTRY_ABILITY,
      params: {
        method: CallMethod.COLLECT_ACTION,
        collectActionType: type,
        formId: formId,
        songId: songId
      }
    });
  }

  jumpPlayPage(component: Object) {
    postCardAction(component, {
      action: FormCarAction.ROUTER,
      abilityName: ENTRY_ABILITY,
      params: {
        type: RouterType.PLAYER
      }
    });
  }

  jumpApp(component: Object) {
    postCardAction(component, {
      action: FormCarAction.ROUTER,
      abilityName: ENTRY_ABILITY,
    });
  }
}

export default new ActionUtils();