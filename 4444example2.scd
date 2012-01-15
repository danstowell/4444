
// Like example1, but with some use of the ebbs (arousal, valence, density) to control the mood of the track.

// on mac you don't need this line; on linux I need to explicitly say what folder we're in
Document.dir = "~/svn/stored_docs/scworkq/4444/".standardizePath;
// Now RUN THESE lines to prepare:
(Document.dir +/+ "4444.scd").load;
s.boot;
~init4444.value();

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// run these local declarations, which define synths, pattern generators, etc, for this particular music type.
(
SynthDef(\kick44441, { |out=0, amp=1, freqa=1000, freqb=100, len=0.01|
	Out.ar(out, (SinOsc.ar(XLine.ar(freqa, freqb, len)) * 0.5 * Line.ar(1,0, len, doneAction: 2)).dup);
}).add;
SynthDef(\hat44441, { |out=0, amp=1|
	Out.ar(out, (HPF.ar(WhiteNoise.ar(amp * 1.8), 15000) * Line.ar(1,0, 0.05, doneAction: 2)).dup);
}).add;
SynthDef(\hat44441open, { |out=0, amp=1, dur=1|
	Out.ar(out, (HPF.ar(WhiteNoise.ar(amp * 1.8), 15000) * EnvGen.ar(Env([0,1,1,0], [0.001, (dur*0.75)-0.101, 0.1]), doneAction: 2)).dup );
}).add;
SynthDef(\snr44441, { |out=0, amp=1|
	Out.ar(out, (BPF.ar(WhiteNoise.ar(amp * 4), 500) * Line.ar(1,0, 0.1, doneAction: 2)).dup);
}).add;
SynthDef(\bss44441, { |out=0, amp=1, freq=110, gate=1|
	Out.ar(out, (SinOsc.ar(freq, mul: 4).tanh * amp * EnvGen.ar(Env.adsr(), gate, doneAction: 2)).dup);
}).add;
SynthDef(\chorus44441, { |out=0, amp=1, freq=440, gate=1|
	Out.ar(out, (Pulse.ar(10.collect{freq * rrand(0.99, 1.01) * BrownNoise.kr.range(0.999, 1.001)}).mean
			 * amp * 2 * EnvGen.ar(Env.adsr(), gate, doneAction: 2)).dup);
}).add;

// define the lines' regen functions to return a 1-bar pattern
~a4444[\define].value(\kick, {}, { |curebbs|
	var tmp;
	Pbind(
		\instrument, \kick44441,
		// trebley onset of kick controlled by arousal ebb
		\freqa, rrand(300, curebbs[\arousal].linexp(0, 1, 350, 2500)),
		\freqb, rrand(20, 120),
		\len, exprand(0.005, 0.04),
		\dur, if(curebbs[\density] < 0.3){
			tmp = 26.rand;
			Pseq([0.75] ++ ([tmp, 26-tmp]/8)) // bit like a beatdown kick pattern
		}{
			Pshuf([0.25, 0.25, 0.5, 1, 1, 0.5, 0.5])
		}
	)
});
~a4444[\define].value(\hat, {}, { |curebbs|
	var dlevel = (curebbs[\density] * 4).floor.asInt;
	// density of hihat pattern controlled by density ebb
	var durs = dlevel.switch(
				0, {{0.5    }.dup( 4) ++ {1    }.dup( 2)},
				1, {{0.25   }.dup( 8) ++ {0.5  }.dup( 4)},
				2, {{0.125  }.dup(16) ++ {0.25 }.dup( 8)},
				3, {{0.125  }.dup(30) ++ {0.25 }.dup( 1)}
			);
	// also whether open ones are thrown in:
	var hatweights = if(dlevel==0){[1.0.rand, 1.0.rand].normalizeSum}{[0.995, 0.005]};
	Pbind(
		\instrument, Pseq(durs.collect{[\hat44441, \hat44441open].wchoose(hatweights)}),
		\legato, 0.5,
		\dur, Pseq(durs)
	)
});
~a4444[\define].value(\snare, {}, { |curebbs|
	Pbind(
		\instrument, \snr44441,
		\dur, 1,
		\midinote, Pseq([\, 60, \, 60])
	)
});
~a4444[\define].value(\bass, {}, { |curebbs|
	Pbind(
		\instrument, \bss44441,
		\dur, Pseq({[1,2,4,8].choose}.dup(10).normalizeSum * 4),
		\midinote, Pseq({(0..23).wchoose(~a4444[\key] ++ ~a4444[\key])}.dup(20)) + 30
	)
});
~a4444[\define].value(\lead, {}, { |curebbs|
	var letsalt = (1.0 - curebbs[\arousal]).squared.postln.coin.postln; // only likely if arousal is looow
	var bardur = if(letsalt){1}{[1,2].choose};
	~a4444[\d][\lead][\everynbars] = if(letsalt){2}{1} * bardur;
	Pbind(
		\instrument, [\bss44441, \default, \chorus44441].choose,
		\dur, Pseq({[1,2,4,8].choose}.dup(rrand(3, 10) + (curebbs[\density]*5).asInt).normalizeSum * 4 * bardur),
		\amp, 0.05,
		\midinote, Pseq({(0..23).wchoose(~a4444[\key] ++ ~a4444[\key])}.dup(20))
				 + 54 + (12 * (2.rand + (curebbs[\arousal] * 3).asInt))
	)
});
)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GO:
~start4444.value;

// ~stop4444.value;    // restartable after this.
// ~dispose4444.value; // final disposal, going home.
