// because my lazy ass doesn't wanna include a bunch of if(stageMode) stuff to the regular ModchartState

// Lua
import openfl.display3D.textures.VideoTexture;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
#if desktop
import flixel.tweens.FlxEase;
import openfl.filters.ShaderFilter;
import openfl.Lib;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import openfl.geom.Matrix;
import openfl.display.BitmapData;
import lime.app.Application;
import flixel.FlxSprite;
import llua.Convert;
import llua.Lua;
import llua.State;
import llua.LuaL;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.system.FlxSound;
import flixel.effects.FlxFlicker;
import flixel.addons.effects.FlxTrail;
import flixel.addons.effects.FlxTrailArea;
import Type.ValueType;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import openfl.system.System;
import lime.utils.Assets;
import flixel.math.FlxMath;
import openfl.display.BlendMode;
import ModchartState;

#if desktop
import Sys;
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;
import Shaders;
import flash.media.Sound;

class StageModchartState 
{
	//public static var shaders:Array<LuaShader> = null;

	public var lua:State = null;
	public var lePlayState:PlayState = null;
	public static var Function_Stop = 1;
	public static var Function_Continue = 0;

	public var blam:Dynamic = "";
	public var scriptName:String = '';
	var gonnaClose:Bool = false;

	public function callLua(func_name : String, args : Array<Dynamic>, ?type : String) : Dynamic
	{
		#if desktop
		if(lua == null) {
			return Function_Continue;
		}

		var result : Any = null;

		Lua.getglobal(lua, func_name);

		for (arg in args) {
			Convert.toLua(lua, arg);
		}

		var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
		if(result != null && resultIsAllowed(lua, result)) {
			if(Lua.type(lua, -1) == Lua.LUA_TSTRING) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				if(error == 'attempt to call a nil value') { //Makes it ignore warnings and not break stuff if you didn't put the functions on your lua file
					return Function_Continue;
				}
			}

			return convert(result, type);
		}
		#end
		return Function_Continue;
	}

	#if desktop
	function resultIsAllowed(leLua:State, leResult:Null<Int>) { //Makes it ignore warnings
		switch(Lua.type(leLua, leResult)) {
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE:
				return true;
		}
		return false;
	}
	#end

	static function toLua(l:State, val:Any):Bool {
		switch (Type.typeof(val)) {
			case Type.ValueType.TNull:
				Lua.pushnil(l);
			case Type.ValueType.TBool:
				Lua.pushboolean(l, val);
			case Type.ValueType.TInt:
				Lua.pushinteger(l, cast(val, Int));
			case Type.ValueType.TFloat:
				Lua.pushnumber(l, val);
			case Type.ValueType.TClass(String):
				Lua.pushstring(l, cast(val, String));
			case Type.ValueType.TClass(Array):
				Convert.arrayToLua(l, val);
			case Type.ValueType.TObject:
				objectToLua(l, val);
			default:
				trace("haxe value not supported - " + val + " which is a type of " + Type.typeof(val));
				return false;
		}

		return true;

	}

	static function objectToLua(l:State, res:Any) {

		var FUCK = 0;
		for(n in Reflect.fields(res))
		{
			trace(Type.typeof(n).getName());
			FUCK++;
		}

		Lua.createtable(l, FUCK, 0); // TODONE: I did it

		for (n in Reflect.fields(res)){
			if (!Reflect.isObject(n))
				continue;
			Lua.pushstring(l, n);
			toLua(l, Reflect.field(res, n));
			Lua.settable(l, -3);
		}

	}

	function getType(l, type):Any
	{
		return switch Lua.type(l,type) {
			case t if (t == Lua.LUA_TNIL): null;
			case t if (t == Lua.LUA_TNUMBER): Lua.tonumber(l, type);
			case t if (t == Lua.LUA_TSTRING): (Lua.tostring(l, type):String);
			case t if (t == Lua.LUA_TBOOLEAN): Lua.toboolean(l, type);
			case t: throw 'you don goofed up. lua type error ($t)';
		}
	}

	function getReturnValues(l) {
		var lua_v:Int;
		var v:Any = null;
		while((lua_v = Lua.gettop(l)) != 0) {
			var type:String = getType(l,lua_v);
			v = convert(lua_v, type);
			Lua.pop(l, 1);
		}
		return v;
	}


	private function convert(v : Any, type : String) : Dynamic { // I didn't write this lol
		if( Std.is(v, String) && type != null ) {
		var v : String = v;
		if( type.substr(0, 4) == 'array' ) {
			if( type.substr(4) == 'float' ) {
			var array : Array<String> = v.split(',');
			var array2 : Array<Float> = new Array();

			for( vars in array ) {
				array2.push(Std.parseFloat(vars));
			}

			return array2;
			} else if( type.substr(4) == 'int' ) {
			var array : Array<String> = v.split(',');
			var array2 : Array<Int> = new Array();

			for( vars in array ) {
				array2.push(Std.parseInt(vars));
			}

			return array2;
			} else {
			var array : Array<String> = v.split(',');
			return array;
			}
		} else if( type == 'float' ) {
			return Std.parseFloat(v);
		} else if( type == 'int' ) {
			return Std.parseInt(v);
		} else if( type == 'bool' ) {
			if( v == 'true' ) {
			return true;
			} else {
			return false;
			}
		} else {
			return v;
		}
		} else {
		return v;
		}
	}

	function getLuaErrorMessage(l) {
		var v:String = Lua.tostring(l, -1);
		Lua.pop(l, 1);
		return v;
	}

	public function setVar(var_name : String, object : Dynamic){
		// trace('setting variable ' + var_name + ' to ' + object);

		Convert.toLua(lua, object);
		Lua.setglobal(lua, var_name);
	}

	public function getVar(var_name : String, type : String) : Dynamic {
		var result : Any = null;

		// trace('getting variable ' + var_name + ' with a type of ' + type);

		Lua.getglobal(lua, var_name);
		result = Convert.fromLua(lua,-1);
		Lua.pop(lua,1);

		if( result == null ) {
		return null;
		} else {
		var result = convert(result, type);
		//trace(var_name + ' result: ' + result);
		return result;
		}
	}

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false) {
		PlayState.instance.addTextToDebug(text);
		trace(text);
	}

	//trying to do some auto stuff so i don't have to set manual x and y values
	public function changeBFAuto(id:String, ?flipped:Bool = false, ?dontDestroy:Bool = false)
	{	
		var animationName:String = "no way anyone have an anim name this big";
		var animationFrame:Int = 0;						
		if (PlayState.instance.boyfriend.animation.curAnim.name.startsWith('sing'))
		{
			animationName = PlayState.instance.boyfriend.animation.curAnim.name;
			animationFrame = PlayState.instance.boyfriend.animation.curAnim.curFrame;
		}

		var bfPath:String = "";

		if (FlxG.save.data.uncacheCharacterSwitch && !dontDestroy)
			bfPath = 'shared:assets/shared/images/'+PlayState.instance.boyfriend.charPath;

		PlayState.instance.removeObject(PlayState.instance.bfTrail);
		PlayState.instance.removeObject(PlayState.instance.boyfriend);
		PlayState.instance.destroyObject(PlayState.instance.boyfriend);
		PlayState.instance.boyfriend = new Boyfriend(0, 0, id, !flipped);

		PlayState.instance.boyfriend.flipMode = flipped;

		var charOffset = new CharacterOffsets(id, !flipped);
		var charX:Float = charOffset.daOffsetArray[0];
		var charY:Float =  charOffset.daOffsetArray[1] - (!flipped ? 0 : 350);

		if (!PlayState.instance.boyfriend.isCustom)
		{
			if (flipped)
			{
				if (charX == 0 && charOffset.daOffsetArray[1] == 0)
				{
					var charOffset2 = new CharacterOffsets(id, true);
					charX = charOffset2.daOffsetArray[0];
					charY =  charOffset2.daOffsetArray[1];
				}
			}
			else
			{
				if (charX == 0 && charY == 0 && !PlayState.instance.boyfriend.curCharacter.startsWith('bf'))
				{
					var charOffset2 = new CharacterOffsets(id, false);
					charX = charOffset2.daOffsetArray[0];
					charY =  charOffset2.daOffsetArray[1] - 350;
				}
			}	
		}

		if (PlayState.instance.boyfriend.isCustom)
		{
			charX = PlayState.instance.boyfriend.positionArray[0];
			charY = PlayState.instance.boyfriend.positionArray[1] - 350;
		}

		PlayState.instance.boyfriend.x = PlayState.instance.Stage.bfXOffset + charX + 770;
		PlayState.instance.boyfriend.y = PlayState.instance.Stage.bfYOffset + charY + 450;

		PlayState.instance.addObject(PlayState.instance.bfTrail);
		PlayState.instance.bfTrail.resetTrail();
		PlayState.instance.addObject(PlayState.instance.boyfriend);

		if (PlayState.newIcons)
		{
			if (PlayState.swapIcons)
				PlayState.instance.iconP1.changeIcon(PlayState.instance.boyfriend.healthIcon);
		}
		else
			PlayState.instance.iconP1.useOldSystem(PlayState.instance.boyfriend.healthIcon);

		if (PlayState.instance.defaultBar)
		{
			PlayState.instance.healthBar.createFilledBar(FlxColor.fromString('#' + PlayState.instance.dad.iconColor), FlxColor.fromString('#' + PlayState.instance.boyfriend.iconColor));
			PlayState.instance.healthBar.updateBar();
		}	

		if (PlayState.instance.boyfriend.animOffsets.exists(animationName))
			PlayState.instance.boyfriend.playAnim(animationName, true, false, animationFrame);

		if (FlxG.save.data.uncacheCharacterSwitch && !dontDestroy)
			Paths.clearStoredMemory2(bfPath);

		if (PlayState.instance.changeArrows)
		{
			for (i in Main.keyAmmo[PlayState.SONG.mania]...Main.keyAmmo[PlayState.SONG.mania] * 2)
			{
				PlayState.instance.strumLineNotes.members[i].texture = PlayState.instance.boyfriend.noteSkin;
				PlayState.instance.bfStrumStyle = PlayState.instance.boyfriend.noteSkin;
			}
		}
	}

	public function changeDadAuto(id:String, ?flipped:Bool = false, ?dontDestroy:Bool = false)
	{	
		var animationName:String = "no way anyone have an anim name this big";
		var animationFrame:Int = 0;						
		if (PlayState.instance.dad.animation.curAnim.name.startsWith('sing'))
		{
			animationName = PlayState.instance.dad.animation.curAnim.name;
			animationFrame = PlayState.instance.dad.animation.curAnim.curFrame;
		}

		var dadPath:String = '';
		var daCurChar:String = PlayState.instance.dad.curCharacter;

		if (FlxG.save.data.uncacheCharacterSwitch && !dontDestroy)
			dadPath = 'shared:assets/shared/images/'+PlayState.instance.dad.charPath;

		PlayState.instance.removeObject(PlayState.instance.dadTrail);
		PlayState.instance.removeObject(PlayState.instance.dad);
		PlayState.instance.destroyObject(PlayState.instance.dad);
		PlayState.instance.dad = new Character(0, 0, id, flipped);

		var charOffset = new CharacterOffsets(id, flipped);
		var charX:Float = charOffset.daOffsetArray[0];
		var charY:Float =  charOffset.daOffsetArray[1] + (flipped ? 350 : 0);

		if (flipped)
			PlayState.instance.dad.flipMode = true;

		if (!PlayState.instance.dad.isCustom)
		{
			if (flipped)
			{
				if (charX == 0 && charOffset.daOffsetArray[1] == 0 && !charOffset.hasOffsets)
				{
					var charOffset2 = new CharacterOffsets(id, false);
					charX = charOffset2.daOffsetArray[0];
					charY = charOffset2.daOffsetArray[1];
				}
			}
			else
			{
				if (charX == 0 && charY == 0 && !charOffset.hasOffsets)
				{
					var charOffset2 = new CharacterOffsets(id, true);
					charX = charOffset2.daOffsetArray[0];
					charY = charOffset2.daOffsetArray[1] + 350;
				}
			}
		}

		if (PlayState.instance.dad.isCustom)
		{
			charX = PlayState.instance.dad.positionArray[0];
			charY = PlayState.instance.dad.positionArray[1];
		}

		PlayState.instance.dad.x = PlayState.instance.Stage.dadXOffset + charX + 100;
		PlayState.instance.dad.y = PlayState.instance.Stage.dadYOffset + charY + 100;

		PlayState.instance.addObject(PlayState.instance.dadTrail);
		PlayState.instance.dadTrail.resetTrail();
		PlayState.instance.addObject(PlayState.instance.dad);

		if (PlayState.newIcons)
		{
			if (PlayState.swapIcons)
				PlayState.instance.iconP2.changeIcon(PlayState.instance.dad.healthIcon);
		}
		else
			PlayState.instance.iconP2.useOldSystem(PlayState.instance.dad.healthIcon);

		if (PlayState.instance.defaultBar)
		{
			PlayState.instance.healthBar.createFilledBar(FlxColor.fromString('#' + PlayState.instance.dad.iconColor), FlxColor.fromString('#' + PlayState.instance.boyfriend.iconColor));
			PlayState.instance.healthBar.updateBar();
		}	

		if (PlayState.instance.dad.animOffsets.exists(animationName))
			PlayState.instance.dad.playAnim(animationName, true, false, animationFrame);

		if (FlxG.save.data.uncacheCharacterSwitch && !dontDestroy && daCurChar != PlayState.instance.dad.curCharacter)
			Paths.clearStoredMemory2(dadPath);

		if (PlayState.instance.changeArrows)
		{
			for (i in 0...Main.keyAmmo[PlayState.SONG.mania])
			{
				PlayState.instance.cpuStrums.members[i].texture = PlayState.instance.dad.noteSkin;
			}
		}
	}

	function changeGFAuto(id:String, ?dontDestroy:Bool = false)
	{		
		PlayState.instance.removeObject(PlayState.instance.gf);
		PlayState.instance.destroyObject(PlayState.instance.gf);
		PlayState.instance.gf = new Character(0, 0, id);
		PlayState.instance.gf.x = PlayState.instance.Stage.gfXOffset + 400;
		PlayState.instance.gf.y = PlayState.instance.Stage.gfYOffset + 130;
		PlayState.instance.gf.scrollFactor.set(0.95, 0.95);
		PlayState.instance.addObject(PlayState.instance.gf);

		if (FlxG.save.data.poltatoPC)
			PlayState.instance.gf.setPosition(PlayState.instance.gf.x + 100, PlayState.instance.gf.y + 170);

		var gfPath:String = '';

		if (FlxG.save.data.uncacheCharacterSwitch && !dontDestroy)
			gfPath = 'shared:assets/shared/images/'+PlayState.instance.gf.charPath;

		if (FlxG.save.data.uncacheCharacterSwitch && !dontDestroy)
			Paths.clearStoredMemory2(gfPath);
	}

	function getActorByName(id:String):Dynamic
	{
		// pre defined names
		switch(id)
		{
			case 'boyfriend' | 'bf':
				@:privateAccesss
				return PlayState.instance.boyfriend;
		}

		if (Std.parseInt(id) == null)
			return Reflect.getProperty(PlayState.instance,id);
		return PlayState.instance.strumLineNotes.members[Std.parseInt(id)];
	}


	function getPropertyByName(id:String)
	{
		return Reflect.field(PlayState.instance,id);
	}

	function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
		}
		return Reflect.getProperty(leArray, variable);
	}

	function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			return;
		}
		Reflect.setProperty(leArray, variable, value);
	}

    public function die() {	
		Lua.close(lua);
		lua = null;
	}
    // LUA SHIT

    public function new(path:String)
    {
		trace('opening a lua state (because we are cool :))');
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

		var curState:Dynamic = FlxG.state;
		lePlayState = curState;

		// pre lowercasing the song name (new)
		var songLowercase = StringTools.replace(PlayState.SONG.song, " ", "-").toLowerCase();
		switch (songLowercase) {
			case 'dad-battle': songLowercase = 'dadbattle';
			case 'philly-nice': songLowercase = 'philly';
			case 'scary-swings': songLowercase = 'scary swings';
		}

		var result = LuaL.dofile(lua, Paths.stageLua(path)); // execute le file
		var resultStr:String = Lua.tostring(lua, result);

		if (resultStr != null && result != 0)
		{
			Application.current.window.alert("LUA COMPILE ERROR:\n" + resultStr,"Kade Engine Modcharts");//kep this
			trace('oops you screwed up');
			Lua.close(lua);
			lua = null;
			Stage.instance.luaArray.remove(this);
			Stage.instance.luaArray = [];
			return;
		}

		scriptName = Paths.stageLua(path);
		
		//shaders = new Array<LuaShader>();	

		// get some fukin globals up in here bois

		setVar('Function_Stop', Function_Stop);
		setVar('Function_Continue', Function_Continue);

		setVar("difficulty", PlayState.storyDifficulty);
		setVar("bpm", Conductor.bpm);
		setVar("scrollspeed", FlxG.save.data.scrollSpeed != 1 ? FlxG.save.data.scrollSpeed : PlayState.SONG.speed);
		setVar("fpsCap", FlxG.save.data.fpsCap);
		setVar("downscroll", FlxG.save.data.downscroll);
		setVar("flashing", FlxG.save.data.flashing);
		setVar("distractions", FlxG.save.data.distractions);

		setVar("curStep", 0);
		setVar("daSection", 0);
		setVar("curBeat", 0);
		setVar("crochetReal", Conductor.crochet);
		setVar("crochet", Conductor.stepCrochet);
		setVar("safeZoneOffset", Conductor.safeZoneOffset);

		setVar("screenWidth",FlxG.width);
		setVar("screenHeight",FlxG.height);
		setVar("windowWidth",FlxG.width);
		setVar("windowHeight",FlxG.height);

		setVar("mustHitSection", false);
		setVar("curStep", 0);
		setVar("curBeat", 0);
		
		// callbacks

		// sprites

		Lua_helper.add_callback(lua, "closeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf. 
			var cervix = luaFile + ".lua";
			var doPush = false;
			if(FileSystem.exists(FileSystem.absolutePath("assets/shared/"+cervix))) {
				cervix = FileSystem.absolutePath("assets/shared/"+cervix);
				doPush = true;
			}
			else if (FileSystem.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(FileSystem.exists(cervix)) {
					doPush = true;
				}
			}

			if(doPush)
			{
				if(!ignoreAlreadyRunning)
				{
					for (luaInstance in PlayState.instance.luaArray)
					{
						if(luaInstance.scriptName == cervix)
						{
							PlayState.instance.closeLuas.push(luaInstance);
							return;
						}
					}

					for (luaInstance in PlayState.instance.Stage.luaArray)
					{
						if(luaInstance.scriptName == cervix)
						{
							//luaTrace('The script "' + cervix + '" is already running!');
							
								PlayState.instance.Stage.closeLuas.push(luaInstance);
							return;
						}
					}
				}
				return;
			}
			luaTrace("Script doesn't exist!");
		});

		Lua_helper.add_callback(lua, "toggleCamFilter", function(bool:Bool, camera:String = '') {
			cameraFromString(camera).filtersEnabled = bool;
		});
	

		Lua_helper.add_callback(lua, "getSongPosition", function() {
			return Conductor.songPosition;
		});

		Lua_helper.add_callback(lua,"setScrollFactor", function(id:String , x:Float, y:Float) {
			var shit:Dynamic = getThing(id);
			
			shit.scrollFactor.set(x, y);
		});

		Lua_helper.add_callback(lua,"getScrollFactor", function(id:String , x:String) {
			if (x == 'x')
				return getActorByName(id).scrollFactor.x;
			else
				return getActorByName(id).scrollFactor.y;
		});

		Lua_helper.add_callback(lua,"changeAnimOffset", function(id:String , x:Float, y:Float) {
			getActorByName(id).addOffset(x, y); // it may say addoffset but it actually changes it instead of adding to the existing offset so this works.
		});

		Lua_helper.add_callback(lua,"checkDownscroll", function() {
			return FlxG.save.data.downscroll;
		});

		Lua_helper.add_callback(lua,"getScared", function(id:String) {
			Stage.instance.swagBacks[id].getScared();
		});

		Lua_helper.add_callback(lua,"setDownscroll", function(id:Bool) {
			FlxG.save.data.downscroll = id;
		});

		Lua_helper.add_callback(lua,"setupNoteSplash", function(id:String) {
			PlayState.instance.splashSkin = id;
		});

		Lua_helper.add_callback(lua,"removeObject", function(id:String) {
			PlayState.instance.removeObject(getActorByName(id));
		});

		Lua_helper.add_callback(lua,"addObject", function(id:String) {
			PlayState.instance.addObject(getActorByName(id));
		});

		Lua_helper.add_callback(lua,"doStaticSign", function(lestatic:Int = 0, ?leopa:Bool = true) {
			PlayState.instance.doStaticSign(lestatic, leopa);
		});

		Lua_helper.add_callback(lua,"characterZoom", function(id:String, zoomAmount:Float, ?isSenpai:Bool = false) {
			getActorByName(id).setZoom(zoomAmount, isSenpai);
		});
		
		Lua_helper.add_callback(lua,"setHudAngle", function (x:Float) {
			PlayState.instance.camHUD.angle = x;
		});
		
		Lua_helper.add_callback(lua,"setHealth", function (heal:Float) {
			PlayState.instance.health = heal;
		});

		Lua_helper.add_callback(lua,"minusHealth", function (heal:Float) {
			PlayState.instance.health -= heal;
		});

		Lua_helper.add_callback(lua,"setHudPosition", function (x:Int, y:Int) {
			PlayState.instance.camHUD.x = x;
			PlayState.instance.camHUD.y = y;
		});

		Lua_helper.add_callback(lua,"getHudX", function () {
			return PlayState.instance.camHUD.x;
		});

		Lua_helper.add_callback(lua,"getHudY", function () {
			return PlayState.instance.camHUD.y;
		});

		Lua_helper.add_callback(lua,"getPlayerStrumsY", function (id:Int) {
			return PlayState.instance.strumLineNotes.members[id].y;
		});
		
		Lua_helper.add_callback(lua,"setCamPosition", function (x:Int, y:Int) {
			FlxG.camera.x = x;
			FlxG.camera.y = y;
		});

		Lua_helper.add_callback(lua,"shakeCam", function (i:Float, d:Float) {
			FlxG.camera.shake(i, d);
		});

		Lua_helper.add_callback(lua,"shakeHUD", function (i:Float, d:Float) {
			PlayState.instance.camHUD.shake(i, d);
		});
		Lua_helper.add_callback(lua, "fadeCam", function (r:Int = 255,g:Int = 255,b:Int = 255, d:Float, f:Bool, ?camera:String = 'game') {
			var c:FlxColor = new FlxColor();
			c.setRGB(r, g, b);
			cameraFromString(camera).fade(c, d, f);
		});

		Lua_helper.add_callback(lua, "fadeCamPsych", function(camera:String, color:String, duration:Float, fadeOut:Bool = false, forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			cameraFromString(camera).fade(colorNum, duration,fadeOut,null,forced);
		});

		Lua_helper.add_callback(lua, "flashCamPsych", function(camera:String, color:String, duration:Float, forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			cameraFromString(camera).flash(colorNum, duration,null,forced);
		});

		Lua_helper.add_callback(lua, "flashCam", function (r:Int,g:Int,b:Int, d:Float, f:Bool, ?camera:String) {
			var c:FlxColor = new FlxColor();
			c.setRGB(r, g, b);
			cameraFromString(camera).flash(c, d, f);
		});

		Lua_helper.add_callback(lua, "flashCamHUD", function (r:Int,g:Int,b:Int, d:Float, f:Bool) {
			var c:FlxColor = new FlxColor();
			c.setRGB(r, g, b);
			PlayState.instance.camHUD.flash(c, d, f);
		});

		Lua_helper.add_callback(lua, "inAndOutCam", function (d:Float, d2:Float, d3:Float, ?camera:String) 
		{
			cameraFromString(camera).fade(FlxColor.WHITE, d, false, function()
			{
				new FlxTimer().start(d2, function(tmr:FlxTimer)
				{
					cameraFromString(camera).fade(FlxColor.WHITE, d3, true);
				});			
			}	
			);										
		});

		Lua_helper.add_callback(lua,"getCameraX", function () {
			return FlxG.camera.x;
		});

		Lua_helper.add_callback(lua,"getCameraY", function () {
			return FlxG.camera.y;
		});

		Lua_helper.add_callback(lua,"setCamZoom", function(zoomAmount:Float) {
			FlxG.camera.zoom = zoomAmount;
		});

		Lua_helper.add_callback(lua,"addCamZoom", function(zoomAmount:Float) {
			FlxG.camera.zoom += zoomAmount;
		});

		Lua_helper.add_callback(lua,"addHudZoom", function(zoomAmount:Float) {
			PlayState.instance.camHUD.zoom += zoomAmount;
		});

		Lua_helper.add_callback(lua,"setDefaultCamZoom", function(zoomAmount:Float) {
			PlayState.instance.defaultCamZoom = zoomAmount;
		});

		Lua_helper.add_callback(lua,"setHudZoom", function(zoomAmount:Float) {
			PlayState.instance.camHUD.zoom = zoomAmount;
		});

		Lua_helper.add_callback(lua,"setCamFollow", function(x:Float, y:Float) {
			PlayState.instance.camFollowIsOn = false;
			PlayState.instance.camFollow.setPosition(x, y);
		});

		Lua_helper.add_callback(lua,"setDelayedCamFollow", function(time:Float,x:Float, y:Float) {
			PlayState.instance.camFollowIsOn = false;

			new FlxTimer().start(time, function(tmr:FlxTimer)
			{
				PlayState.instance.camFollow.setPosition(x, y);
			});	
		});

		Lua_helper.add_callback(lua,"sundayFilter", function(bool:Bool) {
			//The string does absolutely nothing
			PlayState.instance.chromOn = bool;
		});

		Lua_helper.add_callback(lua,"offCamFollow", function(id:String) {
			//The string does absolutely nothing
			PlayState.instance.camFollowIsOn = false;
		});

		Lua_helper.add_callback(lua,"resetCamFollow", function(id:String) {
			//The string does absolutely nothing
			PlayState.instance.camFollowIsOn = true;
		});

		Lua_helper.add_callback(lua,"snapCam", function(x:Float, y:Float) {
			PlayState.instance.camFollowIsOn = false;
			{
				var camPosition:FlxObject;
				camPosition = new FlxObject(0, 0, 1, 1);
				camPosition.setPosition(x, y);
				FlxG.camera.focusOn(camPosition.getPosition());
			}
		});
		
		Lua_helper.add_callback(lua,"resetCamEffects", function(id:String) {
			PlayState.instance.camFollowIsOn = true;
		});

		Lua_helper.add_callback(lua,"miscCamFollow", function(camera:String, x:Float, y:Float) {
				var camPosition:FlxObject;
				camPosition = new FlxObject(0, 0, 1, 1);
				camPosition.setPosition(x, y);

				cameraFromString(camera).follow(camPosition, LOCKON, 0.04 * (30 / (cast (Lib.current.getChildAt(0), Main)).getFPS()));
		});

		// strumline

		Lua_helper.add_callback(lua, "setStrumlineY", function(y:Float)
		{
			PlayState.instance.strumLine.y = y;
		});

		// actors
		
		Lua_helper.add_callback(lua,"getRenderedNotes", function() {
			return PlayState.instance.notes.length;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteX", function(id:Int) {
			return PlayState.instance.notes.members[id].x;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteY", function(id:Int) {
			return PlayState.instance.notes.members[id].y;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteType", function(id:Int) {
			return PlayState.instance.notes.members[id].noteData;
		});

		Lua_helper.add_callback(lua,"isSustain", function(id:Int) {
			return PlayState.instance.notes.members[id].isSustainNote;
		});

		Lua_helper.add_callback(lua,"isParentSustain", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNote.isSustainNote;
		});

		
		Lua_helper.add_callback(lua,"getRenderedNoteParentX", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNote.x;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteParentY", function(id:Int) {
			return PlayState.instance.notes.members[id].prevNote.y;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteHit", function(id:Int) {
			return PlayState.instance.notes.members[id].mustPress;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteCalcX", function(id:Int) {
			if (PlayState.instance.notes.members[id].mustPress)
				return PlayState.instance.playerStrums.members[Math.floor(Math.abs(PlayState.instance.notes.members[id].noteData))].x;
			return PlayState.instance.strumLineNotes.members[Math.floor(Math.abs(PlayState.instance.notes.members[id].noteData))].x;
		});

		Lua_helper.add_callback(lua,"anyNotes", function() {
			return PlayState.instance.notes.members.length != 0;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteStrumtime", function(id:Int) {
			return PlayState.instance.notes.members[id].strumTime;
		});

		Lua_helper.add_callback(lua,"getRenderedNoteScaleX", function(id:Int) {
			return PlayState.instance.notes.members[id].scale.x;
		});

		Lua_helper.add_callback(lua,"setRenderedNotePos", function(x:Float,y:Float, id:Int) {
			if (PlayState.instance.notes.members[id] == null)
				throw('error! you cannot set a rendered notes position when it doesnt exist! ID: ' + id);
			else
			{
				PlayState.instance.notes.members[id].modifiedByLua = true;
				PlayState.instance.notes.members[id].x = x;
				PlayState.instance.notes.members[id].y = y;
			}
		});

		Lua_helper.add_callback(lua,"setRenderedNoteAlpha", function(alpha:Float, id:Int) {
			PlayState.instance.notes.members[id].modifiedByLua = true;
			PlayState.instance.notes.members[id].alpha = alpha;
		});

		Lua_helper.add_callback(lua,"setRenderedNoteScale", function(scale:Float, id:Int) {
			PlayState.instance.notes.members[id].modifiedByLua = true;
			PlayState.instance.notes.members[id].setGraphicSize(Std.int(PlayState.instance.notes.members[id].width * scale));
		});

		Lua_helper.add_callback(lua,"setRenderedNoteScale", function(scaleX:Int, scaleY:Int, id:Int) {
			PlayState.instance.notes.members[id].modifiedByLua = true;
			PlayState.instance.notes.members[id].setGraphicSize(scaleX,scaleY);
		});

		Lua_helper.add_callback(lua,"getRenderedNoteWidth", function(id:Int) {
			return PlayState.instance.notes.members[id].width;
		});


		Lua_helper.add_callback(lua,"setRenderedNoteAngle", function(angle:Float, id:Int) {
			PlayState.instance.notes.members[id].modifiedByLua = true;
			PlayState.instance.notes.members[id].angle = angle;
		});

		Lua_helper.add_callback(lua,"setActorX", function(x:Int,id:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			shit.x = x;
		});
		
		Lua_helper.add_callback(lua,"setActorScreenCenter", function(id:String, ?thing:String) {
			var shit:Dynamic = getThing(id);
			shit.screenCenter();				
		});

		Lua_helper.add_callback(lua,"screenCenter", function(id:String, ?thing:String) { //same thing. just for psych
			var shit:Dynamic = getThing(id);
			shit.screenCenter();				
		});

		Lua_helper.add_callback(lua,"setActorAccelerationX", function(x:Int,id:String) {
			getActorByName(id).acceleration.x = x;
		});
		
		Lua_helper.add_callback(lua,"setActorDragX", function(x:Int,id:String) {
			getActorByName(id).drag.x = x;
		});
		
		Lua_helper.add_callback(lua,"setActorVelocityX", function(x:Int,id:String, ?bg:Bool = false) {
			if (bg){
				Stage.instance.swagBacks[id].velocity.x = x;
			}
			else {
				getActorByName(id).velocity.x = x;
			}				
		});

		Lua_helper.add_callback(lua,"enablePurpleMiss", function(id:String,toggle:Bool) {
			getActorByName(id).doMissThing = toggle;
		});

		Lua_helper.add_callback(lua,"playBGAnimation", function(id:String,anim:String,force:Bool = false,reverse:Bool = false) {
			var shit:Dynamic = getThing(id);
			shit.animation.play(anim, force, reverse);
		});

		Lua_helper.add_callback(lua,"playBGAnimation2", function(id:String,anim:String,force:Bool = false,reverse:Bool = false) {
			getActorByName(id).animation.play(anim, force, reverse);
		});

		Lua_helper.add_callback(lua,"flickerActor", function (id:FlxObject, duration:Float, interval:Float) {
			FlxFlicker.flicker(id, duration, interval);
		});

		Lua_helper.add_callback(lua,"setActorAlpha", function(alpha:Float,id:String, ?bg:Bool = false) {
			if (bg){
				Stage.instance.swagBacks[id].alpha = alpha;
			}
			else {
				getActorByName(id).alpha = alpha;
			}
		});

		/*Lua_helper.add_callback(lua,"boomBoom", function(visible:Bool,id:String, id2:Int) {
			getActorByName(id).members[id2].visible = visible;
		});*/

		Lua_helper.add_callback(lua,"setActorVisibility", function(alpha:Bool,id:String, ?bg:Bool = false) {
			if (bg){
				Stage.instance.swagBacks[id].visible = alpha;
			}
			else {
				getActorByName(id).visible = alpha;
			}	
		});

		Lua_helper.add_callback(lua,"setActorY", function(y:Int,id:String, ?bg:Bool = false) {
			if (bg){
				Stage.instance.swagBacks[id].y = y;
			}
			else {
				getActorByName(id).y = y;
			}	
		});

		Lua_helper.add_callback(lua,"setActorAccelerationY", function(y:Int,id:String) {
			getActorByName(id).acceleration.y = y;
		});
		
		Lua_helper.add_callback(lua,"setActorDragY", function(y:Int,id:String) {
			getActorByName(id).drag.y = y;
		});
		
		Lua_helper.add_callback(lua,"setActorVelocityY", function(y:Int,id:String) {
			getActorByName(id).velocity.y = y;
		});
		
		Lua_helper.add_callback(lua,"setActorAngle", function(angle:Int,id:String) {
			getActorByName(id).angle = angle;
		});

		Lua_helper.add_callback(lua,"setGraphicSize", function(id:String, x:Float) {
			Stage.instance.setGraphicSize(id, x);
		});

		Lua_helper.add_callback(lua,"stopGFDance", function(stop:Bool) {
			PlayState.instance.picoCutscene = stop;
		});

		Lua_helper.add_callback(lua,"isPixel", function(change:Bool) {
			PlayState.isPixel = change;
		});

		Lua_helper.add_callback(lua, "setActorFlipX", function(flip:Bool, id:String)
		{
			getActorByName(id).flipX = flip;
		});
		

		Lua_helper.add_callback(lua, "setActorFlipY", function(flip:Bool, id:String)
		{
			getActorByName(id).flipY = flip;
		});

		Lua_helper.add_callback(lua,"getActorWidth", function (id:String) {
			return getActorByName(id).width;
		});

		Lua_helper.add_callback(lua,"getActorHeight", function (id:String) {
			return getActorByName(id).height;
		});

		Lua_helper.add_callback(lua,"getActorAlpha", function(id:String) {
			return getActorByName(id).alpha;
		});

		Lua_helper.add_callback(lua,"getActorAngle", function(id:String) {
			return getActorByName(id).angle;
		});

		Lua_helper.add_callback(lua,"getActorX", function (id:String, ?bg:Bool = false) {
			if (bg)
				return Stage.instance.swagBacks[id].x;
			else
				return getActorByName(id).x;
		});

		Lua_helper.add_callback(lua,"getCameraZoom", function (id:String) {
			return PlayState.instance.defaultCamZoom;
		});

		Lua_helper.add_callback(lua,"getActorY", function (id:String, ?bg:Bool = false) {
			if (bg)
				return Stage.instance.swagBacks[id].y;
			else
				return getActorByName(id).y;
		});

		Lua_helper.add_callback(lua,"getActorXMidpoint", function (id:String, ?graphic:Bool = false) {
			if (graphic)
				return getActorByName(id).getGraphicMidpoint().x;

			return getActorByName(id).getMidpoint().x;
		});

		Lua_helper.add_callback(lua,"getActorYMidpoint", function (id:String, ?graphic:Bool = false) {
			if (graphic)
				return getActorByName(id).getGraphicMidpoint().y;

			return getActorByName(id).getMidpoint().y;
		});

		Lua_helper.add_callback(lua,"setWindowPos",function(x:Int,y:Int) {
			Application.current.window.x = x;
			Application.current.window.y = y;
		});

		Lua_helper.add_callback(lua,"getWindowX",function() {
			return Application.current.window.x;
		});

		Lua_helper.add_callback(lua,"getWindowY",function() {
			return Application.current.window.y;
		});

		Lua_helper.add_callback(lua,"resizeWindow",function(Width:Int,Height:Int) {
			Application.current.window.resize(Width,Height);
		});
		
		Lua_helper.add_callback(lua,"getScreenWidth",function() {
			return Application.current.window.display.currentMode.width;
		});

		Lua_helper.add_callback(lua,"getScreenHeight",function() {
			return Application.current.window.display.currentMode.height;
		});

		Lua_helper.add_callback(lua,"getWindowWidth",function() {
			return Application.current.window.width;
		});

		Lua_helper.add_callback(lua,"getWindowHeight",function() {
			return Application.current.window.height;
		});


		// tweens
		
		Lua_helper.add_callback(lua,"tweenCameraPos", function(toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {x: toX, y: toY}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});
						
		Lua_helper.add_callback(lua,"tweenCameraAngle", function(toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {angle:toAngle}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenCameraZoom", function(toZoom:Float, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {zoom:toZoom}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenHudPos", function(toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {x: toX, y: toY}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});
						
		Lua_helper.add_callback(lua,"tweenHudAngle", function(toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {angle:toAngle}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenHudZoom", function(toZoom:Float, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {zoom:toZoom}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPos", function(id:String, toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, y: toY}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosQuad", function(id:String, toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, y: toY}, time, {ease: FlxEase.quadInOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosXAngle", function(id:String, toX:Int, toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, angle: toAngle}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosYAngle", function(id:String, toY:Int, toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {y: toY, angle: toAngle}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenAngle", function(id:String, toAngle:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {angle: toAngle}, time, {ease: FlxEase.linear, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenCameraPosOut", function(toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {x: toX, y: toY}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});
						
		Lua_helper.add_callback(lua,"tweenCameraAngleOut", function(toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {angle:toAngle}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenCameraZoomOut", function(toZoom:Float, time:Float, ease:String, onComplete:String) {
			FlxTween.tween(FlxG.camera, {zoom:toZoom}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenHudPosOut", function(toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {x: toX, y: toY}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});
						
		Lua_helper.add_callback(lua,"tweenHudAngleOut", function(toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {angle:toAngle}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenHudZoomOut", function(toZoom:Float, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {zoom:toZoom}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosOut", function(id:String, toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, y: toY}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosXAngleOut", function(id:String, toX:Int, toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, angle: toAngle}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosYAngleOut", function(id:String, toY:Int, toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {y: toY, angle: toAngle}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenAngleOut", function(id:String, toAngle:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {angle: toAngle}, time, {ease: FlxEase.cubeOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenCameraPosIn", function(toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {x: toX, y: toY}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});
						
		Lua_helper.add_callback(lua,"tweenCameraAngleIn", function(toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(FlxG.camera, {angle:toAngle}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenCameraZoomIn", function(toZoom:Float, time:Float, ease:String, onComplete:String) {
			FlxTween.tween(FlxG.camera, {zoom:toZoom}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenHudPosIn", function(toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {x: toX, y: toY}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});
						
		Lua_helper.add_callback(lua,"tweenHudAngleIn", function(toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {angle:toAngle}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenHudZoomIn", function(toZoom:Float, time:Float, onComplete:String) {
			FlxTween.tween(PlayState.instance.camHUD, {zoom:toZoom}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,["camera"]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosIn", function(id:String, toX:Int, toY:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, y: toY}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosXAngleIn", function(id:String, toX:Int, toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {x: toX, angle: toAngle}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenPosYAngleIn", function(id:String, toY:Int, toAngle:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {y: toY, angle: toAngle}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenAngleIn", function(id:String, toAngle:Int, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {angle: toAngle}, time, {ease: FlxEase.cubeIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenFadeIn", function(id:String, toAlpha:Float, time:Float, onComplete:String) {
			FlxTween.tween(getActorByName(id), {alpha: toAlpha}, time, {ease: FlxEase.circIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenFadeInBG", function(id:String, toAlpha:Float, time:Float, onComplete:String) {
			FlxTween.tween(Stage.instance.swagBacks[id], {alpha: toAlpha}, time, {ease: FlxEase.circIn, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenFadeOut", function(id:String, toAlpha:Float, time:Float, ease:String, onComplete:String) {
			FlxTween.tween(getActorByName(id), {alpha: toAlpha}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenFadeOutBG", function(id:String, toAlpha:Float, time:Float, onComplete:String) {
			FlxTween.tween(Stage.instance.swagBacks[id], {alpha: toAlpha}, time, {ease: FlxEase.circOut, onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenFadeOutOneShot", function(id:String, toAlpha:Float, time:Float) {
			FlxTween.tween(getActorByName(id), {alpha: toAlpha}, time, {type: FlxTweenType.ONESHOT});
		});

		Lua_helper.add_callback(lua,"tweenColor", function(id:String, time:Float, initColor:FlxColor, finalColor:FlxColor) {
			FlxTween.color(getThing(id), time, initColor, finalColor);
		});

		Lua_helper.add_callback(lua, "RGBColor", function (r:Int,g:Int,b:Int, alpha:Int = 255) {
			return FlxColor.fromRGB(r, g, b, alpha);
		});

		Lua_helper.add_callback(lua,"changeHue", function(id:String, hue:Int) {
			var newShader:ColorSwap = new ColorSwap();
			getThing(id).shader = newShader.shader;
			newShader.hue = hue / 360;
		});

		//a bunch of psych stuff
		Lua_helper.add_callback(lua,"tweenAnglePsych", function(id:String, toAngle:Int, time:Float, ease:String, onComplete:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {angle: toAngle}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenXPsych", function(id:String, toX:Int, time:Float, ease:String, onComplete:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {x: toX}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenYPsych", function(id:String, toY:Int, time:Float, ease:String, onComplete:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {y: toY}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenZoomPsych", function(id:String, toZoom:Int, time:Float, ease:String, onComplete:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {zoom: toZoom}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenScale", function(id:String, scale:Float, time:Float, ease:String, onComplete:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {"scale.x": scale, "scale.y": scale}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});			
		});

		Lua_helper.add_callback(lua,"tweenScaleXY", function(id:String, scaleX:Float, scaleY:Float, time:Float, ease:String, onComplete:String, ?bg:Bool = false) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {"scale.x": scaleX, "scale.y": scaleY}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua,"tweenAlpha", function(id:String, toAlpha:Float, time:Float, ease:String, onComplete:String) {
			var shit:Dynamic = getThing(id);
			FlxTween.tween(shit, {alpha: toAlpha}, time, {ease: getFlxEaseByString(ease), onComplete: function(flxTween:FlxTween) { if (onComplete != '' && onComplete != null) {callLua(onComplete,[id]);}}});
		});

		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float) {
			if(PlayState.instance.modchartSprites.exists(obj)) {
				var shit:ModchartSprite = PlayState.instance.modchartSprites.get(obj);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return;
			}

			if(Stage.instance.swagBacks.exists(obj)) {
				var shit:ModchartSprite = Stage.instance.swagBacks.get(obj);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return;
			}
			
			if(PlayState.instance.Stage.swagBacks.exists(obj)) {
				var shit:ModchartSprite = Stage.instance.swagBacks.get(obj);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(poop != null) {
				poop.scale.set(x, y);
				poop.updateHitbox();
				return;
			}

			luaTrace('Couldnt find object: ' + obj);
		});

		Lua_helper.add_callback(lua, "getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});

		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = '') {
			var shit:Dynamic = getThing(obj);
			if(shit != null) {
				shit.blend = blendModeFromString(blend);
				return true;
			}
			luaTrace("Object " + obj + " doesn't exist!");
			return false;
		});

		//tweenShit works here so go with it.
		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});

		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {zoom: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				var color:Int = Std.parseInt(targetColor);
				if(!targetColor.startsWith('0x')) color = Std.parseInt('0xff' + targetColor);

				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				PlayState.instance.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, color, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.modchartTweens.remove(tag);
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});

		Lua_helper.add_callback(lua, "doTweenScale", function(tag:String, vars:String, value:Dynamic, value2:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = getThing(vars);
			cancelTween(tag);
			cancelTween(tag+'Y');
			if(penisExam != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {"scale.x": value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));

				PlayState.instance.modchartTweens.set(tag+'Y', FlxTween.tween(penisExam, {"scale.y": value2}, duration, {ease: getFlxEaseByString(ease)}));
			} else {
				luaTrace('Couldnt find object: ' + vars);
			}
		});


		Lua_helper.add_callback(lua, "triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic) {
			if (name == 'Change Character')
			{
				switch (arg1)
				{
					case 0: changeBFAuto(arg2);
					case 1: changeDadAuto(arg2);
					case 2: changeGFAuto(arg2);
				}

				return;
			}
			var value1:String = arg1;
			var value2:String = arg2;
			PlayState.instance.triggerEventNote(name, value1, value2);
		});

		Lua_helper.add_callback(lua, "getPropertyPsych", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) 
			{
				var coverMeInPiss:Dynamic = null;
				if(PlayState.instance.modchartSprites.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartSprites.get(killMe[0]);
				else if(PlayState.instance.modchartIcons.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartIcons.get(killMe[0]);
				else if(PlayState.instance.modchartCharacters.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartCharacters.get(killMe[0]);
				else if(PlayState.instance.Stage.swagBacks.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.Stage.swagBacks.get(killMe[0]);
				else
					coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
			return Reflect.getProperty(getInstance(), variable);
		});

		Lua_helper.add_callback(lua, "setPropertyPsych", function(variable:String, value:Dynamic) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = null;
				if(PlayState.instance.modchartSprites.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartSprites.get(killMe[0]);
				else if(PlayState.instance.modchartIcons.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartIcons.get(killMe[0]);
				else if(PlayState.instance.modchartCharacters.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartCharacters.get(killMe[0]);
				else if(PlayState.instance.Stage.swagBacks.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.Stage.swagBacks.get(killMe[0]);
				else
					coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			}
			return Reflect.setProperty(getInstance(), variable, value);
		});

		Lua_helper.add_callback(lua, "debugPrint", function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = '') {
			if (text1 == null) text1 = '';
			if (text2 == null) text2 = '';
			if (text3 == null) text3 = '';
			if (text4 == null) text4 = '';
			if (text5 == null) text5 = '';
			luaTrace('' + text1 + text2 + text3 + text4 + text5, true, false);
		});

		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = '') {
			if (PlayState.instance.modchartSprites.exists(obj))
				PlayState.instance.modchartSprites.get(obj).cameras = [cameraFromString(camera)];
			else if (PlayState.instance.modchartIcons.exists(obj))
					PlayState.instance.modchartIcons.get(obj).cameras = [cameraFromString(camera)];
			else if(PlayState.instance.modchartTexts.exists(obj))
				PlayState.instance.modchartTexts.get(obj).cameras = [cameraFromString(camera)];
			else if (PlayState.instance.Stage.swagBacks.exists(obj))
			{
				trace('found it');
				PlayState.instance.Stage.swagBacks.get(obj).cameras = [cameraFromString(camera)];
				trace('set it');
			}
			else
				Stage.instance.toHUD.push(Stage.instance.swagBacks.get(obj));
		});

		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('LEFT_P');
				case 'down': key = PlayState.instance.getControl('DOWN_P');
				case 'up': key = PlayState.instance.getControl('UP_P');
				case 'right': key = PlayState.instance.getControl('RIGHT_P');
				case 'accept': key = PlayState.instance.getControl('ACCEPT');
				case 'back': key = PlayState.instance.getControl('BACK');
				case 'pause': key = PlayState.instance.getControl('PAUSE');
				case 'reset': key = PlayState.instance.getControl('RESET');
				case 'space': key = FlxG.keys.justPressed.SPACE;//an extra key for convinience
			}
			return key;
		});

		Lua_helper.add_callback(lua, "keyPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('LEFT');
				case 'down': key = PlayState.instance.getControl('DOWN');
				case 'up': key = PlayState.instance.getControl('UP');
				case 'right': key = PlayState.instance.getControl('RIGHT');
				case 'space': key = FlxG.keys.pressed.SPACE;//an extra key for convinience
			}
			return key;
		});
		
		Lua_helper.add_callback(lua, "keyReleased", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = PlayState.instance.getControl('LEFT_R');
				case 'down': key = PlayState.instance.getControl('DOWN_R');
				case 'up': key = PlayState.instance.getControl('UP_R');
				case 'right': key = PlayState.instance.getControl('RIGHT_R');
				case 'space': key = FlxG.keys.justReleased.SPACE;//an extra key for convinience
			}
			return key;
		});

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(tag);
			PlayState.instance.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) {
					PlayState.instance.modchartTimers.remove(tag);
				}
				PlayState.instance.Stage.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
		});
		
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) {
			cancelTimer(tag);
		});

		Lua_helper.add_callback(lua,"getMapLength", function(obj:String) {
			var killMe:Array<String> = obj.split('.');
			var shit:Map<String, Dynamic> = Reflect.getProperty(getInstance(), obj);

			if(killMe.length > 1) 
			{
				var coverMeInPiss:Dynamic = null;

				coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);
				
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}

				shit = Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
	
			var daArray:Array<String> = [];

			for (key in shit.keys())
				daArray.push(key);
			
			return daArray.length;
		});

		Lua_helper.add_callback(lua,"getMapKeys", function(obj:String) {
			var killMe:Array<String> = obj.split('.');
			var shit:Map<String, Dynamic> = Reflect.getProperty(getInstance(), obj);

			if(killMe.length > 1) 
			{
				var coverMeInPiss:Dynamic = null;

				coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);
				
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}

				shit = Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
	
			var daArray:Array<String> = [];

			for (key in shit.keys())
				daArray.push(key);
			
			return daArray;
		});

		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String) {
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			PlayState.preloadChar = new Character(0, 0, name);
		});

		Lua_helper.add_callback(lua, "cacheImage", function(name:String) {
			Paths.cacheImage(name);
		});

		Lua_helper.add_callback(lua, "precacheSound", function(name:String) {
			return name; //lol
		});

		Lua_helper.add_callback(lua, "precacheImage", function(name:String) {
			return name; //lol
		});

		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) 
			{
				var coverMeInPiss:Dynamic = null;

				if(PlayState.instance.modchartSprites.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartSprites.get(killMe[0]);
				else if(PlayState.instance.modchartIcons.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartIcons.get(killMe[0]);
				else if(PlayState.instance.modchartCharacters.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartCharacters.get(killMe[0]);
				else if(PlayState.instance.Stage.swagBacks.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.Stage.swagBacks.get(killMe[0]);
				else if (Stage.instance.swagBacks.exists(killMe[0]))
					coverMeInPiss = Stage.instance.swagBacks.get(killMe[0]);
				else
					coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);
					

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
			return Reflect.getProperty(getInstance(), variable);
		});

		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			var killMe:Array<String> = variable.split('.');
		
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = null;

				if (Stage.instance.swagBacks.exists(killMe[0]))
					return Stage.instance.setProperty(variable, value);

				if(PlayState.instance.modchartSprites.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartSprites.get(killMe[0]);
				else if(PlayState.instance.modchartTexts.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartTexts.get(killMe[0]);
				else if(PlayState.instance.modchartIcons.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartIcons.get(killMe[0]);
				else if(PlayState.instance.modchartCharacters.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.modchartCharacters.get(killMe[0]);
				else if(PlayState.instance.Stage.swagBacks.exists(killMe[0]))
					coverMeInPiss = PlayState.instance.Stage.swagBacks.get(killMe[0]);
				else
					coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			}
			
			return Reflect.setProperty(getInstance(), variable, value);
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(Type.resolveClass(classVar), killMe[0]);
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
			return Reflect.getProperty(Type.resolveClass(classVar), variable);
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic) {
			var killMe:Array<String> = variable.split('.');
			if(killMe.length > 1) {
				var coverMeInPiss:Dynamic = Reflect.getProperty(Type.resolveClass(classVar), killMe[0]);
				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}
				return Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			}
			return Reflect.setProperty(Type.resolveClass(classVar), variable, value);
		});

		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic) {

			if (PlayState.instance.Stage.swagGroup.exists(obj))
			{
				trace('swagGroup found');
				var shit = PlayState.instance.Stage.swagGroup.get(obj);
				
				if(Std.isOfType(shit, FlxTypedGroup)) {
					trace('is a FlxTypedGroup');
					return getGroupStuff(shit.members[index], variable);
				}
			}
		
			if(Std.isOfType(Reflect.getProperty(getInstance(), obj), FlxTypedGroup)) {
				return getGroupStuff(Reflect.getProperty(getInstance(), obj).members[index], variable);
			}

			var leArray:Dynamic = Reflect.getProperty(getInstance(), obj);
			var killMe:Array<String> = obj.split('.');

			if (killMe.length > 1) //all this just so I can get a character's camera position
			{
				var coverMeInPiss:Dynamic = null;
				coverMeInPiss = Reflect.getProperty(getInstance(), killMe[0]);

				for (i in 1...killMe.length-1) {
					coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
				}

				leArray = Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}

			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					return leArray[variable];
				}
				return getGroupStuff(leArray, variable);
			}
			luaTrace("Object #" + index + " from group: " + obj + " doesn't exist!");
			return null;
		});

		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic) {

			if (PlayState.instance.Stage.swagGroup.exists(obj))
			{
				trace('swagGroup found');
				var shit = PlayState.instance.Stage.swagGroup.get(obj);
				
				if(Std.isOfType(shit, FlxTypedGroup)) {
					trace('is a FlxTypedGroup');
					return setGroupStuff(shit.members[index], variable, value);
				}
			}

			if(Std.isOfType(Reflect.getProperty(getInstance(), obj), FlxTypedGroup)) {
				setGroupStuff(Reflect.getProperty(getInstance(), obj).members[index], variable, value);
				return;
			}

			var leArray:Dynamic = Reflect.getProperty(getInstance(), obj)[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					leArray[variable] = value;
					return;
				}
				setGroupStuff(leArray, variable, value);
			}
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, image:String, x:Float, y:Float, ?antialiasing:Bool = true) {
			tag = tag.replace('.', '');
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0) {

				var rawPic:Dynamic;

				if (!Paths.currentTrackedAssets.exists(image))
					Paths.cacheImage(image);

				rawPic = Paths.currentTrackedAssets.get(image);

				leSprite.loadGraphic(rawPic);					
			}
			leSprite.antialiasing = antialiasing;
			Stage.instance.swagBacks.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float,spriteType:String="sparrow") {
			tag = tag.replace('.', '');
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			
			switch(spriteType.toLowerCase()){
			
				case "texture" | "textureatlas"|"tex":
					leSprite.frames = AtlasFrameMaker.construct(image);
					
				case "packer" |"packeratlas"|"pac":
					leSprite.frames = Paths.getPackerAtlas(image);
				case "xmlless":
				{
					/*var rawPic:Dynamic;

					if (!Paths.currentTrackedAssets.exists(image))
						Paths.cacheImage(image);

					rawPic = Paths.currentTrackedAssets.get(image);
					leSprite.loadGraphic(rawPic, true, width, height);*/
				}
				default:
				{
					var rawPic:Dynamic;
					var rawXml:String;

					if (!Paths.currentTrackedAssets.exists(image))
						Paths.cacheImage(image);

					rawPic = Paths.currentTrackedAssets.get(image);

					if (FileSystem.exists(FileSystem.absolutePath("assets/shared/images/"+image+".xml")))
						rawXml = File.getContent(FileSystem.absolutePath("assets/shared/images/"+image+".xml"));
					else if (FileSystem.exists(Paths.modsXml(image)))
						rawXml = File.getContent(Paths.modsXml(image));
					else
						rawXml = File.getContent(Paths.xmlNew('images/' + image));

					leSprite.frames = FlxAtlasFrames.fromSparrow(rawPic,rawXml);
				}
			}
			
			Stage.instance.swagBacks.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite2", function(tag:String, image:String, x:Float, y:Float,width:Int, height:Int) {
			tag = tag.replace('.', '');
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			
			var rawPic:Dynamic;

			if (!Paths.currentTrackedAssets.exists(image))
				Paths.cacheImage(image);

			rawPic = Paths.currentTrackedAssets.get(image);
			leSprite.loadGraphic(rawPic, true, width, height);
			
			Stage.instance.swagBacks.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int, height:Int, color:String) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

			if(Stage.instance.swagBacks.exists(obj)) {
				Stage.instance.swagBacks.get(obj).makeGraphic(width, height, colorNum);
				return;
			}

			var object:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(object != null) {
				object.makeGraphic(width, height, colorNum);
			}
		});

		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			if(Stage.instance.swagBacks.exists(obj)) {
				var cock:ModchartSprite = Stage.instance.swagBacks.get(obj);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			if(PlayState.instance.modchartSprites.exists(obj)) {
				var cock:ModchartSprite = PlayState.instance.modchartSprites.get(obj);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}
			
			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});
		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			var strIndices:Array<String> = indices.trim().split(',');
			var die:Array<Int> = [];
			for (i in 0...strIndices.length) {
				die.push(Std.parseInt(strIndices[i]));
			}

			if(Stage.instance.swagBacks.exists(obj)) {
				var pussy:ModchartSprite = Stage.instance.swagBacks.get(obj);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
				return;
			}
			
			var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(pussy != null) {
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, indices:String, framerate:Int = 24, loop:Bool = true) {
			var strIndices:Array<String> = indices.trim().split(',');
			var die:Array<Int> = [];
			for (i in 0...strIndices.length) {
				die.push(Std.parseInt(strIndices[i]));
			}

			if(Stage.instance.swagBacks.exists(obj)) {
				var cock:ModchartSprite = Stage.instance.swagBacks.get(obj);
				cock.animation.add(name, die, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}
			
			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.add(name, die, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "objectPlayAnimation", function(obj:String, name:String, forced:Bool = false) {
			var spr:Dynamic = getThing(obj);
			if(spr != null) {
				spr.animation.play(name, forced);
			}
		});

		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, place:Dynamic = -1) {
			if (Stage.instance.swagBacks.exists(tag))
			{
				var shit = Stage.instance.swagBacks.get(tag);
	
				if (place == -1 || place == false)
					Stage.instance.toAdd.push(shit);
				else
				{
					if (place == true){place = 2;}
					Stage.instance.layInFront[place].push(shit);
				}
			}
		});

		//push directly to playstate
		Lua_helper.add_callback(lua, "makeLuaSpritePS", function(tag:String, image:String, x:Float, y:Float, ?antialiasing:Bool = true) {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0) {
				var rawPic:Dynamic;

				if (!Paths.currentTrackedAssets.exists(image))
					Paths.cacheImage(image);

				rawPic = Paths.currentTrackedAssets.get(image);

				leSprite.loadGraphic(rawPic);					
			}
			leSprite.antialiasing = antialiasing;
			PlayState.instance.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
		});

		Lua_helper.add_callback(lua, "makeAnimatedLuaSpritePS", function(tag:String, image:String, x:Float, y:Float,spriteType:String="sparrow", ?antialiasing:Bool = true) {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			
			switch(spriteType.toLowerCase()){
			
				case "texture" | "textureatlas"|"tex":
					leSprite.frames = AtlasFrameMaker.construct(image);
					
				case "packer" |"packeratlas"|"pac":
					leSprite.frames = Paths.getPackerAtlas(image);
				
				default:
				{
					var rawPic:Dynamic;
					var rawXml:String;

					if (!Paths.currentTrackedAssets.exists(image))
						Paths.cacheImage(image);

					rawPic = Paths.currentTrackedAssets.get(image);

					if (FileSystem.exists(FileSystem.absolutePath("assets/shared/images/"+image+".xml")))
						rawXml = File.getContent(FileSystem.absolutePath("assets/shared/images/"+image+".xml"));
					else
						rawXml = File.getContent(Paths.xmlNew('images/' + image));

					leSprite.frames = FlxAtlasFrames.fromSparrow(rawPic,rawXml);
				}
			}
			
			
			leSprite.antialiasing = antialiasing;
			PlayState.instance.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "addLuaSpritePS", function(tag:String, front:Bool = false) {
			if(PlayState.instance.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				if(!shit.wasAdded) {
					if(front)
					{
						getInstance().add(shit);
					}
					else
					{
						var position:Int = PlayState.instance.members.indexOf(PlayState.instance.gf);
						if(PlayState.instance.members.indexOf(PlayState.instance.boyfriend) < position) {
							position = PlayState.instance.members.indexOf(PlayState.instance.boyfriend);
						} else if(PlayState.instance.members.indexOf(PlayState.instance.dad) < position) {
							position = PlayState.instance.members.indexOf(PlayState.instance.dad);
						}
						PlayState.instance.insert(position, shit);
					}
					shit.wasAdded = true;
					//trace('added a thing: ' + tag);
				}
			}
		});


				//Tween shit, but for strums
		Lua_helper.add_callback(lua, "noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String, ?player:Bool = false) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (player)
				testicle = PlayState.instance.playerStrums.members[note];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String, ?player:Bool = false) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if (player)
				testicle = PlayState.instance.playerStrums.members[note];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {direction: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) {
			cancelTween(tag);
		});

		Lua_helper.add_callback(lua, "animExists", function(tag:String, anim:String){
			var shit:Dynamic;

			shit = getThing(tag);

			if (PlayState.instance.modchartCharacters.exists(tag))
				shit = PlayState.instance.modchartCharacters.get(tag);
			if (Stage.instance.swagBacks.exists(tag))
				shit = Stage.instance.swagBacks.get(tag);
			
			return shit.animation.getByName(anim) != null;
		});

		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String) {
			if(PlayState.instance.modchartSprites.exists(obj))
				return getInstance().members.indexOf(PlayState.instance.modchartSprites.get(obj));
			if(PlayState.instance.modchartTexts.exists(obj))
				return getInstance().members.indexOf(PlayState.instance.modchartTexts.get(obj));
			if(PlayState.instance.modchartIcons.exists(obj))
				return getInstance().members.indexOf(PlayState.instance.modchartIcons.get(obj));
			if(PlayState.instance.modchartCharacters.exists(obj))
				return getInstance().members.indexOf(PlayState.instance.modchartCharacters.get(obj));
			if(PlayState.instance.Stage.swagBacks.exists(obj))
				return getInstance().members.indexOf(PlayState.instance.Stage.swagBacks.get(obj));


			var leObj:FlxBasic = Reflect.getProperty(getInstance(), obj);
			if(leObj != null)
			{
				return getInstance().members.indexOf(leObj);
			}
			luaTrace("Object " + obj + " doesn't exist!");
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int) {
			if(PlayState.instance.modchartSprites.exists(obj)) {
				var spr:ModchartSprite = PlayState.instance.modchartSprites.get(obj);
				if(spr.wasAdded) {
					getInstance().remove(spr, true);
				}
				getInstance().insert(position, spr);
				return;
			}
			if(PlayState.instance.modchartCharacters.exists(obj)) {
				var spr:Character = PlayState.instance.modchartCharacters.get(obj);
				getInstance().remove(spr, true);
				getInstance().insert(position, spr);
				return;
			}
			if(PlayState.instance.modchartIcons.exists(obj)) {
				var spr:ModchartIcon = PlayState.instance.modchartIcons.get(obj);
				getInstance().remove(spr, true);
				getInstance().insert(position, spr);
				return;
			}
			if(PlayState.instance.modchartTexts.exists(obj)) {
				var spr:ModchartText = PlayState.instance.modchartTexts.get(obj);
				if(spr.wasAdded) {
					getInstance().remove(spr, true);
				}
				getInstance().insert(position, spr);
				return;
			}
			if(PlayState.instance.Stage.swagBacks.exists(obj)) {
				var spr:Dynamic = PlayState.instance.Stage.swagBacks.get(obj);
				getInstance().remove(spr, true);
				getInstance().insert(position, spr);
				return;
			}

			var leObj:FlxBasic = Reflect.getProperty(getInstance(), obj);
			if(leObj != null) {
				getInstance().remove(leObj, true);
				getInstance().insert(position, leObj);
				return;
			}
			luaTrace("Object " + obj + " doesn't exist!");
		});

		Lua_helper.add_callback(lua, "playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null) {
			var soundPath:Dynamic;
			var isCustomSound:Bool = false;

			if (Assets.exists(Paths.sound(sound)))
				soundPath = Paths.sound(sound);
			else
			{
				if (FileSystem.exists(Paths.sound(sound)))
				{
					isCustomSound = true;
					soundPath = Paths.sound(sound);
				}
				else
				{
					soundPath = Paths.sound('nogood');
					luaTrace('Sound not found!');
				}
			}

			if(tag != null && tag.length > 0) {
				tag = tag.replace('.', '');
				if(PlayState.instance.modchartSounds.exists(tag)) {
					PlayState.instance.modchartSounds.get(tag).stop();
				}
	
				PlayState.instance.modchartSounds.set(tag, FlxG.sound.play((isCustomSound ? (Paths.currentTrackedSounds.exists(sound) ? Paths.currentTrackedSounds.get(sound) : Sound.fromFile(soundPath)): soundPath), volume, false, function() {
					PlayState.instance.modchartSounds.remove(tag);
					PlayState.instance.callOnLuas('onSoundFinished', [tag]);
				}));
				return;
			}
			if (isCustomSound)
				FlxG.sound.play((Paths.currentTrackedSounds.exists(sound) ? Paths.currentTrackedSounds.get(sound) : Sound.fromFile(soundPath)), volume);
			else
				FlxG.sound.play(soundPath, volume);
		});

		Lua_helper.add_callback(lua, "stopSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).stop();
				PlayState.instance.modchartSounds.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "pauseSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).pause();
			}
		});
		Lua_helper.add_callback(lua, "resumeSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).play();
			}
		});
		Lua_helper.add_callback(lua, "soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
			}
			
		});
		Lua_helper.add_callback(lua, "soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeOut(duration, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeOut(duration, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					PlayState.instance.modchartSounds.remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).volume;
			}
			return PlayState.instance.vocals.volume;
		});
		Lua_helper.add_callback(lua, "setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).volume = value;
			}
		});
		Lua_helper.add_callback(lua, "getActualSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).getActualVolume();
			}
			return PlayState.instance.vocals.getActualVolume();
		});
		Lua_helper.add_callback(lua, "getSoundTime", function(tag:String) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).time;
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundTime", function(tag:String, value:Float) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound != null) {
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;
					if(wasResumed) theSound.play();
				}
			}
		});

		Lua_helper.add_callback(lua, "addEffect", function(camera:String,effect:String, ?val1:Dynamic, ?val2:Dynamic, ?val3:Dynamic, ?val4:Dynamic) {
			
			PlayState.instance.addShaderToCamera(camera, getEffectFromString(effect, val1, val2, val3, val4));
			
		});
		Lua_helper.add_callback(lua, "clearEffects", function(camera:String) {
			PlayState.instance.clearShaderFromCamera(camera);
		});

		Lua_helper.add_callback(lua, "characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false) {
			switch(character.toLowerCase()) {
				case 'dad':
					if(PlayState.instance.dad.animOffsets.exists(anim))
						PlayState.instance.dad.playAnim(anim, forced);
				case 'gf' | 'girlfriend':
					if(PlayState.instance.gf.animOffsets.exists(anim))
						PlayState.instance.gf.playAnim(anim, forced);
				default: 
					if(PlayState.instance.boyfriend.animOffsets.exists(anim))
						PlayState.instance.boyfriend.playAnim(anim, forced);
			}
		});


		/*Lua_helper.add_callback(lua, "close", function(printMessage:Bool) {
			if(!gonnaClose) {
				if(printMessage) {
					luaTrace('Stopping lua script: ' + scriptName);
				}
				if (PlayState.instance != null)
					PlayState.instance.Stage.closeLuas.push(this);
				else
					Stage.instance.closeLuas.push(this);
			}
			gonnaClose = true;
		});*/

		Lua_helper.add_callback(lua, "characterDance", function(character:String) {
			if(PlayState.instance.modchartCharacters.exists(character)) {
				var spr:Character = PlayState.instance.modchartCharacters.get(character);
				spr.dance();
			}
			else
				getActorByName(character).dance();
		});
		
		Lua_helper.add_callback(lua, "setOffset", function(id:String, x:Float, y:Float) {
			getActorByName(id).offset.set(x, y);
		});
    }

	public function getThing(id:String)
	{
		var shit:Dynamic;

		if(Stage.instance.swagBacks.exists(id))
			shit = Stage.instance.swagBacks.get(id);
		else if(PlayState.instance.modchartSprites.exists(id))
			shit = PlayState.instance.modchartSprites.get(id);
		else if(PlayState.instance.modchartTexts.exists(id))
			shit = PlayState.instance.modchartTexts.get(id);
		else if(PlayState.instance.modchartIcons.exists(id))
			shit = PlayState.instance.modchartIcons.get(id);
		else if(PlayState.instance.modchartCharacters.exists(id))
			shit = PlayState.instance.modchartCharacters.get(id);
		else
			shit = Reflect.getProperty(PlayState.instance, id);
			
		return shit;
	}

	function getEffectFromString(?effect:String = '', ?val1:Dynamic, ?val2:Dynamic, ?val3:Dynamic , ?val4:Dynamic):ShaderEffect {
		switch(effect.toLowerCase().trim()) {
			case 'grayscale' | 'greyscale' : return new GreyscaleEffect();
			case 'invert' | 'invertcolor': return new InvertColorsEffect();
			case 'tiltshift': return new TiltshiftEffect(val1,val2);
			case 'grain': return new GrainEffect(val1,val2,val3);
			case 'scanline': return new ScanlineEffect(val1);
			case 'outline': return new OutlineEffect(val1, val2, val3, val4);
			case 'distortion': return new DistortBGEffect(val1, val2, val3);
			case 'vcr': return new VCRDistortionEffect(val1,val2,val3,val4);
			case 'glitch': return new GlitchEffect(val1, val2, val3);
			case 'vcr2': return new VCRDistortionEffect2(); //the tails doll one
			case '3d': return new ThreeDEffect(val1, val2, val3, val4);
			case 'bloom': return new BloomEffect(val1/512.0,val2);
			case 'rgbshiftglitch' | 'rgbshift': return new RGBShiftGlitchEffect(val1, val2);
			case 'pulse': return new PulseEffect(val1,val2,val3);
			case 'chromaticabberation' | 'ca': return new ChromaticAberrationEffect(val1);
			case 'sketch': return new SketchEffect();
		}
		return new GreyscaleEffect();
	}

    public function executeState(name,args:Array<Dynamic>)
    {
        return Lua.tostring(lua,callLua(name, args));
    }

	function cameraFromString(cam:String):FlxCamera 
	{
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
		}
		return PlayState.instance.camGame;
	}

	function cancelTimer(tag:String) {
		if(PlayState.instance.modchartTimers.exists(tag)) {
			var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
	}

	function cancelTween(tag:String) {
		if(PlayState.instance.modchartTweens.exists(tag)) {
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
	}
	
	function tweenShit(tag:String, vars:String) {
		cancelTween(tag);
		var variables:Array<String> = vars.replace(' ', '').split('.');
		var sexyProp:Dynamic = Reflect.getProperty(getInstance(), variables[0]);
		if(Stage.instance.swagBacks.exists(variables[0])) {
			sexyProp = Stage.instance.swagBacks.get(variables[0]);
		}
		if(PlayState.instance.modchartTexts.exists(variables[0])) {
			sexyProp = PlayState.instance.modchartTexts.get(variables[0]);
		}

		for (i in 1...variables.length) {
			sexyProp = Reflect.getProperty(sexyProp, variables[i]);
		}
		return sexyProp;
	}

	function getFlxEaseByString(?ease:String = '') {
		switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	function resetSpriteTag(tag:String) {
		if(!PlayState.instance.modchartSprites.exists(tag)) {
			return;
		}
		
		var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			PlayState.instance.remove(pee, true);
		}
		pee.destroy();
		PlayState.instance.modchartSprites.remove(tag);
	}

	function blendModeFromString(blend:String):BlendMode {
		switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}
		return NORMAL;
	}

	inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}
#end