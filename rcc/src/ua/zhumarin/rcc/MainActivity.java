package ua.zhumarin.rcc;

import android.app.Activity;
import android.content.Intent; 
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.os.AsyncTask;

import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.Inet4Address;
import java.net.InetSocketAddress;

public class MainActivity extends Activity implements View.OnClickListener {
	private boolean busy = false;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.main);
		
		((Button) findViewById(R.id.key_power)).setOnClickListener(this);
		((Button) findViewById(R.id.key_mute)).setOnClickListener(this);
		((Button) findViewById(R.id.key_menu)).setOnClickListener(this);
		((Button) findViewById(R.id.key_exit)).setOnClickListener(this);
		((Button) findViewById(R.id.key_up)).setOnClickListener(this);
		((Button) findViewById(R.id.key_down)).setOnClickListener(this);
		((Button) findViewById(R.id.key_left)).setOnClickListener(this);
		((Button) findViewById(R.id.key_right)).setOnClickListener(this);
		((Button) findViewById(R.id.key_ok)).setOnClickListener(this);
		
		setTitle("Хуюльт");
	}
	
	@Override
	public void onClick(View v) {
		final String code = getCode(v.getId());
		if (code != null && !busy) {
			setTitle("Хуюльт | Отправка " + code + "...");
			((TextView) findViewById(R.id.log)).setText("");
			busy = true;
			new AsyncTask<Void, Void, Object>() {
				protected Object doInBackground(Void... params) {
					String log = "";
					try {
						Socket client = new Socket();
						client.connect(new InetSocketAddress(Inet4Address.getByName("192.168.1.2"), 9991), 1000);
						BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(client.getOutputStream()));
						writer.write(code + "\n");
						writer.flush();
						
						BufferedReader br = new BufferedReader(new InputStreamReader(client.getInputStream()));
						log += br.readLine();
						
						br.close();
						writer.close();
						client.close();
						
						return log;
					} catch (Exception e) {
						return e;
					}
				}
				
				@Override
				protected void onPostExecute(Object result) {
					super.onPostExecute(result);
					
					busy = false;
					if (result == null) {
						setTitle("NULL");
					} else if (result instanceof Exception) {
						Exception ex = (Exception) result;
						setTitle("Хуюльт | Ошибка: " + ex.getMessage());
						((TextView) findViewById(R.id.log)).setText(ex.getMessage());
					} else {
						String str = (String) result;
						((TextView) findViewById(R.id.log)).setText(str);
					}
				}
			}.execute();
		}
	}
	
	private String getCode(int id) {
		switch (id) {
			case R.id.key_power:
				return "AF";
			case R.id.key_menu:
				return "EF";
			case R.id.key_mute:
				return null;
			case R.id.key_exit:
				return "9F";
			case R.id.key_up:
				return "FF";
			case R.id.key_down:
				return "7F";
			case R.id.key_left:
				return "3F";
			case R.id.key_right:
				return "BF";
			case R.id.key_ok:
				return "07";
		}
		return null;
	}
}
