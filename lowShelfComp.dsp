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

import ("effect.lib");


maxHoldTime = 1*44100; //sec

mainGroup(x)  = (vgroup("[1]", x));
shelfGroup(x)  = mainGroup(hgroup("[0]", x));
limitGroup(x) = mainGroup(vgroup("[1] full range",x));
lowShelfGroup(x)  = shelfGroup(vgroup("[2]low shelf", x));
highShelfGroup(x)  = shelfGroup(vgroup("[3]high shelf", x));


meter = _<:(_, ((hbargraph("[-1]gain reduction[unit:dB][tooltip: input level in dB]", -40, 0)))):attach;
holdMeter(group) = _<:(_, ((_/(group(holdTime):max(0.0001))):min(1):max(0):group(hbargraph("[-1]hold percentage", 0, 1)))):attach;
threshold     = (hslider("[0]threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -11, -40, 0, 0.1));
maxRateAttack  = (hslider("[1]attack[unit:dB/s][tooltip: ]", 3000, 6, 8000 , 1)/SR);
minRateDecay   = (hslider("[2]min release[unit:dB/s][tooltip: ]", 0, 0, 1000 , 1)/SR);
holdTime       = (hslider("[3]hold time[unit:seconds][tooltip: ]",0.3, 0,   1,  0.001)*maxHoldTime);
maxRateDecay   = (hslider("[4]max release[unit:dB/s][tooltip: ]", 200, 1, 2000 , 1)/SR);
release        = (hslider("[1] Release [unit:seconds]   [tooltip: releasetime in seconds)]",0.001, 0.001, 2, 0.001));
freq  = (hslider("[6]shelf freq[tooltip: ]",115, 1,   400,   1));
xOverFreq  = (hslider("[7]sidechain x-over freq[tooltip: ]",115, 1,   400,   1));

process(x,y) = feedBackLimLowHighShelfFull(x),feedBackLimLowHighShelfFull(y);
crossfade(x,a,b) = a*(1-x),b*x : +;

lowShelfPlusMeter(freq,gain,dry) = (dry :low_shelf(gain:lowShelfGroup(meter),freq));
highShelfPlusMeter(freq,gain,dry) = (dry :high_shelf(gain:highShelfGroup(meter),freq));

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
      ((level<group(threshold))*crossfade(holdPercentage(h),group(minRateDecay),group(maxRateDecay)))
  )
    + g
    :max(-60):min(0)
);
holdPercentage(h) = (h/(group(holdTime):max(0.0001))):min(1):max(0);
hold = 
  select2((level>group(threshold)),(_+1),0): min(group(maxHoldTime)): holdMeter(group);
};


feedBackLim(x) = (feedBackLimDetect:meter:db2linear*x)~_;

feedBackLimLowShelf(x) = (feedBackLimDetectHold(lowShelfGroup):((_,x):lowShelfPlusMeter(lowShelfGroup(freq))))~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimHighShelf(x) = (feedBackLimDetectHold(highShelfGroup):((_,x):highShelfPlusMeter(highShelfGroup(freq))))~highpass(1,highShelfGroup(xOverFreq));
feedBackLimLowHighShelf(x) = (feedBackLimDetectHold(lowShelfGroup):((_,(x)):lowShelfPlusMeter(lowShelfGroup(freq))):feedBackLimHighShelf)~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimLowShelfFull(x) =
  (
    feedBackLimDetectHold(lowShelfGroup):((_,(x)):lowShelfPlusMeter(lowShelfGroup(freq)))
    :(
      ((feedBackLimDetectHold(highShelfGroup):highShelfGroup(meter):db2linear)*_)
      :(_<:((((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1):limitGroup(meter):db2linear)*_))
    )~highpass(1,highShelfGroup(xOverFreq))
  )
  ~lowpass(1,lowShelfGroup(xOverFreq));

feedBackLimLowHighShelfFull(x) =

  (
    (feedBackLimDetectHold(lowShelfGroup):((_,(x)):lowShelfPlusMeter(lowShelfGroup(freq))))
    :(
      (
        ((feedBackLimDetectHold(highShelfGroup),_):highShelfPlusMeter(highShelfGroup(freq)))
        :(_<:((((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1):limitGroup(meter):db2linear)*_))
      )
    )~highpass(1,highShelfGroup(xOverFreq))
  )
  ~lowpass(1,lowShelfGroup(xOverFreq));

