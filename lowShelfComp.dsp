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
declare version   "0.3";
declare copyright "(C) 2015 Bart Brouns";

import ("effect.lib");

maxHoldTime = 1*44100; //sec

mainGroup(x)      = (vgroup("[1]", x));
shelfGroup(x)     = mainGroup(hgroup("[0]", x));
/*limitGroup(x)     = mainGroup(vgroup("[1] full range",x));*/
lowShelfGroup(x)  = shelfGroup(vgroup("[2]low shelf", x));
highShelfGroup(x) = shelfGroup(vgroup("[3]high shelf", x));
limitGroup(x)     = shelfGroup(vgroup("[4] full range",x));
//                =
meter             = _<:(_, ((hbargraph("[-1]gain reduction[unit:dB][tooltip: input level in dB]", -40, 0)))):attach;
holdMeter(group)  = _<:(_, ((_/(group(holdTime):max(0.0001))):min(1):max(0):group(hbargraph("[-1]hold percentage", 0, 1)))):attach;
threshold         = (hslider("[0]threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -11, -40, 0, 0.1));
maxRateAttack     = (hslider("[1]attack[unit:dB/s][tooltip: ]", 3000, 6, 8000 , 1)/SR);
minRateDecay      = (hslider("[2]min release[unit:dB/s][tooltip: ]", 0, 0, 1000 , 1)/SR);
holdTime          = (hslider("[3]hold time[unit:seconds][tooltip: ]",0.2, 0,   1,  0.001)*maxHoldTime);
maxRateDecay      = (hslider("[4]max release[unit:dB/s][tooltip: ]", 200, 1, 2000 , 1)/SR);
release           = (hslider("[1]release[unit:seconds]   [tooltip: release time in seconds)]",0.001, 0.001, 2, 0.001));
freq              = (hslider("[6]shelf freq[tooltip: ]",115, 1,   400,   1));
xOverFreq         = (hslider("[7]sidechain x-over freq[tooltip: ]",115, 1,   400,   1));
channelLink       = (hslider("[8]channel link[tooltip: ]",1, 0,   1,   0.001));

/*process = limLowHighShelfFull;*/
/*process = stereoLim;*/
process = stereoFeedBackLimLowHighShelfFull;
/*process = feedBackLimLowHighShelfFull,feedBackLimLowHighShelfFull;*/
/*process = feedBackLimLowShelfFull,feedBackLimLowShelfFull;*/
/*process = feedBackLimLowHighShelf, feedBackLimLowHighShelf;*/

feedBackLimLowShelf = lowShelfLim~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimHighShelf = highShelfLim~highpass(1,highShelfGroup(xOverFreq));
feedBackLimLowHighShelf = (lowShelfLim:feedBackLimHighShelf)~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimLowShelfFull =
  ( lowShelfLim:fullRangeLim
  )
  ~lowpass(1,lowShelfGroup(xOverFreq));

feedBackLimLowHighShelfFull =(((_<:(highpass(1,highShelfGroup(xOverFreq)),lowpass(1,lowShelfGroup(xOverFreq)))),_): limLowHighShelfFull)~_;

stereoFeedBackLimLowHighShelfFull = 
(
  ((par(i,2,_<:bus2):interleave(2,2):(par(i,2,highpass(1,highShelfGroup(xOverFreq))),par(i,2,lowpass(1,lowShelfGroup(xOverFreq))))),(bus(2))):
  (selfMaxXfade(2),bus(2)):interleave(2,3):par(i,2,((_,(lowShelfLim)):(highShelfLim))):stereoLim
)~(bus2)
with {
limLowHighShelf =
  ((_,(lowShelfLim)):(highShelfLim));
};

selfMaxXfade(N) = par(i,N*2,abs)<:(bus(N*2),maximum):interleave(2*N,2):(par(i,N,(crossfade(highShelfGroup(channelLink)))),par(i,N,(crossfade(lowShelfGroup(channelLink)))))
with {
  maximum = bus(N*2)<:par(i,2,seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),max))<:bus(N));
};
chanLink(N) = par(i,N,abs)<:(bus(N),maximum):interleave(N,2):par(i,N,(crossfade(limitGroup(channelLink))))
with {
  maximum = bus(N)<:seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),max))<:bus(N);
};
stereoLim= bus(2)<:(chanLink(2),bus(2)):interleave(2,2):par(i,2,SCfullRangeLim) ;
/*stereoFeedBackLimLowHighShelfFull = */
/*(*/
  /*((par(i,2,_<:bus2):interleave(2,2):(par(i,2,highpass(1,highShelfGroup(xOverFreq))),par(i,2,lowpass(1,lowShelfGroup(xOverFreq)))):selfMaxXfade(2)),bus(2))*/
  /*:interleave(2,3):par(i,2,limLowHighShelfFull)*/
/*)~(bus2);*/

/*selfMaxXfade(N) = bus(N*2)<:(bus(N*2),maximum):interleave(N*2,2):(par(i,N,(crossfade(highShelfGroup(channelLink)))),par(i,N,(crossfade(lowShelfGroup(channelLink)))))*/
/*with {*/
  /*maximum = par(i,N*2,abs)<:par(i,2,seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),max))<:bus(N));*/
/*};*/

/*limLowHighShelfFull =*/
  /*(*/
    /*(_,(lowShelfLim))*/
    /*:*/
    /*(highShelfLim:fullRangeLim)*/
  /*);*/


limLowHighShelfFull =
  (
    (_,(lowShelfLim))
    :
    (highShelfLim:fullRangeLim)
  );
/*stereoFeedBackLimLowHighShelfFull = (((_<:bus(2)),bus(2)):interleave(2,2):(limLowHighShelfFull,limLowHighShelfFull))~(max);*/

/*limLowHighShelfFull =*/
  /*((_<:(_,_)),_):*/
  /*(*/
    /*(_,((lowpass(1,lowShelfGroup(xOverFreq)),_):lowShelfLim))*/
    /*:*/
    /*((highpass(1,highShelfGroup(xOverFreq)),_): highShelfLim:fullRangeLim)*/
  /*);*/

lowShelfLim = ((feedBackLimDetectHold(lowShelfGroup),_):(lowShelfPlusMeter(lowShelfGroup(freq))));
highShelfLim = ((feedBackLimDetectHold(highShelfGroup),_):highShelfPlusMeter(highShelfGroup(freq)));
fullRangeLim = (_<:SCfullRangeLim);
SCfullRangeLim = ((((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1):limitGroup(meter):db2linear)*_);

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

crossfade(x,a,b) = a*(1-x),b*x : +;

lowShelfPlusMeter(freq,gain,dry) = (dry :low_shelf(gain:lowShelfGroup(meter),freq));
highShelfPlusMeter(freq,gain,dry) = (dry :high_shelf(gain:highShelfGroup(meter),freq));

