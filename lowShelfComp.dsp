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
maxGR = -40;

mainGroup(x)      = (vgroup("[1]", x));
shelfGroup(x)     = mainGroup(hgroup("[0]", x));
/*limitGroup(x)     = mainGroup(vgroup("[1] full range",x));*/
lowShelfGroup(x)  = shelfGroup(vgroup("[2]low shelf", x));
highShelfGroup(x) = shelfGroup(vgroup("[3]high shelf", x));
limitGroup(x)     = shelfGroup(vgroup("[4] full range",x));
//                =
meter             = _<:(_, ((hbargraph("[-1]gain reduction[unit:dB][tooltip: input level in dB]", maxGR, 0)))):attach;
holdMeter(group)  = _<:(_, (min(1):max(0):group(hbargraph("[-1]hold percentage", 0, 1)))):attach;
threshold         = (hslider("[0]threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
inThreshold         = (hslider("[1]in threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
release           = (hslider("[1]release[unit:seconds]   [tooltip: release time in seconds)]",0.001, 0.001, 2, 0.001));
maxRateAttack     = (hslider("[1]attack[unit:dB/s][tooltip: ]", 3000, 6, 8000 , 1)/SR);
smoo              = ((hslider("[1]smoo[unit:][tooltip: ]", 0.5, 0, 1 , 0.001)))*10;
minRateDecay      = (hslider("[2]min release[unit:dB/s][tooltip: ]", 0, 0, 1000 , 1)/SR);
holdTime          = (hslider("[3]hold time[unit:seconds][tooltip: ]",0.2, 0,   1,  0.001)*maxHoldTime);
maxRateDecay      = (hslider("[4]max release[unit:dB/s][tooltip: ]", 200, 1, 2000 , 1)/SR);
freq              = (hslider("[6]shelf freq[tooltip: ]",115, 1,   400,   1));
xOverFreq         = (hslider("[7]sidechain x-over freq[tooltip: ]",115, 1,   400,   1));
outThreshold         = (hslider("[6]out threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
FBthreshold         = (hslider("[7]feedback threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
lowFBthreshold         = (hslider("[6]low feedback threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
highFBthreshold         = (hslider("[7]high feedback threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
channelLink       = (hslider("[8]channel link[tooltip: ]",1, 0,   1,   0.001));

process = NchanFeedBackLimLowHighShelfFull(2);
/*process = feedBackLimLowShelfFull,feedBackLimLowShelfFull;*/
/*process = feedBackLimLowHighShelf, feedBackLimLowHighShelf;*/

feedBackLimLowShelf = lowShelfLim~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimHighShelf = highShelfLim~highpass(1,highShelfGroup(xOverFreq));
feedBackLimLowHighShelf = (lowShelfLim:feedBackLimHighShelf)~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimLowShelfFull =
  ( lowShelfLim:fullRangeLim
  )
  ~lowpass(1,lowShelfGroup(xOverFreq));

NchanFeedBackLimLowHighShelfFull(1) =
  (((_<:(highpass(1,highShelfGroup(xOverFreq)),lowpass(1,lowShelfGroup(xOverFreq)))),_): ((_,(lowShelfLim)):(highShelfLim:fullRangeLim)))~_;

NchanFeedBackLimLowHighShelfFull(N) =
  (
    ((par(i,N,_<:bus2):interleave(2,N)
    :((NchanClipper(limitGroup(highFBthreshold)):par(i,N,highpass(1,highShelfGroup(xOverFreq)):feedBackLimDetectHold(highShelfGroup)))
    ,(NchanClipper(limitGroup(lowFBthreshold)):par(i,N,lowpass(1,lowShelfGroup(xOverFreq)):feedBackLimDetectHold(lowShelfGroup))))),(bus(N))):
    (selfMaxXfade(N),bus(N)):interleave(N,3):par(i,N,((_,(lowShelfPlusMeter(lowShelfGroup(freq)))):(highShelfPlusMeter(highShelfGroup(freq)))))
  )~bus(N):NchanFBlim
    with {
      selfMaxXfade(N) =
        bus(N*2)<:(bus(N*2),maximum):interleave(2*N,2)
        :(par(i,N,(crossfade(highShelfGroup(channelLink)))),par(i,N,(crossfade(lowShelfGroup(channelLink)))))
        with {
          maximum = bus(N*2)<:par(i,2,seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),min))<:bus(N));
        };
      NchanLim= bus(N)<:(chanLink(N),bus(N)):interleave(N,2):par(i,N,gainPlusMeter) ;
      chanLink(N) = par(i,N,gainReduction)<:(bus(N),maximum):interleave(N,2):par(i,N,(crossfade(limitGroup(channelLink))))
        with {
          maximum = bus(N)<:seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),min))<:bus(N);
        };
      NchanFBlim= bus(N)<:(FBgr(N),bus(N)):interleave(N,2):par(i,N,gainPlusMeter) ;
      FBgr(N) =  par(i,N,hardFeedBackLimDetectHold(limitGroup))<:(bus(N),maximum):interleave(N,2):par(i,N,(crossfade(limitGroup(channelLink))))
        with {
          maximum = bus(N)<:seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),min))<:bus(N);
        };
      NchanClipper(tres) = par(i,N,min(tres:db2linear):max(tres:db2linear*-1));
    };

lowShelfLim = ((feedBackLimDetectHold(lowShelfGroup),_):(lowShelfPlusMeter(lowShelfGroup(freq))));
highShelfLim = ((feedBackLimDetectHold(highShelfGroup),_):highShelfPlusMeter(highShelfGroup(freq)));
fullRangeLim = (_<:SCfullRangeLim);
SCfullRangeLim = ((gainReduction,_):gainPlusMeter);
gainReduction = ((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1);
gainPlusMeter = ((limitGroup(meter):db2linear))*_;
/*SCfullRangeLim = ((((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1):limitGroup(meter):db2linear)*_);*/

feedBackLimDetectHold(group,x) = (gain,hold)~((_,(_<:_,_))):(_,!)
  with {
  level =
    (abs(x):linear2db);
  gain(g,h) =
  (
    (
        ((level>group(threshold))*group(maxRateAttack)*-1)
        +
        ((level<group(threshold))*crossfade(holdPercentage(h): holdMeter(group),group(minRateDecay),group(maxRateDecay)))
    )
    + g :max(maxGR):min(0)
  );
  holdPercentage(h) = (h/(group(holdTime):max(0.0001))):min(1):max(0);
  hold = 
    select2((level>group(threshold)),(_+1),0): min(group(maxHoldTime));
  };

hardFeedBackLimDetectHold(group,x) = (gain,hold)~(((_<:_,_),(_<:_,_)):interleave(2,2)):(_,!)
  with {
  level =
    (abs(x):linear2db);
  gain(g,h) =
  (
    ((level<group(threshold))*crossfade(holdPercentage(h): holdMeter(group),group(minRateDecay),group(maxRateDecay)))
    + g :min(x:((abs:linear2db:max(_-limitGroup(threshold),0.0))*-1)):max(maxGR):min(0)
  );
  holdPercentage(h) = (h/(group(holdTime):max(0.0001))):min(1):max(0);
  hold(g,h) = 
    h<:select2((level>group(threshold)),(_+1),0): (-(g:pow(3)*0.05*limitGroup(smoo)*group(holdTime)/maxHoldTime)):min(group(holdTime)):max(0);
  };

crossfade(x,a,b) = a*(1-x),b*x : +;

lowShelfPlusMeter(freq,gain,dry) = (dry :low_shelf(gain:lowShelfGroup(meter),freq));
highShelfPlusMeter(freq,gain,dry) = (dry :high_shelf(gain:highShelfGroup(meter),freq));

