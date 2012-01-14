//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// a very simple 4444 example. just run each line/block in this document.

// what will happen, step-by-step:
//  * load main definitions from "4444.scd"
//  * start server
//  * run ~init4444.value to set up the server objects, scheduler and data structures
//  * add your own synth/pattern definitions to the ~a4444 struct (see below)
//  * run ~start4444.value to set it all going

// this simple example doesn't make use of the 'ebbs' to change the atmosphere/energy of the track.

Document.dir = "~/svn/stored_docs/scworkq/4444/".standardizePath; // or wherever you are
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
	Out.ar(out, (HPF.ar(WhiteNoise.ar(amp * 1.3), 15000) * Line.ar(1,0, 0.05, doneAction: 2)).dup);
}).add;
SynthDef(\snr44441, { |out=0, amp=1|
	Out.ar(out, (BPF.ar(WhiteNoise.ar(amp * 4), 500) * Line.ar(1,0, 0.1, doneAction: 2)).dup);
}).add;
SynthDef(\bss44441, { |out=0, amp=1, freq=110, gate=1|
	Out.ar(out, (SinOsc.ar(freq, mul: 4).tanh * amp * EnvGen.ar(Env.adsr(), gate, doneAction: 2)).dup);
}).add;

// define the lines' regen functions to return a 1-bar pattern
~a4444[\define].value(\kick, {}, { |curebbs|
	Pbind(
		\instrument, \kick44441,
		\freqa, rrand(300, 2000),
		\freqb, rrand(20, 120),
		\len, exprand(0.005, 0.04),
		\dur, Pshuf([0.25, 0.25, 0.5, 1, 1, 0.5, 0.5])
	)
});
~a4444[\define].value(\hat, {}, { |curebbs|
	Pbind(
		\instrument, \hat44441,
		\dur, Pshuf({0.125}.dup(16) ++ {0.25}.dup(8))
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
		\octave, 2,
		\degree, Pseq({20.rand}.dup(20))
	)
});
)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GO:
~start4444.value;

// ~stop4444.value;    // stops after next bar. restartable after this.
// ~dispose4444.value; // final disposal, going home.
