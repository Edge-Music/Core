import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { LogUtil } from '@pura/harmony-utils'
import { FormInfo } from '../viewmodel/FormData';
import { FormRdbHelper } from '../util/FormRdbHelper';
import FormUtils from '../util/FormUtils';

const TAG = 'EntryFormAbility';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    // Called to return a FormBindingData object.
    if (want.parameters) {
      let formId = want.parameters['ohos.extra.param.key.form_identity'] as string;
      let formDimension = want.parameters['ohos.extra.param.key.form_dimension'] as string;
      let formName = want.parameters['ohos.extra.param.key.form_name'] as string;

      let formInfo = new FormInfo();
      formInfo.formId = formId;
      formInfo.formDimension = formDimension;
      formInfo.formName = formName;
      LogUtil.info(TAG, `onAddForm formInfo: ${JSON.stringify(formInfo)}`);
      FormRdbHelper.getInstance(this.context).insertForm(formInfo);

      if (formName.includes('PlayControlCard')) {
        FormUtils.updateMusicControlCard(formId, true);
      }
    }
    return formBindingData.createFormBindingData('');
  }

  onCastToNormalForm(formId: string) {
    // Called when the form provider is notified that a temporary form is successfully
    // converted to a normal form.
  }

  onUpdateForm(formId: string) {
    // Called to notify the form provider to update a specified form.
  }

  onFormEvent(formId: string, message: string) {
    // Called when a specified message event defined by the form provider is triggered.
  }

  onRemoveForm(formId: string) {
    // Called to notify the form provider that a specified form has been destroyed.
    FormRdbHelper.getInstance(this.context).deleteForm(formId);
  }

  onAcquireFormState(want: Want) {
    // Called to return a {@link FormState} object.
    return formInfo.FormState.READY;
  }
}