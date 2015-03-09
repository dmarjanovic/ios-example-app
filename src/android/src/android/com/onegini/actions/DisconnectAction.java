package com.onegini.actions;

import org.apache.cordova.CallbackContext;
import org.json.JSONArray;

import com.onegini.OneginiCordovaPlugin;
import com.onegini.mobile.sdk.android.library.handlers.OneginiDisconnectHandler;

public class DisconnectAction implements OneginiPluginAction {
  @Override
  public void execute(final JSONArray args, final CallbackContext callbackContext,
                         final OneginiCordovaPlugin client) {
    client.getOneginiClient().disconnect(new OneginiDisconnectHandler() {
      @Override
      public void revokeSuccess() {
        callbackContext.success();
      }

      @Override
      public void revokeError() {
        callbackContext.error("Failed to disconnect device.");
      }
    });
  }
}
