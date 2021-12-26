package;

import sys.FileSystem;
import lime.app.Application;
import lime.system.System;
import android.*;

class Data
{
	
	private static var dataPath1:String = null;
	private static var dataPath2:String = null;
	
    static public function getPath1():String 
    {
        if (dataPath1 != null && dataPath1.length > 0) 
        {
            return dataPath1;
        } 
        else 
        {
            dataPath1 = "/storage/emulated/0/Android/data/" + Application.current.meta.get("packageName");
        }
        return dataPath1;
    }
    
    static public function getPath2():String 
    {
        if (dataPath2 != null && dataPath2.length > 0) 
        {
            return dataPath2;
        } 
        else 
        {
            dataPath2 = "/storage/emulated/0/Android/data/";
        }
        return dataPath2;
    }    

    public static function init():Void
    {
        AndroidTools.requestPermission(Permissions.READ_EXTERNAL_STORAGE);
        AndroidTools.requestPermission(Permissions.WRITE_EXTERNAL_STORAGE);

        if (!FileSystem.exists(getPath2 + Application.current.meta.get("packageName")))
            FileSystem.createDirectory(getPath2 + Application.current.meta.get("packageName"));        

        if (!FileSystem.exists(getPath1 + "/files/"))
            FileSystem.createDirectory(getPath1 + "/files/");

        if (!FileSystem.exists(Main.getDataPath() + "assets"))
        {
            Application.current.window.alert("Try copying assets/assets from apk to " + " /storage/emulated/0/Android/data/" + Application.current.meta.get("packageName") + "/files/" + "\n" + "Press Ok To Close The App", "Check Directory Error");
            System.exit(0);//Will close the game
        }
        else if (!FileSystem.exists(Main.getDataPath() + "mods"))
        {
            Application.current.window.alert("Try copying assets/mods from apk to " + " /storage/emulated/0/Android/data/" + Application.current.meta.get("packageName") + "/files/" + "\n" + "Press Ok To Close The App", "Check Directory Error");
            System.exit(0);//Will close the game
        }
    }
}
