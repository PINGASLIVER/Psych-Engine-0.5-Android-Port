package;

import Section.SwagSection;
import Song.SwagSong;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import ModchartState;
import lime.utils.Assets;

#if sys
import lime.media.AudioBuffer;
import flash.media.Sound;
#end

using StringTools;

class EditorPlayState extends MusicBeatState
{
	// Yes, this is mostly a copy of PlayState, it's kinda dumb to make a direct copy of it but... ehhh
	private var strumLine:FlxSprite;
	private var comboGroup:FlxTypedGroup<FlxSprite>;
	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_left'		=> [A, LEFT],
		'note_down'		=> [S, DOWN],
		'note_up'		=> [W, UP],
		'note_right'	=> [D, RIGHT],
		
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_up'			=> [W, UP],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R, NONE],
		
		'volume_mute'	=> [ZERO, NONE],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN, NONE],
		'debug_2'		=> [EIGHT, NONE]
	];

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	var isPixel:Bool = false;

	var generatedMusic:Bool = false;
	var vocals:FlxSound;

	var startOffset:Float = 0;
	var startPos:Float = 0;

	public function new(startPos:Float) {
		this.startPos = startPos;
		Conductor.songPosition = startPos - startOffset;

		startOffset = Conductor.crochet;
		timerToStart = startOffset;
		super();
	}

	var scoreTxt:FlxText;
	var stepTxt:FlxText;
	var beatTxt:FlxText;
	
	var timerToStart:Float = 0;
	private var noteTypeMap:Map<String, Bool> = new Map<String, Bool>();
	
	// Less laggy controls
	private var keysArray:Array<Dynamic>;

	public static var instance:EditorPlayState;

	override function create()
	{
		instance = this;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = FlxColor.fromHSB(FlxG.random.int(0, 359), FlxG.random.float(0, 0.8), FlxG.random.float(0.3, 1));
		add(bg);

		keysArray = [
			copyKey(keyBinds.get('note_left')),
			copyKey(keyBinds.get('note_down')),
			copyKey(keyBinds.get('note_up')),
			copyKey(keyBinds.get('note_right'))
		];
		
		strumLine = new FlxSprite(42, 50).makeGraphic(FlxG.width, 10);
		if(FlxG.save.data.downscroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();
		
		comboGroup = new FlxTypedGroup<FlxSprite>();
		add(comboGroup);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);

		generateStaticArrows(0);
		generateStaticArrows(1);
		/*if(ClientPrefs.middleScroll) {
			opponentStrums.forEachAlive(function (note:StrumNote) {
				note.visible = false;
			});
		}*/
		
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;
		
		if (PlayState.SONG.needsVoices)
		{
			if (!Assets.exists(Paths.voices(PlayState.SONG.song)))
			{
				if (Paths.currentTrackedSounds.exists(Paths.voices2(PlayState.SONG.song)))
					vocals = new FlxSound().loadEmbedded(Paths.currentTrackedSounds.get(Paths.voices2(PlayState.SONG.song)));
				else
					vocals = new FlxSound().loadEmbedded(Sound.fromFile(Paths.voices2(PlayState.SONG.song)));
			}
			else
				vocals = new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song));
		}		
		else
			vocals = new FlxSound();

		generateSong(PlayState.SONG.song);
		/*#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys()) {
			var luaToLoad:String = Paths.modFolders('custom_notetypes/' + notetype + '.lua');
			if(sys.FileSystem.exists(luaToLoad)) {
				var lua:editors.EditorLua = new editors.EditorLua(luaToLoad);
				new FlxTimer().start(0.1, function (tmr:FlxTimer) {
					lua.stop();
					lua = null;
				});
			}
		}
		#end
		noteTypeMap.clear();
		noteTypeMap = null;*/

		scoreTxt = new FlxText(0, FlxG.height - 50, FlxG.width, "Hits: 0 | Misses: 0", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		//scoreTxt.visible = !ClientPrefs.hideHud;
		add(scoreTxt);
		
		beatTxt = new FlxText(10, 610, FlxG.width, "Beat: 0", 20);
		beatTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		beatTxt.scrollFactor.set();
		beatTxt.borderSize = 1.25;
		add(beatTxt);

		stepTxt = new FlxText(10, 640, FlxG.width, "Step: 0", 20);
		stepTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		stepTxt.scrollFactor.set();
		stepTxt.borderSize = 1.25;
		add(stepTxt);

		var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		add(tipText);
		FlxG.mouse.visible = false;

		//sayGo();
		/*if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}*/
		super.create();
	}

	function sayGo() {
		var go:FlxSprite = new FlxSprite().loadGraphic(Paths.image('go'));
		go.scrollFactor.set();

		go.updateHitbox();

		go.screenCenter();
		//go.antialiasing = ClientPrefs.globalAntialiasing;
		add(go);
		FlxTween.tween(go, {y: go.y += 100, alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				go.destroy();
			}
		});
		FlxG.sound.play(Paths.sound('introGo'), 0.6);
	}

	//var songScore:Int = 0;
	var songHits:Int = 0;
	var songMisses:Int = 0;
	var startingSong:Bool = true;
	private function generateSong(dataPath:String):Void
	{
		if (!Assets.exists(Paths.inst(PlayState.SONG.song)))
		{
			if (Paths.currentTrackedSounds.exists(Paths.inst2(PlayState.SONG.song)))
				FlxG.sound.playMusic(Paths.currentTrackedSounds.get(Paths.inst2(PlayState.SONG.song)), 1, false);
			else
				FlxG.sound.playMusic(Sound.fromFile(Paths.inst2(PlayState.SONG.song)), 1, false);
		}
		else
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 1, false);
			
		FlxG.sound.music.pause();
		FlxG.sound.music.onComplete = endSong;
		vocals.pause();
		vocals.volume = 0;

		var songData = PlayState.SONG;
		Conductor.changeBPM(songData.bpm);
		
		notes = new FlxTypedGroup<Note>();
		add(notes);
		
		var noteData:Array<SwagSection>;

		// NEW SHIT
		noteData = songData.notes;

		var playerCounter:Int = 0;

		var daBeats:Int = 0; // Not exactly representative of 'daBeats' lol, just how much it has looped

		for (section in noteData)
		{
			for (songNotes in section.sectionNotes)
			{
				if(songNotes[1] > -1) { //Real notes
					var daStrumTime:Float = songNotes[0];
					if(daStrumTime >= startPos) {
						var daNoteData:Int = Std.int(songNotes[1] % 4);

						var gottaHitNote:Bool = section.mustHitSection;

						if (songNotes[1] > 3)
						{
							gottaHitNote = !section.mustHitSection;
						}

						var oldNote:Note;
						if (unspawnNotes.length > 0)
							oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];
						else
							oldNote = null;

						var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote);
						swagNote.mustPress = gottaHitNote;
						swagNote.sustainLength = songNotes[2];
						swagNote.noteType = songNotes[3];
						if(!Std.isOfType(songNotes[3], String)) swagNote.noteType = ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts
						swagNote.scrollFactor.set();

						var susLength:Float = swagNote.sustainLength;

						susLength = susLength / Conductor.stepCrochet;
						unspawnNotes.push(swagNote);

						var floorSus:Int = Math.floor(susLength);
						if(floorSus > 0) {
							for (susNote in 0...floorSus+1)
							{
								oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

								var sustainNote:Note = new Note(daStrumTime + (Conductor.stepCrochet * susNote) + (Conductor.stepCrochet / FlxMath.roundDecimal(PlayState.SONG.speed, 2)), daNoteData, oldNote, true);
								sustainNote.mustPress = gottaHitNote;
								sustainNote.noteType = swagNote.noteType;
								sustainNote.scrollFactor.set();
								unspawnNotes.push(sustainNote);

								if (sustainNote.mustPress)
								{
									sustainNote.x += FlxG.width / 2; // general offset
								}
							}
						}

						if (swagNote.mustPress)
						{
							swagNote.x += FlxG.width / 2; // general offset
						}

						if(!noteTypeMap.exists(swagNote.noteType)) {
							noteTypeMap.set(swagNote.noteType, true);
						}
					}
				}
			}
			daBeats += 1;
		}

		unspawnNotes.sort(sortByShit);
		generatedMusic = true;
	}

	function startSong():Void
	{
		startingSong = false;
		FlxG.sound.music.time = startPos;
		FlxG.sound.music.play();
		FlxG.sound.music.volume = 1;
		vocals.volume = 1;
		vocals.time = startPos;
		vocals.play();
	}

	function sortByShit(Obj1:Note, Obj2:Note):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	private function endSong() {
		LoadingState.loadAndSwitchState(new ChartingState());
	}

	override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			LoadingState.loadAndSwitchState(new ChartingState());
		}

		if (startingSong) {
			timerToStart -= elapsed * 1000;
			Conductor.songPosition = startPos - timerToStart;
			if(timerToStart < 0) {
				startSong();
			}
		} else {
			Conductor.songPosition += elapsed * 1000;
		}

		var roundedSpeed:Float = FlxMath.roundDecimal(PlayState.SONG.speed, 2);
		if (unspawnNotes[0] != null)
		{
			var time:Float = 1500;
			if(roundedSpeed < 1) time /= roundedSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}
		
		if (generatedMusic)
		{
			var fakeCrochet:Float = (60 / PlayState.SONG.bpm) * 1000;
			notes.forEachAlive(function(daNote:Note)
			{
				/*if (daNote.y > FlxG.height)
				{
					daNote.active = false;
					daNote.visible = false;
				}
				else
				{
					daNote.visible = true;
					daNote.active = true;
				}*/

				// i am so fucking sorry for this if condition
				var strumX:Float = 0;
				var strumY:Float = 0;
				if(daNote.mustPress) {
					strumX = playerStrums.members[daNote.noteData].x;
					strumY = playerStrums.members[daNote.noteData].y;
				} else {
					strumX = opponentStrums.members[daNote.noteData].x;
					strumY = opponentStrums.members[daNote.noteData].y;
				}

				strumX += daNote.offsetX;
				strumY += daNote.offsetY;
				var center:Float = strumY + Note.swagWidth / 2;

				//if(daNote.copyX) {
					daNote.x = strumX;
				//}
				//if(daNote.copyY) {
					if (FlxG.save.data.downscroll) {
						daNote.y = (strumY + 0.45 * (Conductor.songPosition - daNote.strumTime) * roundedSpeed);
						if (daNote.isSustainNote) {
							//Jesus fuck this took me so much mother fucking time AAAAAAAAAA
							if (daNote.animation.curAnim.name.endsWith('end')) {
								daNote.y += 10.5 * (fakeCrochet / 400) * 1.5 * roundedSpeed + (46 * (roundedSpeed - 1));
								daNote.y -= 46 * (1 - (fakeCrochet / 600)) * roundedSpeed;
								if(isPixel) {
									daNote.y += 8;
								} else {
									daNote.y -= 19;
								}
							} 
							daNote.y += (Note.swagWidth / 2) - (60.5 * (roundedSpeed - 1));
							daNote.y += 27.5 * ((PlayState.SONG.bpm / 100) - 1) * (roundedSpeed - 1);

							if(daNote.mustPress || !daNote.ignoreNote)
							{
								if(daNote.y - daNote.offset.y * daNote.scale.y + daNote.height >= center
									&& (!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
								{
									var swagRect = new FlxRect(0, 0, daNote.frameWidth, daNote.frameHeight);
									swagRect.height = (center - daNote.y) / daNote.scale.y;
									swagRect.y = daNote.frameHeight - swagRect.height;

									daNote.clipRect = swagRect;
								}
							}
						}
					} else {
						daNote.y = (strumY - 0.45 * (Conductor.songPosition - daNote.strumTime) * roundedSpeed);

						if(daNote.mustPress || !daNote.ignoreNote)
						{
							if (daNote.isSustainNote
								&& daNote.y + daNote.offset.y * daNote.scale.y <= center
								&& (!daNote.mustPress || (daNote.wasGoodHit || (daNote.prevNote.wasGoodHit && !daNote.canBeHit))))
							{
								var swagRect = new FlxRect(0, 0, daNote.width / daNote.scale.x, daNote.height / daNote.scale.y);
								swagRect.y = (center - daNote.y) / daNote.scale.y;
								swagRect.height -= swagRect.y;

								daNote.clipRect = swagRect;
							}
						}
					}
				///}

				if (!daNote.mustPress && daNote.wasGoodHit && !daNote.ignoreNote)
				{
					if (PlayState.SONG.needsVoices)
						vocals.volume = 1;

					var time:Float = 0.15;
					if(daNote.isSustainNote && !daNote.animation.curAnim.name.endsWith('end')) {
						time += 0.15;
					}
					StrumPlayAnim(true, Std.int(Math.abs(daNote.noteData)) % 4, time);

					if (!daNote.isSustainNote)
					{
						daNote.kill();
						notes.remove(daNote, true);
						daNote.destroy();
					}
				}

				var doKill:Bool = daNote.y < -daNote.height;
				if(FlxG.save.data.downscroll) doKill = daNote.y > FlxG.height;

				if (doKill)
				{
					if (daNote.mustPress)
					{
						if (daNote.tooLate || !daNote.wasGoodHit)
						{
							//Dupe note remove
							notes.forEachAlive(function(note:Note) {
								if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 10) {
									note.kill();
									notes.remove(note, true);
									note.destroy();
								}
							});

							if(!daNote.ignoreNote) {
								songMisses++;
								vocals.volume = 0;
							}
						}
					}

					daNote.active = false;
					daNote.visible = false;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}
			});
		}

		keyShit();
		scoreTxt.text = 'Hits: ' + songHits + ' | Misses: ' + songMisses;
		beatTxt.text = 'Beat: ' + curBeat;
		stepTxt.text = 'Step: ' + curStep;
		super.update(elapsed);
	}
	
	override public function onFocus():Void
	{
		vocals.play();

		super.onFocus();
	}
	
	override public function onFocusLost():Void
	{
		vocals.pause();

		super.onFocusLost();
	}

	override function beatHit()
	{
		super.beatHit();

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, FlxG.save.data.downscroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}
	}

	override function stepHit()
	{
		super.stepHit();
		if (FlxG.sound.music.time > Conductor.songPosition + 20 || FlxG.sound.music.time < Conductor.songPosition - 20)
		{
			resyncVocals();
		}
	}

	function resyncVocals():Void
	{
		vocals.pause();

		FlxG.sound.music.play();
		Conductor.songPosition = FlxG.sound.music.time;
		vocals.time = Conductor.songPosition;
		vocals.play();
	}
	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		//trace('Pressed: ' + eventKey);

		if (key > -1 && (FlxG.keys.checkStatus(eventKey, JUST_PRESSED)))
		{
			if(generatedMusic)
			{
				//more accurate hit time for the ratings?
				var lastTime:Float = Conductor.songPosition;
				Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !FlxG.save.data.ghost;

				// heavily based on my own code LOL if it aint broke dont fix it
				var pressNotes:Array<Note> = [];
				//var notesDatas:Array<Int> = [];
				var notesStopped:Bool = false;

				trace('test!');
				var sortedNotesList:Array<Note> = [];
				notes.forEachAlive(function(daNote:Note)
				{
					if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit)
					{
						if(daNote.noteData == key && !daNote.isSustainNote)
						{
							trace('pushed note!');
							sortedNotesList.push(daNote);
							//notesDatas.push(daNote.noteData);
						}
						canMiss = true;
					}
				});
				sortedNotesList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

				if (sortedNotesList.length > 0) {
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes) {
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1) {
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							} else
								notesStopped = true;
						}
							
						// eee jack detection before was not super good
						if (!notesStopped) {
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}

					}
				}
				else if (canMiss && !FlxG.save.data.ghost) {
					noteMiss(key);
				}

				//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
				Conductor.songPosition = lastTime;
			}

			var spr:StrumNote = playerStrums.members[key];
			if(spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
		}
	}
		
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		if(key > -1)
		{
			var spr:StrumNote = playerStrums.members[key];
			if(spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
		}
		//trace('released: ' + controlArray);
	}

	public static function copyKey(arrayToCopy:Array<FlxKey>):Array<FlxKey> {
		var copiedArray:Array<FlxKey> = arrayToCopy.copy();
		var i:Int = 0;
		var len:Int = copiedArray.length;

		while (i < len) {
			if(copiedArray[i] == NONE) {
				copiedArray.remove(NONE);
				--i;
			}
			i++;
			len = copiedArray.length;
		}
		return copiedArray;
	}

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...keysArray.length)
			{
				for (j in 0...keysArray[i].length)
				{
					if(key == keysArray[i][j])
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	private function keyShit():Void
	{
		// HOLDING

		var up = controls.UP;
		var right = controls.RIGHT;
		var down = controls.DOWN;
		var left = controls.LEFT;
		var controlHoldArray:Array<Bool> = [left, down, up, right];
		
		// TO DO: Find a better way to handle controller inputs, this should work for now
		/*if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [controls.NOTE_LEFT_P, controls.NOTE_DOWN_P, controls.NOTE_UP_P, controls.NOTE_RIGHT_P];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyPress(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true, -1, keysArray[i][0]));
				}
			}
		}*/

		// FlxG.watch.addQuick('asdfa', upP);
		if (generatedMusic)
		{
			// rewritten inputs???
			notes.forEachAlive(function(daNote:Note)
			{
				// hold note functions
				if (daNote.isSustainNote && controlHoldArray[daNote.noteData] && daNote.canBeHit 
				&& daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit) {
					goodNoteHit(daNote);
				}
			});
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		/*if(ClientPrefs.controllerMode)
		{
			var controlArray:Array<Bool> = [controls.NOTE_LEFT_R, controls.NOTE_DOWN_R, controls.NOTE_UP_R, controls.NOTE_RIGHT_R];
			if(controlArray.contains(true))
			{
				for (i in 0...controlArray.length)
				{
					if(controlArray[i])
						onKeyRelease(new KeyboardEvent(KeyboardEvent.KEY_UP, true, true, -1, keysArray[i][0]));
				}
			}
		}*/
	}

	var combo:Int = 0;
	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			switch(note.noteType) {
				case 'Hurt Note': //Hurt note
					noteMiss(note.noteData);
					--songMisses;
					if(!note.isSustainNote) {
						//if(!note.noteSplashDisabled) {
							spawnNoteSplashOnNote(note);
						//}
					}

					note.wasGoodHit = true;
					vocals.volume = 0;

					if (!note.isSustainNote)
					{
						note.kill();
						notes.remove(note, true);
						note.destroy();
					}
					return;
			}

			if (!note.isSustainNote)
			{
				popUpScore(note);
				combo += 1;
				songHits++;
				if(combo > 9999) combo = 9999;
			}

			playerStrums.forEach(function(spr:StrumNote)
			{
				if (Math.abs(note.noteData) == spr.ID)
				{
					spr.playAnim('confirm', true);
				}
			});

			note.wasGoodHit = true;
			vocals.volume = 1;

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	function noteMiss(direction:Int = 1):Void
	{
		combo = 0;

		//songScore -= 10;
		songMisses++;

		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		vocals.volume = 0;
	}

	var COMBO_X:Float = 400;
	var COMBO_Y:Float = 340;
	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition);

		vocals.volume = 1;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.x = COMBO_X;
		coolText.y = COMBO_Y;
		//

		var rating:FlxSprite = new FlxSprite();
		//var score:Int = 350;

		var daRating:String = "sick";

		if (noteDiff > Conductor.safeZoneOffset * 0.75)
		{
			daRating = 'shit';
			//score = 50;
		}
		else if (noteDiff > Conductor.safeZoneOffset * 0.5)
		{
			daRating = 'bad';
			//score = 100;
		}
		else if (noteDiff > Conductor.safeZoneOffset * 0.25)
		{
			daRating = 'good';
			//score = 200;
		}

		if(daRating == 'sick')
		{
			spawnNoteSplashOnNote(note);
		}
		//songScore += score;

		/* if (combo > 60)
				daRating = 'sick';
			else if (combo > 12)
				daRating = 'good'
			else if (combo > 4)
				daRating = 'bad';
			*/

		var pixelShitPart1:String = "";
		var pixelShitPart2:String = '';

		if (isPixel)
		{
			pixelShitPart1 = 'pixelUI/';
			pixelShitPart2 = '-pixel';
		}

		rating.loadGraphic(Paths.image(pixelShitPart1 + daRating + pixelShitPart2));
		rating.screenCenter();
		rating.x = coolText.x - 40;
		rating.y -= 60;
		rating.acceleration.y = 550;
		rating.velocity.y -= FlxG.random.int(140, 175);
		rating.velocity.x -= FlxG.random.int(0, 10);

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
		comboSpr.screenCenter();
		comboSpr.x = coolText.x;
		comboSpr.acceleration.y = 600;
		comboSpr.velocity.y -= 150;

		comboSpr.velocity.x += FlxG.random.int(1, 10);
		comboGroup.add(rating);

		if (!isPixel)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * PlayState.daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * PlayState.daPixelZoom * 0.85));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var seperatedScore:Array<Int> = [];

		if(combo >= 1000) {
			seperatedScore.push(Math.floor(combo / 1000) % 10);
		}
		seperatedScore.push(Math.floor(combo / 100) % 10);
		seperatedScore.push(Math.floor(combo / 10) % 10);
		seperatedScore.push(combo % 10);

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
			numScore.screenCenter();
			numScore.x = coolText.x + (43 * daLoop) - 90;
			numScore.y += 80;

			if (!isPixel)
			{
				numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			}
			else
			{
				numScore.setGraphicSize(Std.int(numScore.width * PlayState.daPixelZoom));
			}
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300);
			numScore.velocity.y -= FlxG.random.int(140, 160);
			numScore.velocity.x = FlxG.random.float(-5, 5);

			if (combo >= 10 || combo == 0)
				insert(members.indexOf(strumLineNotes), numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002
			});

			daLoop++;
		}
		/* 
			trace(combo);
			trace(seperatedScore);
			*/

		coolText.text = Std.string(seperatedScore);
		// comboGroup.add(coolText);

		FlxTween.tween(rating, {alpha: 0}, 0.2, {
			startDelay: Conductor.crochet * 0.001
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2, {
			onComplete: function(tween:FlxTween)
			{
				coolText.destroy();
				comboSpr.destroy();

				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.001
		});
	}

	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
		//	if (player < 1 && ClientPrefs.middleScroll) targetAlpha = 0.35;

			var babyArrow:StrumNote = new StrumNote(42, strumLine.y, i, player, PlayState.SONG.noteStyle);
			babyArrow.alpha = targetAlpha;

			if (babyArrow.pixelNotes.contains(babyArrow.daStyle))
				isPixel = false;

			if (player == 1)
			{
				playerStrums.add(babyArrow);
			}
			else
			{
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}


	// For Opponent's notes glow
	function StrumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = strumLineNotes.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}


	// Note splash shit, duh
	function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var skin:String = '';
		/*if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) skin = PlayState.SONG.splashSkin;
		
		var hue:Float = ClientPrefs.arrowHSV[data % 4][0] / 360;
		var sat:Float = ClientPrefs.arrowHSV[data % 4][1] / 100;
		var brt:Float = ClientPrefs.arrowHSV[data % 4][2] / 100;
		if(note != null) {
			skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}*/

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin);
		grpNoteSplashes.add(splash);
	}
	
	override function destroy() {
		FlxG.sound.music.stop();
		vocals.stop();
		vocals.destroy();

		/*if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}*/
		super.destroy();
	}
}
