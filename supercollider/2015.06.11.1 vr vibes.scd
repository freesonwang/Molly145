//
// Vibraphone music
//

s.boot; // run and wait until you see "Shared memory server interface initialized"




// ### 1 ### INIT
(
n = NetAddr.new("127.0.0.1", 7771); // OSC target


// load bowed vibraphone samples
v = ();
v.path = PathName.new("".resolveRelative ++ "samples/vibraphone-bow");
v.load = {|me|
	me.samples = me.path.entries.collect({|file|
	var metadata = file.fileNameWithoutExtension.split($_);
	metadata = metadata.drop(1);
	(
		filename: file.fileName,
		path: file,
		buffer: Buffer.read(s, file.fullPath),
		midi: metadata[0].asInteger,
		amp: case  {metadata[1] == "p"} {0.4} {metadata[1] == "f"} {1}
	)
})
};
v.load;
v.match = {|me, midi = 60, amp = 0.5|
	var amps = me.samples.collect{|x| x.amp};
	var nearestAmp = amp.nearestInList(amps);
	var ampOptions = me.samples.select{|x| x.amp == nearestAmp};
	var notes = ampOptions.collect{|x| x.midi};
	var nearestNote = midi.nearestInList(notes.asArray);
	var noteOptions = ampOptions.select{|x| x.midi == nearestNote};
	if (noteOptions.class == Array, {noteOptions.choose}, {noteOptions});
};


// load pizz vibraphone samples

p = v.deepCopy;
p.path = PathName.new("".resolveRelative ++ "samples/vibraphone-pizz");
p.load;


// Sampler
b = p.samples.choose.buffer;
(
SynthDef(\bowedVibraphone, { arg out=0, in=0, freq=440, sampleFreq=440, pan=0, amp=1, buf=b, length=1;
	var sound, rate, report, duration, env;
	rate = freq/sampleFreq;
	//[freq,sampleFreq,buf].poll(1);
	sound = PlayBuf.ar(1, buf, rate);
	duration = (BufDur.kr(buf) / rate) * length;
	env = EnvGen.kr(Env.new([0,1,0.7,0], [0.01, 0.4, 0.59], curve:2), timeScale:duration, doneAction:2);
	sound = Splay.ar(sound, spread:0.1, level:amp, center: pan) * env;
	Out.ar(out, sound);

	// 1 messages gets sent out via OSC:

	// you will receive an array with this information:
	//   '/bowedVibraphone',
	//   nodeID -- a number that identifies this synth (each note will have a unique object)
	//   amp (volume 0 to 1),
	//   sound[0] (left channel raw audio -1 to 1),
	//   sound[1] (right channel raw audio -1 to 1)

	report = Array.with(Amplitude.kr(sound), freq, sound[0], sound[1]);
	SendReply.kr(Impulse.kr(30), '/bowedVibraphone', report);

}
).add;
);

(
SynthDef(\pizzVibraphone, { arg out=0, in=0, freq=440, sampleFreq=440, pan=0, amp=1, buf=b, length=1;
	var sound, rate, report, duration, env;
	rate = freq/sampleFreq;
	sound = PlayBuf.ar(1, buf, rate);
	duration = (BufDur.kr(buf) / rate) * length;
	env = EnvGen.kr(Env.new([0,1,0.7,0], [0.01, 0.4, 0.59], curve:2), timeScale:duration, doneAction:2);
	sound = Splay.ar(sound, spread:0.1, level:amp, center: pan) * env;
	Out.ar(out, sound);
	report = Array.with(Amplitude.kr(sound), freq, sound[0], sound[1]);

	// OSC: ditto

	SendReply.kr(Impulse.kr(30), '/pizzVibraphone', report);
}
).add;
);


// OSC relay
OSCresponder.all.do({|x| x.remove});
OSCresponder(nil, '/bowedVibraphone', {|time, resp, message, addr|
	("received % / % / % / %").format(time, message,addr);
	n.sendMsg("/bowedVibraphone", [time, message, addr]);
}).add;
OSCresponder(nil, '/pizzVibraphone', {|time, resp, message, addr|
	("received % / % / % / %").format(time, message,addr);
	n.sendMsg("/pizzVibraphone", [time, message, addr]);
}).add;


// Event prototypes for bow and pizz

~bvEvent = Event.default.parent.deepCopy.putAll(
	(
		\instrument: \bowedVibraphone,
		\getSample: {~sample = v.match(
			~midinote.value.asArray[0], ~amp)},
		// if it gets an array of notes, just use one sample for all of them -- improve this later (~midinote.collect{|x| v.match(x, ~amp)}
		\sampleFreq: {~getSample.value; ~sample.midi.midicps},
		\buf: {~sample.value.buffer.bufnum}
	)
);

~pvEvent = Event.default.parent.deepCopy.putAll(
	(
		\instrument: \pizzVibraphone,
		\getSample: {~sample = p.samples[0]},
		\sampleFreq: {~getSample.value; ~sample.midi.midicps},
		\buf: {~sample.value.buffer.bufnum}
	)
);
)




///// ### 2 ### RUN

(
(
~form = [60, 100, 60];
~subform = 15;

TempoClock.default.tempo_(rrand(1, 1.3));
TempoClock.default.tempo;

///

Pdefn(\k, Scale.dorian);
// Pdefn(\k, Scale.choose.postln);

(
Pdef(\blooms, Pbind(
	\scale, Pdefn(\k),
	\degree, Pwhite(-4, 15),
	\dur, Pser([Pn(0.1, {rrand(3,9)}), Pwhite(4,12,1)], inf),
	\pan, Pgauss(0, 0.5),
	\amp, 0.6,
	\length, 0.85
))
);

// Pdef(\blooms).play(protoEvent: ~bvEvent)
// Pdef(\blooms).stop


(
Pdef(\wash, Pbind(
	\scale, Pdefn(\k),
	\degree, Pxrand([0,2,4,6,8,10,11,12], inf),
	\mtranspose, Pstep(Pseq([0,-3,4,1], inf), 14, inf),
	\dur, Pser([Pn(0.1, {rrand(3,9)}), 1], inf),
	\pan, Pgauss(0, 1),
	\amp, Pwhite(0.2, 0.4),
	\length, Pwhite(0.1,0.3)
))
);

// Pdef(\wash).play(protoEvent: ~bvEvent)
// Pdef(\wash).stop


(
Pdef(\subbass, Pbind(
	\scale, Pdefn(\k),
	\dur, Pstutter(2, Pseq({rrand(4,10)}!2, inf)),
	\degree, Pseq({6.rand}!2,inf),
	\octave, 3,
	\pan, Pgauss(0, 0.5),
	\amp, 1,
	\length, 1
))
);

// Pdef(\subbass).play(protoEvent: ~bvEvent)
// Pdef(\subbass).stop

(
Pdef(\line, Pbind(
	\scale, Pdefn(\k),
	\dur, Pser([Pn(2, {rrand(3,9)}), Pwhite(4,12,1)], inf),
	\degree, Pseq({6.rand}!3,inf),
	\mtranspose, Pstutter(20, Pwhite(0, 6)),
	\pan, Pgauss(0, 0.5),
	\octave, 5,
	\amp, 0.4,
	\length, 1
))
);

// Pdef(\line).play(protoEvent: ~bvEvent)
// Pdef(\subbass).stop


(
Pdef(\chords, Pbind(
	\scale, Pdefn(\k),
	\mtranspose, Pstutter(3, Pwhite(-3, 6)),
	\degree, Pseq([0,4,9], inf),
	\dur, Pseq([0.1, 0.1, Prand([4,8,12],1)],inf),
	\amp, 0.4,
	\length, 1
))
);

// Pdef(\chords).play(protoEvent: ~bvEvent)
// Pdef(\chords).stop


(
~osti = (
	new: {|me, rate=1| Pbind(
		\scale, Pdefn(\k),
		\degree, me.degree.choose,
		\mtranspose,  me.mtranspose.choose,
		\octave, 5,
		\dur, me.dur.choose * rate,
		\amp, 1,
		\length, 1,
		\pan, Pbrown(-1,1)
	)},
	degree:
	[
		/*Prout({
			var set = {8.rand} ! 4;
			loop {
				set.do{|x| x.yield};
				set.postln;
				if (set.size < 5, {
					set = [set ++ 15.rand].choose;
					},
					{
						set = [set.drop(1)].choose;
					}
				)
			}
		}),*/
		Pseq({10.rand}!4,8),
		Pseq({10.rand}!3,4),
		Pn(Pshuf({15.rand}!6,4)),
		Pn(Pshuf({10.rand}!5,4)),
		Pn(Pshuf({15.rand}!4,4)),
		Pn(Pshuf({10.rand}!12,4)),
		Pn(Pshuf({6.rand}!10,4)),
		Pseq({10.rand}!5,2),
		Pseq({10.rand}!2,4),
		Pseq({10.rand}!7,4),
		Pseq({4.rand}!6,4),
		Pseq(({10.rand}!4).sort,4),
		Pseq(({12.rand}!4).sort,4),
	],
	mtranspose:
	[
		0,
		2,
		Pstutter(20, Pseq([0, 1, 2, -2],inf)),
			Pstutter(10, Pseq([0, 3],inf)),
	],
	dur:
	[
		1/5,
		1/5,
		2/5,
		2/5,
		Pseq([1/5,1/5,1/5,1/5,1/5,1/5,2],inf),
		Pseq([1/5,1/5,4/5],inf),
		//Pconst(1, Pwhite(0.1, 0.4),inf),
	],
	amp: [
		0.8,
		0.8,
	]

)
);




);



(

~bows = (
	intro: [
		[0, Pdef(\chords)],
		[0, Pdef(\blooms)],
		[0, Pdef(\chords), ~subform, Pdef(\blooms)],
		[0, Pdef(\blooms), ~subform * 2, Pdef(\subbass)],
		[0, Pdef(\subbass), ~subform * 2, Pdef(\blooms)],
		[0, Pdef(\subbass), ~subform * 2, Pdef(\chords)]
	].choose,
	middle: [
		[~subform * 1, Pdef(\line)],
		[~subform * 1, Pdef(\subbass), ~subform, 2, Pdef(\line)],
		[~subform * 2, Pdef(\line), ~subform * 3, Pdef(\wash)],
		[~subform * 2, Pdef(\line), ~subform * 3, Pdef(\subbass)],
		[~subform * 2, Pdef(\wash), ~subform * 4, Pdef(\subbass)],
		[~subform * 3, Pdef(\wash)],
		[~subform * 3, Pdef(\blooms)],
		[~subform * 3, Pdef(\chords)],
		[~subform * 3, Pdef(\subbass)],
		[~subform * 2, Pdef(\wash), ~subform * 4, Pdef(\chords)],
		[~subform * 2, Pdef(\subbass), ~subform * 4, Pdef(\chords)],
		[~subform * 2, Pdef(\subbass), ~subform * 4, Pdef(\blooms)],
	].choose,
	outro: [
		[0, Pdef(\wash)],
		[0, Pdef(\chords)],
		[0, Pdef(\wash), ~subform * 2, Pdef(\chords)],
	].choose
);



{
var slow = {~osti.new(4)} ! 3, medium = {~osti.new(2)} ! 4,  fast = {~osti.new(1)} ! 8;

~pizz = (
	intro: [
		[0, Pbind(\dur, 10, \midinote, \rest)],
		[~subform * 3, Pn(slow.choose)],
		[~subform * 3, Pseq({slow.choose} ! 2, inf)],
		[~subform * 2, Ppar({slow.choose} ! 2, inf)],
		[~subform * 2, Ppar({slow.choose} ! 4, inf)],
		[~subform * 1, Pn(slow.choose, 4)]
	].choose,
	middle: [
		[0, Pseq({medium.choose} ! 2, inf), ~subform * 1, Ppar({fast.choose} ! 3, 20), ~subform * 2, Ppar({fast.choose} ! 2, inf)],
		[0, Pseq({medium.choose} ! 4, inf), ~subform * 1, Ppar({fast.choose} ! 3, 20), ~subform * 2, Ppar({fast.choose} ! 2, inf)],
		[0, Pseq({fast.choose} ! 4, inf), ~subform * 1, Ppar({fast.choose} ! 4, inf)],
		[0, Pn(medium.choose, inf), ~subform * 2, Ppar({fast.choose} ! 2, inf), ~subform * 4, slow.choose],
		[0, Pn(fast.choose, 16), ~subform * 2, Ppar({fast.choose} ! 2, 8), ~subform * 4, slow.choose],
	].choose,
	outro: [
		[~subform * 1, Pn(slow.choose, 2)],
		[~subform * 1, Pn(slow.choose, 2)]
	].choose
)
}.value

);

(
Pseq([
	Pfindur(~form[0], Ptpar(~bows.intro)),
	Pfindur(~form[1], Ptpar(~bows.middle)),
	Pfindur(~form[2], Ptpar(~bows.outro))
], 1).play(protoEvent: ~bvEvent);

Pseq([
	Pfindur(~form[0], Ptpar(~pizz.intro)),
	Pfindur(~form[1], Ptpar(~pizz.middle)),
	Pfindur(~form[2], Ptpar(~pizz.outro))
], 1).play(protoEvent: ~pvEvent)
);

~scales = [Scale.dorian, Scale.ionian, Scale.harmonicMinor, Scale.mixolydian, Scale.phrygian, Scale.lydian];

Task.new({
	loop{
		10.wait;
		if (0.2.coin, {Pdefn(\k, ~scales.choose.postln)});
	}
}).play;


)








)


s.makeWindow


