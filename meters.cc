/* meter.lv2
 *
 * Copyright (C) 2013 Robin Gareus <robin@gareus.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "lv2/lv2plug.in/ns/lv2core/lv2.h"

#include "jmeters/jmeterdsp.h"
#include "jmeters/vumeterdsp.h"
#include "jmeters/iec1ppmdsp.h"
#include "jmeters/iec2ppmdsp.h"

#define MTR_URI "http://gareus.org/oss/lv2/meters#"

using namespace LV2M;

typedef enum {
	MTR_REFLEVEL = 0,
	MTR_INPUT0   = 1,
	MTR_OUTPUT0  = 2,
	MTR_LEVEL0   = 3,
	MTR_INPUT1   = 4,
	MTR_OUTPUT1  = 5,
	MTR_LEVEL1   = 6
} PortIndex;

typedef struct {
	float  rlgain;
	float  p_refl;
	float* reflvl;

	JmeterDSP *mtr[2];
	float* level[2];
	float* input[2];
	float* output[2];

	int chn;
} LV2meter;


#define MTRDEF(NAME, CLASS) \
	else if (!strcmp(descriptor->URI, MTR_URI NAME "mono")) { \
		self->chn = 1; \
		self->mtr[0] = new CLASS(); \
		static_cast<CLASS *>(self->mtr[0])->init(rate); \
	} \
	else if (!strcmp(descriptor->URI, MTR_URI NAME "stereo")) { \
		self->chn = 2; \
		self->mtr[0] = new CLASS(); \
		self->mtr[1] = new CLASS(); \
		static_cast<CLASS *>(self->mtr[0])->init(rate); \
	}

static LV2_Handle
instantiate(const LV2_Descriptor*     descriptor,
            double                    rate,
            const char*               bundle_path,
            const LV2_Feature* const* features)
{
	LV2meter* self = (LV2meter*)calloc(1, sizeof(LV2meter));

	if (!self) return NULL;

	if (0);
	MTRDEF("VU", Vumeterdsp)
	MTRDEF("BBC", Iec2ppmdsp)
	MTRDEF("EBU", Iec2ppmdsp)
	MTRDEF("DIN", Iec1ppmdsp)
	MTRDEF("NOR", Iec1ppmdsp)
	else {
		free(self);
		return NULL;
	}

	self->rlgain = 1.0;
	self->p_refl = -9999;

	return (LV2_Handle)self;
}

static void
connect_port(LV2_Handle instance,
             uint32_t   port,
             void*      data)
{
	LV2meter* self = (LV2meter*)instance;

	switch ((PortIndex)port) {
	case MTR_REFLEVEL:
		self->reflvl = (float*) data;
		break;
	case MTR_INPUT0:
		self->input[0] = (float*) data;
		break;
	case MTR_OUTPUT0:
		self->output[0] = (float*) data;
		break;
	case MTR_LEVEL0:
		self->level[0] = (float*) data;
		break;
	case MTR_INPUT1:
		self->input[1] = (float*) data;
		break;
	case MTR_OUTPUT1:
		self->output[1] = (float*) data;
		break;
	case MTR_LEVEL1:
		self->level[1] = (float*) data;
		break;
	}
}

static void
run(LV2_Handle instance, uint32_t n_samples)
{
	LV2meter* self = (LV2meter*)instance;

	if (self->p_refl != *self->reflvl) {
		self->p_refl = *self->reflvl;
		self->rlgain = powf (10.0f, 0.05f * (self->p_refl + 18.0));
	}

	int c;
	for (c = 0; c < self->chn; ++c) {

		float* const input  = self->input[c];
		float* const output = self->output[c];

		self->mtr[c]->process(input, n_samples);

		*self->level[c] = self->rlgain * self->mtr[c]->read();

		if (input != output) {
			memcpy(output, input, sizeof(float) * n_samples);
		}
	}
}

static void
cleanup(LV2_Handle instance)
{
	LV2meter* self = (LV2meter*)instance;
	for (int c = 0; c < self->chn; ++c) {
		delete self->mtr[c];
	}
	free(instance);
}

const void*
extension_data(const char* uri)
{
	return NULL;
}

#define mkdesc(ID, NAME) \
static const LV2_Descriptor descriptor ## ID = { \
	MTR_URI NAME, \
	instantiate, \
	connect_port, \
	NULL, \
	run, \
	NULL, \
	cleanup, \
	extension_data \
};

mkdesc(0, "VUmono")
mkdesc(1, "VUstereo")
mkdesc(2, "BBCmono")
mkdesc(3, "BBCstereo")
mkdesc(4, "EBUmono")
mkdesc(5, "EBUstereo")
mkdesc(6, "DINmono")
mkdesc(7, "DINstereo")
mkdesc(8, "NORmono")
mkdesc(9, "NORstereo")

LV2_SYMBOL_EXPORT
const LV2_Descriptor*
lv2_descriptor(uint32_t index)
{
	switch (index) {
	case 0: return &descriptor0;
	case 1: return &descriptor1;
	case 2: return &descriptor2;
	case 3: return &descriptor3;
	case 4: return &descriptor4;
	case 5: return &descriptor5;
	case 6: return &descriptor6;
	case 7: return &descriptor7;
	case 8: return &descriptor8;
	case 9: return &descriptor9;
	default:
		return NULL;
	}
}
