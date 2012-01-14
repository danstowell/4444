////////////////
////4444////////
////////4444////
////////////////

by Dan Stowell, (c) 2011--2012, all rights reserved.
Released under the Affero GPL (AGPL) license, version 3 or later.

4444 is a thing for generative dance music using a 4-bar arrangement of pulls 
and drops. It provides a simple framework for making generative dance music, 
and presumably other sorts of music, anything that you can code in 
supercollider and comes in 4-bar patterns of 4.

You just need to define some Patterns (or more interestingly, some Functions 
that return Patterns), and probably some SynthDefs of your own.

The system has its own notion of its current mood ('arousal' and 'valence') 
which the Functions can use to generate happy/sad/chill/angry patterns 
accordingly.

The included 'example' files are simple generative examples that might help 
you get started.



The general approach: 

Each channel (bass, snare, hats, whatever) is a data structure stored in a 
Dictionary, having:
 * a current Pattern that can be triggered by the master sequencer, 
           to play a bar
 * a group, on which the pattern will play, and might have filters added
 * a 'regen' function, which can create and return a new pattern
 * a 'rare'  function, which is called on very first start, and only rarely 
           after that (e.g. to change a synthdef every 5 mins or so)
           (the 'rare' function can return an Event containing things that'll 
           be stored in \vars, which will later passed to the regen function)

Then there's a master sequencer which triggers four bars, then on last bar randomly chooses to kill/filter/regenerate the channels.


