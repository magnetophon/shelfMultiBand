/*
 *  Copyright (C) 2015 Bart Brouns
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; version 2 of the License.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

Based on blushcomp mono by Sampo Savolainen
 */
declare name      "CharacterCompressor";
declare author    "Bart Brouns";
declare version   "0.2";
declare copyright "(C) 2015 Bart Brouns";

import ("math.lib");
import ("music.lib");
import ("filter.lib");

import ("./compressor-basics.dsp");

//the maximum size of the array for calculating the rms mean
//should be proportional to SR
// the size of a par() needs to be known at compile time, so (SR/100) doesn't work
rmsMaxSize = 441; //441

drywet        = hslider("[0]dry-wet[tooltip: ]", 1.0, 0.0, 1.0, 0.1);
ingain        = hslider("[1] Input Gain [unit:dB]   [tooltip: The input signal level is increased by this amount (in dB) to make up for the level lost due to compression]",0, -40, 40, 0.1) : db2linear : smooth(0.999);
peakRMS       = hslider("[2] peak/RMS [tooltip: Peak or RMS level detection",1, 0, 1, 0.001);
rms_speed     = hslider("[3]RMS size[tooltip: ]",96, 1,   rmsMaxSize,   1)*44100/SR; //0.0005 * min(192000.0, max(22050.0, SR);
threshold     = hslider("[4] Threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -27.1, -80, 0, 0.1);
ratio         = hslider("[5] Ratio   [tooltip: A compression Ratio of N means that for each N dB increase in input signal level above Threshold, the output level goes up 1 dB]", 20, 1, 20, 0.1);
attack        = time_ratio_attack(hslider("[6] Attack [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new lower target level (the compression `kicking in')]", 23.7, 0.1, 500, 0.1)/1000);
release       = time_ratio_release(hslider("[7] Release [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",0.1, 0.1, 2000, 0.1)/1000);

feedFwBw     = hslider("[8]feedback/feedforward[tooltip: ]", 0, 0, 1 , 0.001);
freq  = hslider("[9]low shelf freq[tooltip: ]",134, 1,   400,   1);

meter = _<:(_, ((hbargraph("[10][unit:dB][tooltip: input level in dB]", -60, 0)))):attach;

mult  = hslider("[11]mult[tooltip: ]",1, 1,   400,   1);
/*COMP = detector:maxGRshaper:(_-maxGR)*(1/(1-maxGR)): curve_pow(curve):tanshape(shape):_*(1-maxGR):_+maxGR:linear2db*/
/*<: _,( rateLimiter(maxRateAttack,maxRateDecay) ~ _ ):crossfade(ratelimit) : db2linear;//:( rateLimiter(maxRate) ~ _ );*/

/*process(x) = (_,x):lowShelfPlusMeter;*/

process(x,y) = lowShelfComp(x),lowShelfComp(y);

/*lowShelfPlusMeter(gain,dry) = gain*dry;*/
lowShelfPlusMeter(gain,dry) = (dry :low_shelf(gain:meter,freq));

/*lowShelfComp(x,y) = ( ((crossfade(feedFwBw,x,_)) : detector):(_,(x:low_shelf(freq))))~_;*/
/*lowShelfComp(x,y) = ( ((crossfade(feedFwBw,x,_)) : detector))~_;*/
/*lowShelfComp(x,y) = ( (x:low_shelf(((crossfade(feedFwBw,x,_)) : detector),freq)))~_;*/
/*lowShelfComp(x,y) =    x:low_shelf(((crossfade(feedFwBw,x,y)) : detector),freq);*/
lowShelfComp(x) =             (((crossfade(feedFwBw,x,_)) : detector):((_,x):lowShelfPlusMeter))~_;
/*lowShelfComp(x) =             (((crossfade(feedFwBw,x,_)) : detector))~_;*/
/*lowShelfComp(x) = (x:low_shelf(((crossfade(feedFwBw,x,_)) : detector),freq))~_;*/
/*lowShelfComp(x) = (x:low_shelf ((crossfade(feedFwBw,x,_) : detector),freq))~_;*/

detector = DETECTOR : rmsFade : RATIO * mult   : max(-60) : min(0);

/*rmsFade =_;*/
rmsFade = _<:crossfade(peakRMS,_,RMS(rms_speed)); // bypass makes the dsp double as efficient. On silence RMS takes double that (so in my case 7, 13 and 21 %)

crossfade(x,a,b) = a*(1-x),b*x : +;
