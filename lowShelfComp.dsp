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
lowShelfGroup(x)  = shelfGroup(vgroup("[2]low shelf", x));
highShelfGroup(x) = shelfGroup(vgroup("[3]high shelf", x));
limitGroup(x)     = shelfGroup(vgroup("[4] full range",x));
GRgroup(x)        = vgroup("[-1][tooltip: gain reduction in dB]gain reduction",x);
HoldGroup(x)      = vgroup("[-2][tooltip: fade from min to max release rate]release min/max",x);
//                =
meter             = _<:(_, max(maxGR):GRgroup((hbargraph("[1][unit:dB][tooltip: gain reduction in dB]", maxGR, 0)))):attach;
holdMeter(group)  = _<:(_, (min(1):max(0):group(HoldGroup(hbargraph("[2][tooltip: fade from min to max release rate]", 0, 1))))):attach;
//                =
threshold         = (hslider("[0]threshold [unit:dB]   [tooltip:]", -11, maxGR, 0, 0.1));
ratio             = (hslider("[1]ratio[tooltip: 0 is 1:1 and 1 is 1:inf]",1, 0,   1,   0.001));
release           = (hslider("[2]release[unit:seconds]   [tooltip: release time in seconds)]",0.001, 0.001, 2, 0.001));
maxRateAttack     = (hslider("[2]attack rate[unit:dB/s][tooltip: attack rate in dB/s ]", 3000, 6, 8000 , 1)/SR);
FastTransient     = (hslider("[2]fast transient[unit:][tooltip: more GR means quicker release rate]", 0.5, 0, 1 , 0.001):pow(3));
minRateDecay      = (hslider("[3]min release[unit:dB/s][tooltip: release rate when 'release min/max' is at min, in dB/s]", 0, 0, 1000 , 1)/SR);
holdTime          = (hslider("[4]fade time[unit:seconds][tooltip: time to fade from min to max release, in sec. ]",0.2, 0,   1,  0.001)*maxHoldTime);
maxRateDecay      = (hslider("[5]max release[unit:dB/s][tooltip: release rate when 'release min/max' is at min, in dB/s]", 200, 1, 2000 , 1)/SR);
freq              = (hslider("[7]shelf freq[unit:Herz][tooltip: corner frequency of the shelving filter]",115, 1,   400,   1));
xOverFreq         = (hslider("[8]sidechain x-over freq[unit:Herz][tooltip: corner frequency of the sidechain cross-over]",115, 1,   400,   1));
keepSpeed         = (hslider("[7]keepSpeed[tooltip: keep some of the 'release min/max' value, instead of a full reset to 0]",1, 0,   1,   0.001));
prePost           = (hslider("[8]pre/post[tooltip: amount of GR beiong done inside or outside the shelving limiters]",1, 0,   1,   0.001));
lowFBthreshold    = 999;//(hslider("[7]low feedback threshold [unit:dB]   [tooltip:threshold of a clipper in the FB path of the low shelf limiter]", -11, maxGR, 0, 0.1));
highFBthreshold   = 999;// (hslider("[8]high feedback threshold [unit:dB]   [tooltip:threshold of a clipper in the FB path of the high shelf limiter]", -11, maxGR, 0, 0.1));
channelLink       = (hslider("[9]channel link[tooltip: amount of link between the GR of individual channels]",1, 0,   1,   0.001));
/*N               = 4;*/
/*process         = ((cross(2*N):par(i,2,cross(N))))~(bus(N),par(i,N,!)):(par(i,N,!),bus(N));*/
/*process         = bus(2*N)<:(bus(N),par(i,N,!),par(i,N,!),bus(N));*/
process           = NchanFeedBackLimLowHighShelfFull(2);
/*process         = feedBackLimLowShelfFull,feedBackLimLowShelfFull;*/
/*process         = feedBackLimLowHighShelf, feedBackLimLowHighShelf;*/

feedBackLimLowShelf     = lowShelfLim~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimHighShelf    = highShelfLim~highpass(1,highShelfGroup(xOverFreq));
feedBackLimLowHighShelf = (lowShelfLim:feedBackLimHighShelf)~lowpass(1,lowShelfGroup(xOverFreq));
feedBackLimLowShelfFull =
  ( lowShelfLim:fullRangeLim
  )
  ~lowpass(1,lowShelfGroup(xOverFreq));

NchanFeedBackLimLowHighShelfFull(N) =
  (
    ((par(i,N,_<:bus2):interleave(2,N)
    :((NchanClipper(limitGroup(highFBthreshold)):par(i,N,highpass(1,highShelfGroup(xOverFreq)):feedBackLimDetectHold(highShelfGroup)))
    ,(NchanClipper(limitGroup(lowFBthreshold)):par(i,N,lowpass(1,lowShelfGroup(xOverFreq)):feedBackLimDetectHold(lowShelfGroup))))),(bus(N))):
    (selfMaxXfade(N),bus(N)):interleave(N,3):par(i,N,((_,(lowShelfPlusMeter(lowShelfGroup(freq)))):(highShelfPlusMeter(highShelfGroup(freq))))):NchanFBlimPre
  )~(par(i,N,!),bus(N)):NchanFBlimPost
    with {
      selfMaxXfade(1) = bus(2);
      selfMaxXfade(N) =
        bus(N*2)<:(bus(N*2),minimum(N)):interleave(2*N,2)
        :(par(i,N,(crossfade(highShelfGroup(channelLink)))),par(i,N,(crossfade(lowShelfGroup(channelLink)))))
        with {
          minimum(N) = bus(N*2)<:par(i,2,seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),min))<:bus(N));
        };
      NchanFBlim= bus(N)<:(FBgr(N),bus(N)):interleave(N,2):par(i,N,gainPlusMeter) ;
      NchanFBlimPre= (bus(N)<:((FBgr(N):par(i,N,limitGroup(meter))),bus(N)))
        :((bus(N)<:((bus(N),par(i,N,_*((limitGroup(prePost)*-1)+1))))),bus(N))
        :(bus(N),(interleave(N,2):par(i,N,db2linear*_)));
      NchanFBlimPost= (par(i,N,_*limitGroup(prePost)),bus(N)):interleave(N,2):par(i,N,db2linear*_);
      FBgr(1) =  hardFeedBackLimDetectHold(limitGroup);
      FBgr(N) =  par(i,N,hardFeedBackLimDetectHold(limitGroup))<:(bus(N),minimum(N)):interleave(N,2):par(i,N,(crossfade(limitGroup(channelLink))))
        with {
          minimum(N) = bus(N)<:seq(j,(log(N)/log(2)),par(k,N/(2:pow(j+1)),min))<:bus(N);
        };
      NchanClipper(tres) = par(i,N,min(tres:db2linear):max(tres:db2linear*-1));
    };

lowShelfLim      = ((feedBackLimDetectHold(lowShelfGroup),_):(lowShelfPlusMeter(lowShelfGroup(freq))));
highShelfLim     = ((feedBackLimDetectHold(highShelfGroup),_):highShelfPlusMeter(highShelfGroup(freq)));
fullRangeLim     = (_<:SCfullRangeLim);
SCfullRangeLim   = ((gainReduction,_):gainPlusMeter);
gainReduction    = ((amp_follower(limitGroup(release)):linear2db:max(_-limitGroup(threshold),0.0))*-1);
gainPlusMeter    = ((limitGroup(meter):db2linear))*_;

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
    select2((level>group(threshold)),(h+1),h*limitGroup(keepSpeed:pow(0.02))): (+(g:pow(4)*limitGroup(FastTransient:pow(2))*group(holdTime)/maxHoldTime)):min(group(holdTime)):max(0);
  };

crossfade(x,a,b) = a*(1-x),b*x : +;

lowShelfPlusMeter(freq,gain,dry) = (dry :low_shelf(gain:lowShelfGroup(meter),freq));
highShelfPlusMeter(freq,gain,dry) = (dry :high_shelf(gain:highShelfGroup(meter),freq));

