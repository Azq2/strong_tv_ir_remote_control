package ua.zhumarin.rcd;

import android.os.Handler;
import android.os.Looper;
import android.content.IntentFilter;
import android.content.Intent;
import android.content.BroadcastReceiver;
import android.util.Log;
import android.app.Application;
import android.net.ConnectivityManager;
import android.net.wifi.WifiManager;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;

public class App extends Application {
	private static App instance = null;
	
	@Override
	public void onCreate() {
		super.onCreate();
		instance = this;
	}
	
	public static App instance() {
		return instance;
	}
}
