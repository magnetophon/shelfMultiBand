declare author "Bart Brouns";
declare license "GPLv3";

import("effect.lib");

process =
FFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,meter,2);
// FBFFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,FBFF,meter,2);
// RMS_FBFFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,FBFF,meter,2);
// RMS_FBcompressor_peak_limiter_N_chan(strength,threshold,thresholdLim,attack,release,knee,prePost,link,meter,2);

 // nrBlocks = int(rmsMaxSize/blockSize);
 // blockSize = 64;
 blockSize = 256;

sr = 44100;
RMStime = vslider("time [unit:ms] [style: knob] [scale:log]", 150, 1, (rmsMaxSize/sr)*1000, 1)/1000;
// rmsMaxSize = 1024; // for block diagram
rmsMaxSize = 2:pow(16);

my_compression_gain_mono(strength,thresh,att,rel,knee,prePost) =
  abs:bypass(prePost,lag_ud(att,rel)) : linear2db : gain_computer(strength,thresh,knee):bypass((prePost*-1)+1,lag_ud(rel,att)) : db2linear;
// my_compression_gain_mono(strength,thresh,att,rel,knee) has a more traditional knee parameter than
// compression_gain_mono(ratio,thresh,att,rel), which also has an internal parameter called knee,
// but that is a time-smoothing of the gain-reduction.
// This knee is a gradual increase in gain reduction around the threshold:
// Below thresh-(knee/2) there is no gain reduction,
// above thresh+(knee/2) there is the same gain reduction as without a knee,
// and in between there is a gradual increase in gain reduction.

// prePost places the level detector either at the input or after the gain computer
// this turns it from a linear return-to-zero detector into a log  domain return-to-threshold detector

// source:
// Digital Dynamic Range Compressor Design
// A Tutorial and Analysis
// DIMITRIOS GIANNOULIS (Dimitrios.Giannoulis@eecs.qmul.ac.uk)
// MICHAEL MASSBERG (michael@massberg.org)
// AND JOSHUA D. REISS (josh.reiss@eecs.qmul.ac.uk)

// It uses a strength parameter instead of the more traditional ratio, in order to be able to
// function as a hard limiter.
// For that you'd need a ratio of infinity:1, and you cannot express that in faust

// Sometimes even bigger ratios are usefull:
// For example a group recording where one instrument is recorded with both a close microphone and a room microphone,
// and the instrument is loud enough in the room mic when playing loud, but you want to boost it when it is playing soft.

gain_computer(strength,thresh,knee,level) =
  select3((level>(thresh-(knee/2)))+(level>(thresh+(knee/2))),
    0,
    ((level-thresh+(knee/2)):pow(2)/(2*knee)) ,
    (level-thresh)
  ) : max(0)*-strength;

RMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost) =
  RMS(rel): bypass(prePost,lag_ud(att,0)) : linear2db : gain_computer(strength,thresh,knee) : bypass((prePost*-1)+1,lag_ud(0,att)) : db2linear;

// add together the last size values:
delaysum(size,maxSize) = _ <: par(i,maxSize, @(i)*(i<size)) :> _;

// the same as above, but much less CPU hungry:
// we devide the time we want to look at into blocks,
// get the sum of the first block, and add it to delayed versions of itself.
// each delay is a multiple of the block size long.
// we switch the blocks on and off depending on the size we want to look at
// finaly, we add a variable block that represents the values that are not covered by the whole blocks.
blockDelaysum(size,block,maxSize) = _ <: variable,par(i,int(maxSize/block), integrate(block)@(int(i*block))*(i<floor(size/block))) :> _ with {
  variable = _ <: par(i,int(maxSize/block), delaysum(int(decimal(size/block)*block),block)@(int(i*block))*(i==floor(size/block))) :> _;
  // integrate(n,x) = x:delaysumFixed(n);
  integrate(n,x) = x - x @ n : + ~ _ ;  // is a bit more efficient: 23% vs 30% CPU
  delaysumFixed(size) = _ <: par(i,size, @(i)) :> _;
};

RMS(time) = pow(_,2):(blockDelaysum(s,blockSize,rmsMaxSize)/s):sqrt with {
  s = int(time*sr):max(1);
};

// generalise compression gains for N channels.
// first we define a mono version:
compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,1) =
  my_compression_gain_mono(strength,thresh,att,rel,knee,prePost);

// the actual N-channel version:
// calculate the maximum gain reduction of N channels,
// and then crossfade between that and each channel's own gain reduction,
// to link/unlink channels
compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N) =
  par(i, N, my_compression_gain_mono(strength,thresh,att,rel,knee,prePost))
  <:(bus(N),(minimum(N)<:bus(N))):interleave(N,2):par(i,N,(crossfade(link)));

minimum(1) = _;
minimum(2) = min;
minimum(N) = (minimum(N-1),_):min;

// an RMS versions of the above
RMS_compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,1) =
  RMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost);

RMS_compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N) =
  par(i, N, RMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost))
  <:(bus(N),(minimum(N)<:bus(N))):interleave(N,2):par(i,N,(crossfade(link)));

// feed forward compressor
FFcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,meter,N) =
  (bus(N) <:
    (compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N),bus(N))
  )
  :(interleave(N,2):par(i,N,meter*_));

// feed back compressor
FBcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,meter,N) =
  (
    (compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N),bus(N))
    :(interleave(N,2):par(i,N,meter*_))
  )~bus(N);

// feed back and/or forward compressor
// the feedback part has a much higher strength, so they end up sounding similar
FBFFcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,FBFF,meter,N) =
  bus(N) <: bus(N*2):
  (
    ((
      (par(i, 2, compression_gain_N_chan(strength*(1+((i==0)*2)),thresh,att,rel,knee,prePost,link,N)):interleave(N,2):par(i, N, crossfade(FBFF)))
      ,bus(N))
      :(interleave(N,2):par(i,N,meter*_))
    )~bus(N)
  );

// RMS feed back and/or forward compressor
// to save CPU we cheat a bit, in a similar way as in the original libs:
// instead of crosfading between two sets of gain calculators as above,
// we take the abs of the audio from both the FF and FB, and crossfade between those,
// and feed that into one set of gain calculators
// again the strength is much higher when in FB mode, but implemented differently
RMS_FBFFcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,FBFF,meter,N) =
  bus(N) <: bus(N*2):
  (
    (
      (
        (interleave(N,2):par(i, N*2, abs) :par(i, N, crossfade(FBFF)) : RMS_compression_gain_N_chan(strength*(1+(((prePost*-1)+1)*4)),thresh,att,rel,knee,prePost,link,N))
        ,bus(N)
      )
    :(interleave(N,2):par(i,N,meter*_))
    )~bus(N)
  );



// RMS feed back compressor into peak limiter feeding back into the FB comp.
// By combining them this way, they complement each other optimally:
// The RMS compressor doesn't have to deal with the peaks,
// and the peak limiter get's spared from the steady state signal.
RMS_FBcompressor_peak_limiter_N_chan(strength,thresh,threshLim,att,rel,knee,prePost,link,meter,N) =
  (
    (
      (
        (RMS_compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N))
        ,bus(N)
      ):(interleave(N,2):par(i,N,meter*_))
    ):FFcompressor_N_chan(1,threshLim,0,att:min(rel),knee*0.5,0,link,meter,N)
  )~bus(N);

crossfade(x,a,b) = a*(1-x),b*x : +;

// bypass switch for any number of channels
// bp -> the switch
// e -> the expression you want to bypass
// NOTE: bypass only makes sense when inputs(e) equals outputs(e)
bypass(bp,e) = bus(N) <: ((inswitch:e),bus(N)) : outswitch with {
  N = inputs(e);
  inswitch =par(i, N, select2(bp,_,0));
  outswitch = interleave(N,2) : par(i, N, select2(bp) );
};

// here bp can be a float between 0 and 1
crossfade_bypass(bp,e) = bus(N) <: ((inswitch:e),bus(N)) : outswitch with {
  N = inputs(e);
  inswitch = par(i, N, crossfade(bp,_,0));
  outswitch = interleave(N,2) : par(i, N, crossfade(bp) );
};

compressor_N_chan_demo(N) =
  bypass(cbp,compressor_N_chan(strength,threshold,attack,release,knee,prePost,link,meter,N):par(i, N, *(makeupgain)));

    comp_group(x) = vgroup("COMPRESSOR  [tooltip: Reference: http://en.wikipedia.org/wiki/Dynamic_range_compression]", x);

    meter_group(x)  = comp_group(vgroup("[0]", x));
    knob_group(x)  = comp_group(hgroup("[1]", x));

    checkbox_group(x)  = meter_group(hgroup("[0]", x));

    cbp = checkbox_group(checkbox("[0] Bypass  [tooltip: When this is checked, the compressor has no effect]"));
    prePost = checkbox_group(checkbox("[1] slow/fast  [tooltip: Unchecked: log  domain return-to-threshold detector
      Checked: linear return-to-zero detector]")*-1)+1;
    maxGR = -100;
    meter = _<:(_, (linear2db:max(maxGR):meter_group((hbargraph("[1][unit:dB][tooltip: gain reduction in dB]", maxGR, 0))))):attach;

    ctl_group(x)  = knob_group(hgroup("[3] Compression Control", x));

    strength = ctl_group(hslider("[0] Strength [style:knob]
      [tooltip: A compression Strength of 0 means no gain reduction and 1 means full gain reduction]",
      1, 0, 8, 0.01));

    threshold = ctl_group(hslider("[1] Threshold [unit:dB] [style:knob]
      [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Strength]",
      0, maxGR, 10, 0.1));

    thresholdRMS = ctl_group(hslider("[1] Threshold RMS [unit:dB] [style:knob]
      [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Strength]",
      0, maxGR, 10, 0.1));

    knee = ctl_group(hslider("[2] Knee [unit:dB] [style:knob]
      [tooltip: soft knee amount in dB]",
      6, 0, 30, 0.1));

    env_group(x)  = knob_group(hgroup("[4] Compression Response", x));

    attack = env_group(hslider("[1] Attack [unit:ms] [style:knob] [scale:log]
      [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new lower target level (the compression `kicking in')]",
      0.1, 0.1, 1000, 0.01)-0.1) : *(0.001) ;
    // The actual attack value is 0.1 smaller than the one displayed.
    // This is done for hard limiting:
    // You need 0 attack for that, but a log scale starting at 0 is useless

    release = env_group(hslider("[2] Release [unit:ms] [style: knob] [scale:log]
      [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",
      100, 1, 10000, 0.1)) : *(0.001) : max(1/SR);

    releaseRMS = env_group(hslider("[2] Release RMS [unit:ms] [style: knob] [scale:log]
      [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",
      100, 1, 10000, 0.1)) : *(0.001) : max(1/SR);

    link = env_group(hslider("[3] link [style:knob]
      [tooltip: 0 means all channels get individual gain reduction, 1 means they all get the same gain reduction]",
      1, 0, 1, 0.01));

    FBFF = env_group(hslider("[3] feed-back/forward [style:knob]
      [tooltip: fade between a feedback and a feed forward compressor design]",
      1, 0, 1, 0.01));

    lim_group(x)  = knob_group(hgroup("[5] Limiter [tooltip: It's release time is the minimum of the attack and release of the compressor,
      and it's knee is half that of the compressor]", x));

    thresholdLim = lim_group(hslider("[9] Threshold [unit:dB] [style:knob]
      [tooltip: The signal leveli never exceeds this threshold]",
      0, -30, 10, 0.1));

    makeupgain = comp_group(hslider("[6] Makeup Gain [unit:dB]
      [tooltip: The compressed-signal output level is increased by this amount (in dB) to make up for the level lost due to compression]",
      0, 0, maxGR*-1, 0.1)) : db2linear;
// };