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
declare name      "lowShelfComp";
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
maxHoldTime = 1*44100; //sec

MAX_flt = fconstant(int LDBL_MAX, <float.h>);
MIN_flt = fconstant(int LDBL_MIN, <float.h>);

main_group(x)  = (hgroup("[1]", x));
lowShelfGroup(x)  = main_group(vgroup("[1]", x));
highShelfGroup(x)  = main_group(vgroup("[2]", x));

drywet        = hslider("[0]dry-wet[tooltip: ]", 1.0, 0.0, 1.0, 0.1);
ingain        = hslider("[1] Input Gain [unit:dB]   [tooltip: The input signal level is increased by this amount (in dB) to make up for the level lost due to compression]",0, -40, 40, 0.1) : db2linear : smooth(0.999);
peakRMS       = hslider("[2] peak/RMS [tooltip: Peak or RMS level detection",1, 0, 1, 0.001);
rms_speed     = hslider("[3]RMS size[tooltip: ]",96, 1,   rmsMaxSize,   1)*44100/SR; //0.0005 * min(192000.0, max(22050.0, SR);
//threshold     = hslider("[4] Threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -27.1, -80, 0, 0.1);
ratio         = hslider("[5] Ratio   [tooltip: A compression Ratio of N means that for each N dB increase in input signal level above Threshold, the output level goes up 1 dB]", 20, 1, 20, 0.1);
attack        = time_ratio_attack(hslider("[6] Attack [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new lower target level (the compression `kicking in')]", 23.7, 0.1, 500, 0.1)/1000);
release       = time_ratio_release(hslider("[7] Release [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",0.1, 0.1, 2000, 0.1)/1000);

feedFwBw     = hslider("[8]feedback/feedforward[tooltip: ]", 0, 0, 1 , 0.001);
/*freq  = hslider("[9]low shelf freq[tooltip: ]",134, 1,   400,   1);*/



/*maxRateAttack  = hslider("[11]max attack[unit:dB/s][tooltip: ]", 1020, 6, 8000 , 1)/SR;*/
/*minRateDecay   = hslider("[12]min decay[unit:dB/s][tooltip: ]", 0, 0, 1000 , 1)/SR;*/
/*maxRateDecay   = hslider("[13]max decay[unit:dB/s][tooltip: ]", 1000, 1, 2000 , 1)/SR;*/
/*decayPower     = hslider("[14]decay power", 1, 1, 10 , 0.001);*/
/*holdTime       = hslider("[9]hold time[unit:seconds][tooltip: ]",0.3, 0,   1,  0.001)*maxHoldTime;*/

powerScale(x) =((x>=0)*(1/((x+1):pow(3))))+((x<0)* (((x*-1)+1):pow(3)));

//power          = hslider("[11]power[tooltip: ]", 1.881 , -33, 33 , 0.001):powerScale;
mult  = hslider("[11]mult[tooltip: ]",1, 1,   400,   1);


meter = _<:(_, ((hbargraph("[-1][unit:dB][tooltip: input level in dB]", -60, 0)))):attach;
holdMeter(group) = _<:(_, ((_/(group(holdTime):max(0.0001))):min(1):max(0):group(hbargraph("[-1]hold percentage", 0, 1)))):attach;
threshold     = (hslider("[0] low shelf threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -27.1, -80, 0, 0.1));
maxRateAttack  = (hslider("[1]max attack[unit:dB/s][tooltip: ]", 8000, 6, 8000 , 1)/SR);
holdTime       = (hslider("[2]hold time[unit:seconds][tooltip: ]",0.3, 0,   1,  0.001)*maxHoldTime);
minRateDecay   = (hslider("[3]min decay[unit:dB/s][tooltip: ]", 0, 0, 1000 , 1)/SR);
maxRateDecay   = (hslider("[4]max decay[unit:dB/s][tooltip: ]", 200, 1, 2000 , 1)/SR);
power          = (hslider("[5]power[tooltip: ]", 0 , -11, 11 , 0.001):powerScale);
freq  = (hslider("[6]low shelf freq[tooltip: ]",134, 1,   400,   1));

/*COMP = detector:maxGRshaper:(_-maxGR)*(1/(1-maxGR)): curve_pow(curve):tanshape(shape):_*(1-maxGR):_+maxGR:linear2db*/
/*<: _,( rateLimiter(maxRateAttack,maxRateDecay) ~ _ ):crossfade(ratelimit) : db2linear;//:( rateLimiter(maxRate) ~ _ );*/

/*process(x) = (_,x):lowShelfPlusMeter;*/

/*process(x,y) = lowShelfComp(x),lowShelfComp(y);*/
process(x,y) = feedBackLimLowShelf(x),feedBackLimLowShelf(y);

/*process = */
/*feedBackLimDetectHold;*/

/*lowShelfComp(x) =             (((crossfade(feedFwBw,x,_)) : detector):((_,x):lowShelfPlusMeter))~_;*/

detector = DETECTOR : rmsFade : RATIO : max(-60) : min(0);
/*detector = DETECTOR : rmsFade : RATIO : db2linear:min(1):max(MIN_flt)<:_,_:pow(powlim(power)) : linear2db;*/

/*rmsFade =_;*/
rmsFade = _<:crossfade(peakRMS,_,RMS(rms_speed)); // bypass makes the dsp double as efficient. On silence RMS takes double that (so in my case 7, 13 and 21 %)

crossfade(x,a,b) = a*(1-x),b*x : +;

/*lowShelfPlusMeter(gain,dry) = gain*dry;*/

lowShelfPlusMeter(freq,gain,dry) = (dry :low_shelf(gain:lowShelfGroup(meter),freq));

powlim(x,base) = x:max(log(MAX_flt)/log(base)):  min(log(MIN_flt)/log(base));

feedBackLimDetect(x) = 
(
  (
    ((
      ((level>threshold)*maxRateAttack*-1)
      +
      ((level<threshold)*maxRateDecay)
    )
    + _
    :max(-60):min(0))
  )~_
);

feedBackLimDetectHold(group,x) = (gain,hold)~((_,(_<:_,_))):(_,!)
with {
level =
(abs(x):linear2db);
gain(g,h) =
(
  (
      ((level>group(threshold))*group(maxRateAttack)*-1)
      +
      ((level<group(threshold))*crossfade(holdPercentage(h):pow(group(power)),group(minRateDecay),group(maxRateDecay)))
  )
    + g
    :max(-60):min(0)
);
holdPercentage(h) = (h/(group(holdTime):max(0.0001))):min(1):max(0);
hold = 
  select2((level>group(threshold)),(_+1),0): min(group(maxHoldTime)): holdMeter(group);
};


feedBackLim(x) = (feedBackLimDetect:meter:db2linear*x)~_;

feedBackLimLowShelf(x) = (feedBackLimDetectHold(lowShelfGroup):((_,x):lowShelfPlusMeter(lowShelfGroup(freq))))~_;

rateLimiter(maxRateAttack,maxRateDecay,prevx,x) = prevx+newtangent:min(0):max(maxGR)
with {
    tangent     = x- prevx;
    avgChange   = abs((tangent@1)-(tangent@2)):integrate(IM_size);
    newtangent  = select2(tangent>0,minus,plus):max(maxRateAttack*-1):min(maxRateDecay);
    plus        = tangent*((abs(avgChange)*-1):db2linear);
    minus       = tangent;//*((abs(avgChange)*0.5):db2linear);
       //select2(abs(tangent)>maxRate,tangent,maxRate);
	integrate(size,x) = delaysum(size, x)/size;
    
    delaysum(size) = _ <: par(i,rmsMaxSize, @(i)*(i<size)) :> _;
    };

