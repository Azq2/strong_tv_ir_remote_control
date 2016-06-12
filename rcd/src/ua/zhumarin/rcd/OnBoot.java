package ua.zhumarin.rcd;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent; 
import android.content.Context;
import android.content.BroadcastReceiver;

public class OnBoot extends BroadcastReceiver {
	@Override
	public void onReceive(Context context, Intent intent) {
		Intent i = new Intent(context, MainActivity.class);
		i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		context.startActivity(i);
	}
}
