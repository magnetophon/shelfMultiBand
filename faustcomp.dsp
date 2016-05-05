declare author "Bart Brouns";
declare license "GPLv3";

// import("/home/bart/Downloads/fst.rms.dsp");
import("effect.lib");

// process = compressor_N_chan_demo(2);
peakG(x) = hgroup("peak", x);
rmsG(x) = hgroup("rms", x);
process =
FFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,meter,2);
// FBFFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,FBFF,meter,2);
// peakRMS_FBFFcompressor_N_chan(strength,threshold,thresholdRMS,attack,release,releaseRMS,knee,prePost,link,FBFF,meter,2);

// bus(2)<:(
// (   peakG(FBFFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,FBFF,meter,2):(par(i, 2, _*cbp)))),
// (rmsG(RMS_FBFFcompressor_N_chan(strength,threshold,attack,release,knee,prePost,link,FBFF,meter,2):(par(i, 2, _*((cbp*-1))))))
// ):>bus(2);

sr = 44100;
RMStime = vslider("time [unit:ms] [style: knob] [scale:log]", 150, 1, (rmsMaxSize/sr)*1000, 1)/1000;
rmsMaxSize = 2:pow(12);

my_compression_gain_mono(strength,thresh,att,rel,knee,prePost) =
  // amp_follower_ar(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs:lag_ud(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs : linear2db : GR(strength,thresh,knee):lag_ud(rel,att) : db2linear
  abs:bypass(prePost,lag_ud(att,rel)) : linear2db : gain_computer(strength,thresh,knee):bypass((prePost*-1)+1,lag_ud(rel,att)) : db2linear
with {
// my_compression_gain_mono(strength,thresh,att,rel,knee) has a more traditional knee parameter than
// compression_gain_mono(ratio,thresh,att,rel), which also has an internal parameter called knee,
// but that is a time-smoothing of the gain-reduction
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

  gain_computer(strength,thresh,knee,level) =
    select3((level>(thresh-(knee/2)))+(level>(thresh+(knee/2))),
      0,
      ((level-thresh+(knee/2)):pow(2)/(2*knee)) ,
      (level-thresh)
    ) : max(0)*-strength;
};

RMS(att,rel) = pow(2) : lag_ud(att,rel) : sqrt;

RMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost) =
  // amp_follower_ar(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs:lag_ud(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs : linear2db : GR(strength,thresh,knee):lag_ud(rel,att) : db2linear
  abs : bypass(prePost,RMS(att,rel)) : linear2db : gain_computer(strength,thresh,knee) : bypass((prePost*-1)+1,_*-1:RMS(att,rel)*-1) : db2linear
  // RMS(RMStime) : linear2db : gain_computer(strength,thresh,knee) : db2linear
with {
  gain_computer(strength,thresh,knee,level) =
    select3((level>(thresh-(knee/2)))+(level>(thresh+(knee/2))),
      0,
      ((level-thresh+(knee/2)):pow(2)/(2*knee)) ,
      (level-thresh)
    ) : max(0)*-strength;
};

OLDpeakRMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost) =
  // amp_follower_ar(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs:lag_ud(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs : linear2db : GR(strength,thresh,knee):lag_ud(rel,att) : db2linear
  abs:bypass(prePost,lag_ud(att,rel)) : linear2db :bypass((prePost*-1)+1,lag_ud(att,rel))<:(
  peakG(gain_computer(strength,thresh,knee)),
  rmsG(gain_computer(strength,thresh,knee): _*-1:RMS(att,rel):_*-1)
  ):min :db2linear
  // RMS(RMStime) : linear2db : gain_computer(strength,thresh,knee) : db2linear
with {
 crest= vslider("crest", 0, -20, 20, 0.1);
  gain_computer(strength,thresh,knee,level) =
    select3((level>(thresh-(knee/2)))+(level>(thresh+(knee/2))),
      0,
      ((level-thresh+(knee/2)):pow(2)/(2*knee)) ,
      (level-thresh)
    ) : max(0)*-strength;
};

peakRMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost) =
  // amp_follower_ar(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs:lag_ud(att,rel) : linear2db : GR(strength,thresh,knee) : db2linear
  // abs : linear2db : GR(strength,thresh,knee):lag_ud(rel,att) : db2linear
  abs:bypass(prePost,lag_ud(att,rel)) : linear2db :bypass((prePost*-1)+1,lag_ud(att,rel))<:(
  peakG(gain_computer(strength,thresh,knee)),
  rmsG(gain_computer(strength,thresh,knee): _*-1:RMS(att,rel):_*-1)
  ):min :db2linear;
  // RMS(RMStime) : linear2db : gain_computer(strength,thresh,knee) : db2linear

  gain_computer(strength,thresh,knee,level) =
    select3((level>(thresh-(knee/2)))+(level>(thresh+(knee/2))),
      0,
      ((level-thresh+(knee/2)):pow(2)/(2*knee)) ,
      (level-thresh)
    ) : max(0)*-strength;

// calculate the maximum gain reduction of N channels,
// and then crossfade between that and each channel's own gain reduction,
// to link/unlink channels
compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,1) =
  my_compression_gain_mono(strength,thresh,att,rel,knee,prePost);

compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N) =
 par(i, N, my_compression_gain_mono(strength,thresh,att,rel,knee,prePost))
 <:(bus(N),(minimum(N)<:bus(N))):interleave(N,2):par(i,N,(crossfade(link)))
 with {
    minimum(1) = _;
    minimum(2) = min;
    minimum(N) = (minimum(N-1),_):min;
  };

RMS_compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,1) =
  RMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost);

RMS_compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N) =
 par(i, N, RMS_compression_gain_mono(strength,thresh,att,rel,knee,prePost))
 <:(bus(N),(minimum(N)<:bus(N))):interleave(N,2):par(i,N,(crossfade(link)))
 with {
    minimum(1) = _;
    minimum(2) = min;
    minimum(N) = (minimum(N-1),_):min;
  };

// feed forward compressor
FFcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,meter,N) =
  (bus(N) <:
  (compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N),bus(N)))
  :(interleave(N,2):par(i,N,meter*_));

// feed back compressor
FBcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,meter,N) =
  (
  (compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N),bus(N))
  :(interleave(N,2):par(i,N,meter*_))
  )~bus(N);

// feed back and/or forward compressor
FBFFcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,FBFF,meter,N) =
  bus(N) <: bus(N*2):
  (((
  (par(i, 2, compression_gain_N_chan(strength*(1+((i==0)*2)),thresh,att,rel,knee,prePost,link,N)):interleave(N,2):par(i, N, crossfade(FBFF)))
  ,bus(N))
  :(interleave(N,2):par(i,N,meter*_))
  )~bus(N));

// RMS feed back and/or forward compressor
RMS_FBFFcompressor_N_chan(strength,thresh,att,rel,knee,prePost,link,FBFF,meter,N) =
  bus(N) <: bus(N*2):
  (((
  (interleave(N,2):par(i, N, crossfade(FBFF)):RMS_compression_gain_N_chan(strength,thresh,att,rel,knee,prePost,link,N))
  ,bus(N))
  :(interleave(N,2):par(i,N,meter*_))
  )~bus(N));



// RMS feed back and/or forward compressor
peakRMS_FBFFcompressor_N_chan(strength,thresh,thresRMS,att,rel,relRMS,knee,prePost,link,FBFF,meter,N) =
  bus(N) <: bus(N*2):
  (((
  ((RMS_compression_gain_N_chan(strength,thresRMS,att,rel,6+knee,1,link,N),compression_gain_N_chan(strength,thresh,0,att,knee,prePost,link,N)):(interleave(N,2):par(i,N,min)))
  ,bus(N))
  :(interleave(N,2):par(i,N,meter*_))
  )~bus(N));

crossfade(x,a,b) = a*(1-x),b*x : +;

// bypass switch for any number of channels
// bpc -> the switch
// e -> the expression you want to bypass
// NOTE: bypass only makes sense when inputs(e) equals outputs(e)
bypass(bpc,e) = bus(N) <: ((inswitch:e),bus(N)) : outswitch with {
  N = inputs(e);
  inswitch = bus(N) : par(i, N, select2(bpc,_,0)) : bus(N);
  outswitch = interleave(N,2) : par(i, N, select2(bpc) ) : bus(N);
};

// here bpc can be a fader
crossfade_bypass(bpc,e) = bus(N) <: ((inswitch:e),bus(N)) : outswitch with {
  N = inputs(e);
  inswitch = bus(N) : par(i, N, crossfade(bpc,_,0)) : bus(N);
  outswitch = interleave(N,2) : par(i, N, crossfade(bpc) ) : bus(N);
};

compressor_N_chan_demo(N) =
  bypass(cbp,compressor_N_chan(strength,threshold,attack,release,knee,prePost,link,meter,N):par(i, N, *(makeupgain)))
;
// with {

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
    // It can also be 'abused' for greater than infinity ratios:
    // with strength > 1 the output level goes down when the input is above the threshold

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

    makeupgain = comp_group(hslider("[5] Makeup Gain [unit:dB]
      [tooltip: The compressed-signal output level is increased by this amount (in dB) to make up for the level lost due to compression]",
      0, 0, maxGR*-1, 0.1)) : db2linear;
// };