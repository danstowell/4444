////////////////
////4444////////
////////4444////
////////////////

// by Dan Stowell, (c) 2011-2012, all rights reserved.
// Released under the Affero GPL (AGPL) license, version 3 or later.

// 4444 is a thing for generative dance music using a 4-bar arrangement of pulls and drops.
// General approach: each channel (bass, snare, hats, whatever) is a data structure stored in a Dictionary, having:
//  * a current Pattern that can be triggered by the master sequencer, to play a bar
//  * a group, on which the pattern will play, and might have filters added
//  * a 'regen' function, which can create and return a new pattern
//  * a 'rare'  function, which is called on very first start, and only rarely after that (e.g. to change a synthdef every 5 mins or so)
//          (the 'rare' function can return an Event containing things that'll be stored in \vars, which will later passed to the regen function)
// Then there's a master sequencer which triggers four bars, then on last bar randomly chooses to kill/filter/regenerate the channels.

// This file defines the main gubbins. For more of an overview see the how-to.

//////////////////////////////////////////////////////////////////////////////////////////
// INIT FUNCTION. DEFAULT SERVER MUST ALREADY BE BOOTED.
~init4444 = {

~a4444 = (); // data will be stored in here. Importantly, the ~a4444[\d] will be the dict of the different channels.

~a4444[\pattgroup] = Group.new(Server.default); // main group for patterns to play on
~a4444[\outmixgroup] = Group.after(~a4444[\pattgroup]); // for synths that mix to output

// Synth for general emotional dimension "ebb" (used in continuous mix mode)
SynthDef(\ebber4444, { |out=0, evolvetime=0.1, userval=0, t_trig=0|
	var ebb = LFDNoise1.kr(evolvetime).range(0.0001, 0.999).clip(0.0001, 0.999);
	var useuser = EnvGen.kr(Env.perc(5, 60, 1, 'linear'), t_trig + Impulse.kr(0));
	ebb = LinXFade2.kr(ebb, userval, useuser * 2 - 1);
	Out.kr(out, ebb);
}).add;
~a4444[\ebbgroup] = Group.new(~a4444[\pattgroup], \addBefore);
~a4444[\ebbs] = (  // control busses for gradually-varying 'mood' values, between 0.0001 and 9.999.
	arousal: Bus.control(Server.default), // 0    calm <---> excited  1
	valence: Bus.control(Server.default), // 0     sad <---> happy    1
	density: Bus.control(Server.default)  // 0  sparse <---> dense    1
);
~a4444[\ebbprocessor] = {|ebbs| ebbs }; // a function which optionally pre-processes ebbs, e.g. to add other values in.
~a4444[\setebb] = {|ebbname, value| ~a4444[\ebbsynths][ebbname.asSymbol].set(\userval, value, \t_trig, 1)}; // for user control
~a4444[\ebbs_tm1] = nil; // will hold previous values
~a4444[\ebbs_tm2] = nil; // will hold previous previous values

// buildup detector/decider
// Reads the arousal and turns it into a decision about doing a build
SynthDef(\buildupper4444, {|arousalbus=0, buildbus=0, t_inhibitbuild=0|
	var arou = In.kr(arousalbus);
	var buildup = Decay.kr([(arou - 0.5) * 0.0001, HPZ1.kr(arou)], 5 * 60);
	var buildinhibit = EnvGen.kr(Env.perc(0, 3 * 60, 1, 'linear'), t_inhibitbuild);
	buildup = buildup.mean;
	buildup = LinXFade2.kr(buildup, 0, buildinhibit * 2 - 1);
	Out.kr(buildbus, buildup);
}).add;
~a4444[\buildgroup] = Group.new(~a4444[\ebbgroup], \addToTail);
~a4444[\buildbus] = Bus.control(Server.default);
~a4444[\buildbus].set(0);

// The different channels (hihat, bass, whatever) each have an entry in \d - but you invoke the \define func to set it (see example files).
~a4444[\d] = ();
~a4444[\define] = { |key, rarefunc, regenfunc, everynbars=1, makebuild=\old, duckunder=nil|
	var prev = ~a4444[\d][key] ?? {()};
	~a4444[\d][key] = (
		\group : prev[\group] ?? {Group.new(~a4444[\pattgroup])},
		\bus   : prev[\bus  ] ?? {Bus.audio(Server.default, 2)},
		\patt  : prev[\patt ] ?? {EventPatternProxy()},
		\everynbars: everynbars, // default to one, typically might alternatively use two or four.
		\currentbarcounter: 1, // a variable used along with \everynbars.
		\onprob: 1, // probability of getting scheduled in any given 4bar. can be a function.
		\maypull: true, // whether the scheduler is allowed to silence the channel in the leadup to a new 4bar.
		\rare  : rarefunc  ?? {},
		\regen : regenfunc ?? {},
		\makebuild : makebuild,
		\duckunder : duckunder  // if not nil, this should be the key saying which channel this channel should duck under in the output mixer/compression stage. (e.g. bassline duck under \kick.)
	);
	~a4444[\d][key][\vars] = ~a4444[\d][key][\rare].value(~a4444[\ebbs_now]);
//rm	~a4444[\d][key][\outmix] = prev[\outmix] ?? {
//rm		Synth(\outmix4444, [\in, ~a4444[\d][key][\bus], \out, 0, \amp, ~a4444[\outmixamp]], ~a4444[\outmixgroup])
//rm	};
};

// Possible for (external?) processes to pull the percussion by zeroing this bus
~a4444[\percussionon] = Bus.control(Server.default);
{
	~a4444[\percussionon].set(1);
}.defer(0.3);


// Filters -- use \dur key to make sure they free, they don't always free otherwise.
SynthDef(\lpf4444, { |out=0, gate=1, dur=1|
	ReplaceOut.ar(out, LPF.ar(In.ar(out, 2), 100)); FreeSelf.kr(1-gate);
	Line.kr(1,1,dur,doneAction:2);
}).add;
SynthDef(\decim4444, { |out=0, gate=1, dur=1|
	ReplaceOut.ar(out, In.ar(out, 2).round(0.1) * 0.75); FreeSelf.kr(1-gate);
	Line.kr(1,1,dur,doneAction:2);
}).add;
SynthDef(\eko4444, { |out=0, gate=1, dur=1|
	var len = Rand(0.01, 0.1);
	var son = In.ar(out, 2);
	ReplaceOut.ar(out, CombC.ar(son, len, len, 2.0));
	FreeSelf.kr(1-gate);
	Line.kr(1,1,dur,doneAction:2);
}).add;
~a4444[\filters]  = [\lpf4444, \decim4444, \eko4444];

////////////////////////////////////////////////////////////////////////////////////
///// special probability fun: dirichlet-like sampling functions (stuck with alpha=1 for now)
// this returns a sample from a dirichlet-like using stick-breaking construction but fixed N and fixed alpha
~a4444[\stickbreakraw] = { |numitems|
	var p = {0}.dup(numitems);
	numitems.do{|i|
		p[i] = (1.0 - p.sum) * 1.0.rand; // uniform distrib here is what forces alpha as 1 (no beta distrib)
	};
	p.normalizeSum
};
// modified version where proby of first item is injected (we want to use ebb to choose it) and rest are shuffled.
// "rawsb" allows to inject an old result from ~a4444[\stickbreakraw].value(numitems-1).scramble
~a4444[\stickbreak1plus] = { |numitems, pfirst=0.95, pdropfirst=0.01, rawsb|
	var first = if(pdropfirst.coin){0.1}{pfirst};
	if(rawsb.isNil){rawsb = ~a4444[\stickbreakraw].value(numitems-1).scramble};
	[first] ++ (rawsb * (1.0-first))
};

////////////////////////////////////////////////////////////////////////////////////
// Definition of master scheduler:
~a4444[\launchonebar] = {
	".".post;
	~a4444[\d].do{|item|
		item[\currentbarcounter] = item[\currentbarcounter] - 1;
		if(item[\currentbarcounter] < 1){
			item[\currentbarcounter] = item[\everynbars].value;
			item[\nowplaying] = (Pbind(\group, item[\group], \out, item[\bus].index) <> item.patt).play(quant: 2)
		}
	}
};
~a4444[\launchbuild] = { | numbars=1, gapbeats=0 |
	var madebuild;
	// the build is not a normal onebar; it's a longer sequence of bars (8 bars, for now) building up to a drop or sth.
	// each item is asked to generate N bars - it can use "item[\patt]" (which is what's coming next) or gen something new.
	"".postln;
	"b".postln;
	//Pbind(\dur, 1, \midinote, Pseq([60, 61, 62, 63])).play(quant: 2);
	~a4444[\d].do{|item|
		madebuild = item[\makebuild].value(item, numbars, gapbeats, ~a4444[\ebbs_now]);
		
		// convenience: return a number as a simple way to say "this is the proby of the channel carrying on (rather than silencing)"
		if(madebuild.isNumber){
			madebuild = if(madebuild.coin){ \old }{ nil };
		};
		
		// handle special convenience signals to reuse things:
		madebuild.switch(
			\old, {
				madebuild = Pfindur(numbars * 4 - gapbeats, Pseq([item[\patt_latestplayed]], numbars))
			}, 
			\new, {
				madebuild = Pfindur(numbars * 4 - gapbeats, Pseq([item[\patt             ]], numbars))
			});
		item[\nowplaying] = (Pbind(\group, item[\group], \out, item[\bus].index) <> madebuild).play(quant: 2)
	}
};
~a4444[\generatekey] = {
	~a4444[\key] = Array.newClear(12);
	~hiprob = 0.15;
	~loprob = 0.05;
	~wibble  = 0.05;
	~ishigh = 0.5.coin;
	12.do{|i|
		if(0.81.coin){~ishigh = ~ishigh.not}; // 0.81 approx what you get in a standard western scale
		~a4444[\key][i] = (if(~ishigh){~hiprob}{~loprob} + ~wibble.sum3rand).max(0.01);
	};
	~a4444[\key] = ~a4444[\key].normalizeSum;
	~a4444[\key] //.plot(minval: 0, discrete: true);
};
~a4444[\handleregen] = { |item|
	item[\patt] = if(item[\onprob].value(~a4444[\ebbs_now]).coin){
		item[\regen].value(~a4444[\ebbs_now], item[\vars])
	}{
		Pbind(\freq, \, \dur, Pseq([1], 1))
	};

};
~a4444[\mainscheduler] = Prout{var filt, curebbs, dobuild, tmpnow, tmptm1, tmptm2,   numbars,gapbeats, changetendency;
	while{~a4444[\trackdur].isNil or: { 
			~a4444[\trackdur] = ~a4444[\trackdur] - 1; 
			~a4444[\trackdur] > 0}
		}{

	"".postln;
	~a4444[\launchonebar].value;
	4.yield;
	~a4444[\launchonebar].value;
	4.yield;
	~a4444[\launchonebar].value;
	4.yield;
	~a4444[\launchonebar].value;
	
	// grab ebbs, remembering some old ones too
	~a4444[\ebbs_tm2] = ~a4444[\ebbs_tm1];
	~a4444[\ebbs_tm1] = ~a4444[\ebbs_now];
	~a4444[\ebbs_now] = ();
	~a4444[\ebbs].keysValuesDo{|ebbname, ebbbus|
		ebbbus.get{|value| ~a4444[\ebbs_now][ebbname] = value.round(0.0001) };
	};
	// add build monitor as a "special case" ebb
	~a4444[\buildbus].get{|value| ~a4444[\ebbs_now][\build] = value.round(0.0001) };
	
	block{|break|
		30.do{
			0.05.wait;
			if(~a4444[\ebbs_now].size == (~a4444[\ebbs].size + 1) /* plus one cos of build */){
				break.value;
			}
		};
		"\n~a4444[\\mainscheduler] continuing WITHOUT having heard back from all the ebbs".warn;
		// copy+paste nonexistent ebbs from yester
		~a4444[\ebbs_tm1].keysValuesDo{|k, v|
			if(~a4444[\ebbs_now][k].isNil){ ~a4444[\ebbs_now][k] = v };
		};
	};
	~a4444[\ebbs_now] = ~a4444[\ebbprocessor].value(~a4444[\ebbs_now]);
	"".postln;
	~a4444[\ebbs_now].postln;

	// decide a general tendency to regen, and also decide whether to do a build
	changetendency = 1.0.rand;
	dobuild = (~a4444[\ebbs_now][\build] > 0.2) and: {~a4444[\ebbs_now][\arousal] > 0.6} and: {changetendency > 0.75};

	// Find out if we're "not too far" from prev position in ebbspace and therefore may recall old patterns
	~a4444[\ebbs_dorecall] = (~a4444[\ebbs_tm2].notNil) and:
			{
				tmpnow = ~a4444[\ebbs_now].reject{|elem, key| key==\build }.asSortedArray.collect(_[1]);
				tmptm1 = ~a4444[\ebbs_tm1].reject{|elem, key| key==\build }.asSortedArray.collect(_[1]);
				tmptm2 = ~a4444[\ebbs_tm2].reject{|elem, key| key==\build }.asSortedArray.collect(_[1]);
				(((tmpnow-tmptm2).abs.sum / (tmptm1-tmptm2).abs.sum) < if(~a4444[\trackdur].isNil){1.2}{1.5})
			};
	
	
	// generate a key. More generic than major/minor, probabilistically done - we get a prob distribution over 12 notes.
	if(~a4444[\key].isNil or: {changetendency.squared.squared.squared.coin}){
		"*** KEYCHANGE".postln;
		~a4444[\generatekey].value;
	};
	
	// decide a beat offset for any killing/filtering that might happen
	~a4444[\koffset] = 8.rand / 2;
	~a4444[\d].keysValuesDo{|key, item|
		// decide whether to kill/filter
		if(item[\maypull] and: {1.0.rand > changetendency}){
			if(dobuild.not and: {1.0.rand > 0.5}){
				"%.pull();  ".format(key).post;
				item[\nowplaying].stop; // todo: align with ~a4444[\koffset]
			}{
				filt = ~a4444[\filters].choose;
				"%.filt(%);  ".format(key, filt).post;
				Pbind(
					\dur, Pseq([~a4444[\koffset], 4 - ~a4444[\koffset]]), 
					\instrument, filt,
					\out, item[\bus],
					\group, item[\group],
					\addAction, \addToTail,
					\midinote, [\, 60] // hackish, meaning nothing-then-something
				).play(quant: 2);
			}
		};
		item[\patt_latestplayed] = item[\patt]; // irrespective of whether we're changing, this is what-was-played-in-prev-4bar
		// decide whether to regen
		if(1.0.rand > changetendency){
			// in track-mode, we do the rare stuff only at the start
			if(~a4444[\trackdur].isNil and: {1.0.rand.squared.squared > changetendency}){
				"%.rare(***);  ".format(key).post;
				item[\vars] = item[\rare].value(~a4444[\ebbs_now]);
			};
			item[\patt_tm2] = item[\patt_tm1];
			item[\patt_tm1] = item[\patt];
			// At this point we normally already have item[\patt], and we want to know if we're going to swap it with item[\patt_tm1] or gen new
			if(item[\patt_tm2].notNil and: {dobuild.not} and: {~a4444[\ebbs_dorecall]}){
				"%.recall(); ".format(key).post;
				item[\patt] = item[\patt_tm2];
			}{
				"%.regen(); ".format(key).post;
				~a4444[\handleregen].value(item);
			};
		};
	};
	4.yield;
	
	// Decide whether to inject a buildup into the proceedings.
	if(dobuild){
		numbars = 4; //[4, 8].choose;
		gapbeats = [0, 1, 2].choose; // how many beats of silence (e.g. with a sample in) before the drop
		//"****************************************".postln;
		~a4444[\launchbuild].value(numbars, gapbeats);
		(4 * numbars).yield;
	};
	
	}; // end inf.do
	4.yield;
	"trackmode ending - calling dispose".postln;
	~dispose4444.value;
}
}; // end ~init4444


//////////////////////////////////////////////////////////////////////////////////////////
// LAUNCH FUNCTION.
~start4444 = { |evolvetime=0.1, record=false, initebbs=((arousal: 0.1, valence: 0.5, density: 0.3)), amp=0.5, trackdur=nil|
	var numsegs, madesegs, stemoutpath, stembusses;
	if(trackdur.notNil){
		numsegs  = trackdur / 2; // TODO is this (combined with the length below) correct?
		madesegs = ~a4444[\ebbs].collect{{rrand(0.0, 1.0)}.dup(numsegs+1)};
		~a4444[\ebbs_now] = madesegs.collect(_[0]);
	}{
		~a4444[\ebbs_now] = initebbs;
	};

	"I have initialised ebbs_now to: %".format(~a4444[\ebbs_now]).postln;/////////////////////////////////////////////

	~a4444[\trackdur] = trackdur;
	~a4444[\outmixamp] = amp; // not working? using group-set below

	~a4444[\generatekey].value;
	// ensure each channel has prepared itself something to say
	~a4444[\d].keysValuesDo{|key, item|
		~a4444[\handleregen].value(item);
	};
	// start the ebbs ebbing
	~a4444[\ebbsynths] = ~a4444[\ebbs].collect{ |elem, key|
		if(trackdur.isNil){
			Synth(\ebber4444, [\out, elem, \evolvetime, evolvetime, \userval, initebbs[key] ?? {1.0.rand}], ~a4444[\ebbgroup]);
		}{
			// If there's a trackdur then let's generate envelopes to fit that dur
			{
				Out.kr(elem, EnvGen.kr(Env( madesegs[key],
								{32 / TempoClock.default.tempo}.dup(numsegs), rrand(-8.0, 8.0) ).postln))
			}.play(target: ~a4444[\ebbgroup])
		};
	};
	~a4444[\buildbus].set(0);
	~a4444[\buildsynth] = Synth(\buildupper4444, [\arousalbus, ~a4444[\ebbs][\arousal], \buildbus, ~a4444[\buildbus]], 
				~a4444[\buildgroup], \addToTail);

	if(record.isNumber.not){
		record = if(record){1}{0}; //asInt; "binaryValue" more backwards-compatible
	};
	if(record > 0){
		"Recording to folder '%'".format(thisProcess.platform.recordingsDir).postln;
		// recording the main output mix:
		Server.default.record(thisProcess.platform.recordingsDir +/+ 
				"4444_" ++ Date.localtime.stamp ++ "." ++ Server.default.recHeaderFormat);
	};
	if(record > 1){
		// recording the individual stems:
		stemoutpath = thisProcess.platform.recordingsDir +/+ 
				"4444_" ++ Date.localtime.stamp ++ "_stems." ++ Server.default.recHeaderFormat;
		stembusses = ~a4444[\d].collect{|chan| chan.bus}.asArray; // remember each one's bus is itself stereo

		~a4444[\stemrecbuf] = Buffer.alloc(Server.default, 65536, stembusses.size * 2);
		~a4444[\stemrecbuf].write(stemoutpath, Server.default.recHeaderFormat, Server.default.recSampleFormat, 0, 0, true);
		
		Task{
			0.2.wait;
			Server.default.sync;
			~a4444[\stemrecsynth] = {
				DiskOut.ar(~a4444[\stemrecbuf], stembusses.collect{|abus| In.ar(abus, 2) }.flat);
				Out.ar(0, DC.ar(0));//silent
			}.play(~a4444[\outmixgroup]);
		}.play;
	};

	// The thing that mixes the tracks together into a stereo result
	~a4444[\outmixproxy] = NodeProxy(Server.default, \audio, 2).play;
	~a4444[\outmixproxy].group = ~a4444[\outmixgroup];

	~setupmixer4444.value;

	~a4444[\outmixgroup].set(\amp, amp);
	~a4444[\mainschedulerplaying] = ~a4444[\mainscheduler].play;
	~a4444[\mainschedulerplaying] // return it
};

// Creates a synth which handles the mixdown (inc compression etc) of the tracks for output.
// It's a separate function because you'd need to invoke it if you add a new channel mid-flow,
//  and you want it to go to the main mix.
~setupmixer4444 = {
	~a4444[\outmixproxy].source = { |amp=1, bassamp=2, duckamount=1, pregain=5|
		var son, raws, amps, ducked, ampall;
		var lo, hi;
		/*
		// Deactivated - this simple summing mixer:
		son = chaninfo.collect{|info| In.ar(info[0], 2)}.asArray.sum;
		// with simple bass emphasis:
	 	son = son + LPF.ar(son, rrand(100, 150), bassamp - 1);
		*/
	
		// mixing with sidechain ducking compression.
		raws = ~a4444[\d].collect{|chan| In.ar(chan.bus, 2) };
		amps = ~a4444[\d].collect{|chan, key| Amplitude.ar(raws[key], 0.005, 0.04) };
		// foreach channel, if 'duckunder' is nil simply mix it in, otherwise suppress its amplitude using the named channel
		ducked = ~a4444[\d].collect{|chan, key|
			if(chan.duckunder.isNil){
				raws[key] // no duck
			}{
				"% ducks under %".format(key, chan[1]).postln;
				// simple assumption of summing amplitudes. any amplitude present in the sidechain is amplitude we must try to subtract
				raws[key] * ( /* target amp: */ max(0, amps[key] - (amps[chan.duckunder] * duckamount))
				                               / 
				            /*   self amp: */ max(0.0000001, amps[key]))
			}
		};
		// apply eq as needed, here a simple bass emphasis:
	 	ducked = ducked.collect{|chan| chan + LPF.ar(chan, rrand(100, 150), bassamp - 1)};
		// now sum, pregain, compress, gain.
		son = ducked.asArray.sum;
		son = son * pregain;

		// very simple crossover split before the distortion, so bass & snare can avoid smulging each other
		lo = LPF.ar(son);
		hi = son - lo;
		son = (lo.tanh + hi.tanh) * 0.5;

		son * amp   // and output it
	};
};

//////////////////////////////////////////////////////////////////////////////////////////
// Stop playing. (able to be restarted after this)
~stop4444 = {
	~a4444[\mainschedulerplaying].stop;
	~a4444[\ebbsynths].do(_.free);
	~a4444[\buildsynth].free;
	{
		~a4444[\outmixproxy].release(0.1);
		Server.default.stopRecording;
		if(~a4444[\stemrecsynth].notNil){
			~a4444[\stemrecsynth].free;
			~a4444[\stemrecbuf].close;
			~a4444[\stemrecbuf].free;
			~a4444[\stemrecsynth] = nil;
		};
	}.defer(5);
};

//////////////////////////////////////////////////////////////////////////////////////////
// Clean tidyup
~dispose4444 = {
	~stop4444.value;
	~a4444[\d].collect{|item| item[\nowplaying].stop};
	~a4444[\ebbgroup].free;
	~a4444[\pattgroup].free;
	~a4444[\outmixgroup].free;
	~a4444[\percussionon].free;
	~a4444[\buildbus].free;
	~a4444[\ebbs].do(_.free);
};

