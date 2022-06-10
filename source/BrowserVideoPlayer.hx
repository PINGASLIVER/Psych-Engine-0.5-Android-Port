package;

import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxBasic;

import extension.webview.WebView;

using StringTools;

class BrowserVideoPlayer extends FlxBasic
{
	public static var androidPath:String = 'file://';//ok
        public var finishCallback:Void->Void = null;

	public function new(path:String)
	{
		super();

		WebView.onClose = onClose;
		WebView.onURLChanging= onURLChanging;

		WebView.open(androidPath + path, false, null, ['http://exitme(.*)']);
	}

	public override function update(dt:Float) 
	{
		super.update(dt);	
	}

	function onClose()
	{
		if (finishCallback != null)
		{
			finishCallback();
		}
	}

	function onURLChanging(url:String) 
	{
		if (url == 'http://exitme/') 
                        onClose(); // drity hack lol
		trace("WebView is about to open: "+url);
	}
}
