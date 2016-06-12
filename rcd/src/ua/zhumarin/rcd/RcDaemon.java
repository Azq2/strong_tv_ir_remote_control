package ua.zhumarin.rcd;

import android.app.Service; 
import android.content.Intent; 
import android.util.Log; 
import android.content.Context;
import android.os.Build;
import android.os.IBinder; 
import android.os.AsyncTask;
import android.content.res.*;
import android.media.MediaPlayer;

import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.Inet4Address;

public class RcDaemon extends Service {
	public final static String LOG_TAG = "xujxujxuj";
	private RcServer server = null;
	
	@Override
	public void onStart(Intent intent, int startId) {
		if (server == null) {
			Log.d(LOG_TAG, "start");
			server = new RcServer();
			server.execute();
		} else {
			Log.d(LOG_TAG, "already runned");
		}
	}
	
	@Override
	public void onDestroy() {
		if (server != null) {
			Log.d(LOG_TAG, "destroy");
			server.cancel(false);
			server = null;
		}
	}
	
	@Override
	public IBinder onBind(Intent intent) {
		return null; 
	}
	
	public static class RcServer extends AsyncTask<Void, Void, Void> {
		MediaPlayer player = null;
		AssetFileDescriptor fd = null;
		AssetManager am = null;
		
		private void startPlayer(String path) {
			Log.d(LOG_TAG, "startPlayer()");
			
			stopPlayer();
			
			if (player == null)
				player = new MediaPlayer();
			
			try {
				fd = am.openFd(path);
				player.setDataSource(fd.getFileDescriptor(), fd.getStartOffset(), fd.getLength());
				player.prepare();
				player.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
					@Override
					public void onCompletion(MediaPlayer mp) {
						stopPlayer();
					}
				});
				player.setVolume(1, 1);
				player.start();
			} catch (IOException e) {
				Log.d(LOG_TAG, "xuj??");
			}
		}
		
		private void stopPlayer() {
			Log.d(LOG_TAG, "stopPlayer()");
			
			if (player != null) {
				if (player.isPlaying())
					player.stop();
				player.reset();
			}
			
			if (fd != null) {
				try {
					fd.close();
				} catch (IOException e) { }
				fd = null;
			}
		}
		
		protected Void doInBackground(Void... params) {
			am = App.instance().getAssets();
			
			while (true) {
				try {
					java.lang.System.setProperty("java.net.preferIPv6Addresses", "false");
					java.lang.System.setProperty("java.net.preferIPv4Stack", "true");
					
					ServerSocket server = new ServerSocket(9991, 50, Inet4Address.getByName("0.0.0.0"));
					Log.d(LOG_TAG, "open!");
					while (!isCancelled()) {
						Socket socket = server.accept();
						BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(socket.getOutputStream()));
						BufferedReader br = new BufferedReader(new InputStreamReader(socket.getInputStream()));
						
						try {
							Log.d(LOG_TAG, "accept!");
							
							writer.write("STATE: " + (player != null && player.isPlaying() ? "playing" : "none") + "\n");
							writer.flush();
							
							String line = br.readLine();
							
							if (line.length() == 2) {
								startPlayer("key_" + line + ".wav");
								writer.write("OK\n");
							} else {
								writer.write("invalid input: " + line + "\n");
							}
						} catch (Exception e) {
							
						}
						try { writer.flush(); } catch (IOException e) { }
						try { writer.close(); } catch (IOException e) { }
						try { br.close(); } catch (IOException e) { }
					}
					
					Log.d(LOG_TAG, "O_O");
				} catch (IOException e) {
					Log.d(LOG_TAG, "xuj??");
					 e.printStackTrace();
				}
			}
			// return null;
		}
	}
}
