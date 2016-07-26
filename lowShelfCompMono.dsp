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
declare name      "lowShelfCompMono";
declare author    "Bart Brouns";
declare version   "0.5.1";
declare copyright "(C) 2015 Bart Brouns";

import ("lowShelfComp.lib");

process           = NchanFeedBackLimLowHighShelfFull(1);
