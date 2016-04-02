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
declare version   "0.4";
declare copyright "(C) 2015 Bart Brouns";

import ("effect.lib");

sr = 44100;
maxHoldTime = 1*sr; //sec
maxGR = -40;

mainGroup(x)      = (vgroup("[1]", x));
shelfGroup(x)     = mainGroup(hgroup("[0]", x));
lowShelfGroup(x)  = shelfGroup(vgroup("[2]low shelf", x));
highShelfGroup(x) = shelfGroup(vgroup("[3]high shelf", x));
limitGroup(x)     = shelfGroup(vgroup("[4] full range",x));
GRgroup(x)        = vgroup("[-1][tooltip: gain reduction in dB]gain reduction",x);
HoldGroup(x)      = vgroup("[-2][tooltip: fade from min to max release rate]release min/max",x);
//                =
meter             = _<:(_, (max(maxGR):GRgroup((hbargraph("[1][unit:dB][tooltip: gain reduction in dB]", maxGR, 0))))):attach;
holdMeter(group)  = _<:(_, (min(1):max(0):group(HoldGroup(hbargraph("[2][tooltip: fade from min to max release rate]", 0, 1))))):attach;
//                =
threshold         = (hslider("[00]threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
ratio             = (hslider("[01]ratio[tooltip: 0 is 1:1 and 1 is 1:inf]",1, 0,   1,   0.001));
release           = (hslider("[02]release[unit:seconds]   [tooltip: release time in seconds)]",0.001, 0.001, 2, 0.001));
maxRateAttack     = (hslider("[02]attack rate[unit:dB/s][tooltip: attack rate in dB/s ]", 3000, 6, 8000 , 1)/SR);
FastTransient     = (hslider("[02]fast transient[unit:][tooltip: more GR means quicker release rate]", 0.5, 0, 1 , 0.001):pow(3));
minRateDecay      = (hslider("[03]min release[unit:dB/s][tooltip: release rate when 'release min/max' is at min, in dB/s]", 0, 0, 1000 , 1)/SR);
holdTime          = (hslider("[04]fade time[unit:seconds][tooltip: time to fade from min to max release, in sec. ]",0.2, 0,   1,  0.001)*maxHoldTime);
maxRateDecay      = (hslider("[05]max release[unit:dB/s][tooltip: release rate when 'release min/max' is at min, in dB/s]", 200, 1, 2000 , 1)/SR);
freq              = (hslider("[07]shelf freq[unit:Herz][tooltip: corner frequency of the shelving filter]",115, 1,   400,   1));
xOverFreq         = (hslider("[08]sidechain x-over freq[unit:Herz][tooltip: corner frequency of the sidechain cross-over]",115, 1,   400,   1));
keepSpeed         = (hslider("[07]keepSpeed[tooltip: keep some of the 'release min/max' value, instead of a full reset to 0]",1, 0,   1,   0.001));
prePost           = (hslider("[08]pre/post[tooltip: amount of GR beiong done inside or outside the shelving limiters]",1, 0,   1,   0.001))*prePostEnabled;
channelLink       = (hslider("[09]channel link[tooltip: amount of link between the GR of individual channels]",1, 0,   1,   0.001));
highKeep          = (hslider("[10]high keep[tooltip: the amount of high frequencies to be kept]",1, 0,   1,   0.001));
highKeepFreq      = (hslider("[11]high keep frequency[tooltip: the frequency from where on the highs should be kept ]",8000, 1000,   sr/2,   1));
subKeep          = (hslider("[10]sub keep[tooltip: the amount of subs to be kept or killed]",-1, -1,   1,   0.001));
subKeepFreq      = (hslider("[11]sub keep frequency[tooltip: the frequency from where on the subs should be kept or killed ]",30, 1,   400,   1));
/*N               = 4;*/
/*N               = 4;*/
/*process         = ((cross(2*N):par(i,2,cross(N))))~(bus(N),par(i,N,!)):(par(i,N,!),bus(N));*/
/*process         = bus(2*N)<:(bus(N),par(i,N,!),par(i,N,!),bus(N));*/
process           = NchanFeedBackLimLowHighShelfFull(2);
prePostEnabled = 1;
// process           = NchanFeedBackLimFull(2);
// process = high_shelf(highKeep,highKeepFreq);
// process = highKeeper;
// process = minimum(6);
/*process         = feedBackLimLowShelfFull,feedBackLimLowShelfFull;*/
/*process         = feedBackLimLowHighShelf, feedBackLimLowHighShelf;*/

feedBackLimLowShelf     = lowShelfLim~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimHighShelf    = highShelfLim~highpass(1,highShelfGroup(xOverFreq));
feedBackLimLowHighShelf = (lowShelfLim:feedBackLimHighShelf)~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimLowShelfFull =
  ( lowShelfLim:fullRangeLim
  )
  ~lowpass(1,lowShelfGroup(xOverFreq));

NchanFeedBackLimFull(N) = NchanFBlim(N);

selfMaxXfade(1) = bus(2);
selfMaxXfade(N) =
  bus(N*2)<:(bus(N*2),par(i,2,(minimum(N)<:bus(N)))):interleave(2*N,2)
  :(par(i,N,(crossfade(highShelfGroup(channelLink)))),par(i,N,(crossfade(lowShelfGroup(channelLink)))));

NchanFBlim(N)= (bus(N)<:((FBgr(N):par(i,N,limitGroup(meter))),bus(N)))
:(interleave(N,2):par(i,N,(db2linear*_)));

NchanFBlimPre(N)= (bus(N)<:((FBgr(N):par(i,N,limitGroup(meter))),bus(N)))
  :((bus(N)<:((bus(N),par(i,N,_*((limitGroup(prePost)*-1)+1))))),bus(N))
  :(bus(N),(interleave(N,2):par(i,N,db2linear*_)));
NchanFBlimPost(N)= (par(i,N,_*limitGroup(prePost)),bus(N)):interleave(N,2):par(i,N,db2linear*_);
FBgr(1) =  hardFeedBackLimDetectHold(limitGroup);
FBgr(N) =  par(i,N,hardFeedBackLimDetectHold(limitGroup))<:(bus(N),(minimum(N)<:bus(N))):interleave(N,2):par(i,N,(crossfade(limitGroup(channelLink))));

// NchanFeedBackLimLowShelf(N) =
//   (
//     (
//     (
//     ,(par(i,N,lowpass(1,lowShelfGroup(xOverFreq)):feedBackLimDetectHold(lowShelfGroup))))),(bus(N))):
//     (selfMaxXfade(N),bus(N)):interleave(N,3):par(i,N,((_,(lowShelfPlusMeter(lowShelfGroup(freq)))):(highShelfPlusMeter(highShelfGroup(freq))))):NchanFBlimPre(N)
//   )~(par(i,N,!),bus(N)):NchanFBlimPost(N)
//     with {
//     };

NchanFeedBackLimHighShelf(N) =
  (
    ((par(i,N,_<:bus2):interleave(2,N)
    :((par(i,N,highpass(1,highShelfGroup(xOverFreq)):feedBackLimDetectHold(highShelfGroup)))
    ,(par(i,N,lowpass(1,lowShelfGroup(xOverFreq)):feedBackLimDetectHold(lowShelfGroup))))),(bus(N))):
    (selfMaxXfade(N),bus(N)):interleave(N,3):par(i,N,((_,(lowShelfPlusMeter(lowShelfGroup(freq)))):(highShelfPlusMeter(highShelfGroup(freq))))):NchanFBlimPre(N)
  )~(par(i,N,!),bus(N)):NchanFBlimPost(N)
    with {
    };

NchanFeedBackLimLowHighShelfFull(N) =
  (
    ((par(i,N,_<:bus2):interleave(2,N)
    :((par(i,N,highpass(1,highShelfGroup(xOverFreq)):feedBackLimDetectHold(highShelfGroup)))
    ,(par(i,N,lowpass(1,lowShelfGroup(xOverFreq)):feedBackLimDetectHold(lowShelfGroup))))),(bus(N))):
    (selfMaxXfade(N),bus(N)):interleave(N,3):par(i,N,((_,(lowShelfGroup(subKeeper):lowShelfPlusMeter(lowShelfGroup(freq)))):(highShelfGroup(highKeeper):highShelfPlusMeter(highShelfGroup(freq))))):NchanFBlimPre(N)
  )~(par(i,N,!),bus(N)):NchanFBlimPost(N)
    with {
    };

minimum(1) = _;
minimum(2) = min;
minimum(N) = (minimum(N-1),_):min;

lowShelfLim      = ((feedBackLimDetectHold(lowShelfGroup),_):(lowShelfPlusMeter(lowShelfGroup(freq))));
highShelfLim     = ((feedBackLimDetectHold(highShelfGroup),_):highShelfPlusMeter(highShelfGroup(freq)));
fullRangeLim     = (_<:SCfullRangeLim);
SCfullRangeLim   = ((gainReduction,_):gainPlusMeter);
gainReduction    = ((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1);
gainPlusMeter    = ((limitGroup(meter):db2linear))*_;

highKeeper(gain,x) =
gain,(x:high_shelf((gain*-1*highKeep),highKeepFreq));

subKeeper(gain,x) =
gain,(x:low_shelf((((gain+6):min(0))*-1*subKeep:min(20)),subKeepFreq));

feedBackLimDetectHold(group,x) = (gain,hold)~((_,(_<:_,_))):(_*group(ratio),!)
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
    + g :max(2*maxGR):min(0)
  );
  holdPercentage(h) = (h/(group(holdTime):max(0.0001))):min(1):max(0);
  hold =
    select2((level>group(threshold)),(_+1),0): min(group(maxHoldTime));
  };

hardFeedBackLimDetectHold(group,x) = (gain,hold)~(((_<:_,_),(_<:_,_)):interleave(2,2)):(_*group(ratio),!)
  with {
  level =
    (abs(x):linear2db);
  gain(g,h) =
  (
    ((level<group(threshold))*crossfade(holdPercentage(h): holdMeter(group),group(minRateDecay),group(maxRateDecay)))
    + g :min(x:((abs:linear2db:max(_-limitGroup(threshold),0.0))*-1)):max(2*maxGR):min(0)
  );
  holdPercentage(h) = (h/(group(holdTime):max(0.0001))):min(1):max(0);
  hold(g,h) =
    select2((level>group(threshold)),(h+1),h*limitGroup(keepSpeed:pow(0.02))): (+(g*.25:pow(4)*limitGroup(FastTransient:pow(.5)*8)*group(holdTime)/maxHoldTime)):min(group(holdTime)):max(0);
  };

crossfade(x,a,b) = a*(1-x),b*x : +;

lowShelfPlusMeter(freq,gain,dry) = (dry :low_shelf(gain:lowShelfGroup(meter),freq));
highShelfPlusMeter(freq,gain,dry) = (dry :high_shelf(gain:highShelfGroup(meter),freq));
