# shelfMultiBand


A multi-band compressor made out of shelving filters.

When there is no compression going on, it is bit-transparent.



### usage

Here's a quick rundown of the parameters.

The same info is displayed as tooltips


##### threshold:
from what level on should the compression start?

##### ratio:
0 is 1:1 and 1 is 1:inf

##### release:
release time in seconds

##### attack rate:
attack rate in dB/s

##### fast transient:
more GR means quicker release rate

##### min release:
release rate when 'release min/max' is at min, in dB/s

##### fade time:
time to fade from min to max release, in sec.

##### max release:
release rate when 'release min/max' is at min, in dB/s

##### shelf freq:
corner frequency of the shelving filter

##### sidechain x-over freq:
corner frequency of the sidechain cross-over

##### keepSpeed:
keep some of the 'release min/max' value, instead of a full reset to 0

##### pre/post:
amount of GR beiong done inside or outside the shelving limiters

##### channel link:
amount of link between the GR of individual channels

##### high keep:
the amount of high frequencies to be kept

##### high keep frequency:
the frequency from where on the highs should be kept

##### sub keep:
the amount of subs to be kept or killed

##### subKeepFreq:
the frequency from where on the subs should be kept or killed
