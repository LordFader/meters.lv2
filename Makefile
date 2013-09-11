#!/usr/bin/make -f

# these can be overridden using make variables. e.g.
#   make CFLAGS=-O2
#   make install DESTDIR=$(CURDIR)/debian/meters.lv2 PREFIX=/usr
#
OPTIMIZATIONS ?= -msse -msse2 -mfpmath=sse -ffast-math -fomit-frame-pointer -O3 -fno-finite-math-only
PREFIX ?= /usr/local
CFLAGS ?= -Wall -Wno-unused-function
LIBDIR ?= lib

EXTERNALUI?=yes
KXURI?=yes

override CFLAGS += -g $(OPTIMIZATIONS)
BUILDDIR=build/
###############################################################################
LIB_EXT=.so

LV2DIR ?= $(PREFIX)/$(LIBDIR)/lv2
LOADLIBES=-lm

LV2NAME=meters

LV2GTK1=needle_gtk
LV2GTK2=eburUI_gtk
LV2GTK3=goniometerUI_gtk
LV2GTK4=dpmUI_gtk

LV2GUI1=needle_gl
LV2GUI2=eburUI_gl
LV2GUI3=goniometerUI_gl
LV2GUI4=dpmUI_gl

BUNDLE=meters.lv2

#########
#override CFLAGS+=-DVISIBLE_EXPOSE
MTRGUI=mtr:needle
EBUGUI=mtr:eburui
GONGUI=mtr:goniometerui
DPMGUI=mtr:dpmui

#########


LV2UIREQ=
GLUICFLAGS=-I.
GTKUICFLAGS=-I.

## TODO OSX gl/x11
UNAME=$(shell uname)
ifeq ($(UNAME),Darwin)
  LV2LDFLAGS=-dynamiclib
  LIB_EXT=.dylibA
  UI_TYPE=ui:CocoaUI
  PUGL_SRC=pugl/pugl_osx.m
  $(error OSX is not yet supported)
# TODO set flags (see setBfree) set pugl sources...
else
  LV2LDFLAGS=-Wl,-Bstatic -Wl,-Bdynamic
  LIB_EXT=.so
  UI_TYPE=ui:X11UI
  PUGL_SRC=pugl/pugl_x11.c
endif

ifeq ($(EXTERNALUI), yes)
  ifeq ($(KXURI), yes)
    UI_TYPE=kx:Widget
    LV2UIREQ+=lv2:requiredFeature kx:Widget;\\n\\t
    override CFLAGS += -DXTERNAL_UI
  else
    LV2UIREQ+=lv2:requiredFeature ui:external;\\n\\t
    override CFLAGS += -DXTERNAL_UI
    UI_TYPE=ui:external
  endif
endif

targets=$(BUILDDIR)$(LV2NAME)$(LIB_EXT)

ifneq ($(BUILDOPENGL), no)
targets+=$(BUILDDIR)$(LV2GUI1)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GUI2)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GUI3)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GUI4)$(LIB_EXT)
endif

targets+=$(BUILDDIR)$(LV2GTK1)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GTK2)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GTK3)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GTK4)$(LIB_EXT)

# check for build-dependencies
ifeq ($(shell pkg-config --exists lv2 || echo no), no)
  $(error "LV2 SDK was not found")
endif

ifeq ($(shell pkg-config --exists glib-2.0 gtk+-2.0 pango cairo glu || echo no), no)
  $(error "This plugin requires cairo, pango, openGL, glib-2.0 and gtk+-2.0")
endif

# check for LV2 idle thread
ifeq ($(shell pkg-config --atleast-version=1.4.2 lv2 && echo yes), yes)
  GLUICFLAGS+=-DHAVE_IDLE_IFACE
  GTKUICFLAGS+=-DHAVE_IDLE_IFACE
  LV2UIREQ+=lv2:requiredFeature ui:idleInterface;\\n\\tlv2:extensionData ui:idleInterface;
endif

override CFLAGS += -fPIC
override CFLAGS += `pkg-config --cflags lv2`

IM=gui/img/
RW=robtk/
RT=$(RW)rtk/
WD=$(RW)widgets/robtk_

UIIMGS=$(IM)meter-bright.c $(IM)meter-dark.c $(IM)screw.c
GTKUICFLAGS+=`pkg-config --cflags gtk+-2.0 cairo pango`
GTKUILIBS+=`pkg-config --libs gtk+-2.0 cairo pango`

GLUICFLAGS+=`pkg-config --cflags glu cairo pango`
GLUILIBS+=`pkg-config --libs glu cairo pango` -lX11

ifeq ($(GLTHREADSYNC), yes)
  GLUICFLAGS+=-DTHREADSYNC
endif
ifeq ($(GTKRESIZEHACK), yes)
  GLUICFLAGS+=-DUSE_GTK_RESIZE_HACK
  GLUICFLAGS+=$(GTKUICFLAGS)
  GLUILIBS+=$(GTKUILIBS)
endif

DSPSRC=jmeters/vumeterdsp.cc jmeters/iec1ppmdsp.cc \
  jmeters/iec2ppmdsp.cc jmeters/stcorrdsp.cc \
  ebumeter/ebu_r128_proc.cc \
  jmeters/truepeakdsp.cc \
  zita-resampler/resampler.cc zita-resampler/resampler-table.cc

DSPDEPS=$(DSPSRC) jmeters/jmeterdsp.h jmeters/vumeterdsp.h \
  jmeters/iec1ppmdsp.h jmeters/iec2ppmdsp.h \
  jmeters/stcorrdsp.h ebumeter/ebu_r128_proc.h \
  jmeters/truepeakdsp.h \
  zita-resampler/resampler.h zita-resampler/resampler-table.h

UITOOLKIT=$(WD)checkbutton.h $(WD)dial.h $(WD)label.h $(WD)pushbutton.h\
          $(WD)radiobutton.h $(WD)scale.h $(WD)separator.h $(WD)spinner.h

ROBGL= Makefile $(UITOOLKIT) $(RW)ui_gl.c $(PUGL_SRC) \
  $(RW)gl/common_cgl.h $(RW)gl/layout.h $(RW)gl/robwidget_gl.h $(RW)robtk.h \
	$(RT)common.h $(RT)style.h \
  $(RW)gl/xternalui.c $(RW)gl/xternalui.h

ROBGTK = Makefile $(UITOOLKIT) $(RW)ui_gtk.c \
  $(RW)gtk2/common_cgtk.h $(RW)gtk2/robwidget_gtk.h $(RW)robtk.h \
	$(RT)common.h $(RT)style.h


# build target definitions
default: all

all: $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(targets)

$(BUILDDIR)manifest.ttl: lv2ttl/manifest.gui.ttl.in lv2ttl/manifest.lv2.ttl.in lv2ttl/manifest.ttl.in Makefile
	@mkdir -p $(BUILDDIR)
	sed "s/@LV2NAME@/$(LV2NAME)/g" \
	    lv2ttl/manifest.ttl.in > $(BUILDDIR)manifest.ttl
	sed "s/@LV2NAME@/$(LV2NAME)/g;s/@LIB_EXT@/$(LIB_EXT)/g;s/@URI_SUFFIX@//g" \
	    lv2ttl/manifest.lv2.ttl.in >> $(BUILDDIR)manifest.ttl
	sed "s/@LV2NAME@/$(LV2NAME)/g;s/@LIB_EXT@/$(LIB_EXT)/g;s/@URI_SUFFIX@/_gtk/g" \
	    lv2ttl/manifest.lv2.ttl.in >> $(BUILDDIR)manifest.ttl
	sed "s/@LV2NAME@/$(LV2NAME)/g;s/@LIB_EXT@/$(LIB_EXT)/g;s/@UI_TYPE@/$(UI_TYPE)/;s/@LV2GUI1@/$(LV2GUI1)/g;s/@LV2GUI2@/$(LV2GUI2)/g;s/@LV2GUI3@/$(LV2GUI3)/g;s/@LV2GUI4@/$(LV2GUI4)/g;s/@LV2GTK1@/$(LV2GTK1)/g;s/@LV2GTK2@/$(LV2GTK2)/g;s/@LV2GTK3@/$(LV2GTK3)/g;s/@LV2GTK4@/$(LV2GTK4)/g" \
	    lv2ttl/manifest.gui.ttl.in >> $(BUILDDIR)manifest.ttl

$(BUILDDIR)$(LV2NAME).ttl: lv2ttl/$(LV2NAME).ttl.in lv2ttl/$(LV2NAME).lv2.ttl.in lv2ttl/$(LV2NAME).gui.ttl.in Makefile
	@mkdir -p $(BUILDDIR)
	sed "s/@LV2NAME@/$(LV2NAME)/g" \
	    lv2ttl/$(LV2NAME).ttl.in > $(BUILDDIR)$(LV2NAME).ttl
	sed "s/@UI_URI_SUFFIX@/_gtk/;s/@UI_TYPE@/ui:GtkUI/;s/@UI_REQ@//" \
	    lv2ttl/$(LV2NAME).gui.ttl.in >> $(BUILDDIR)$(LV2NAME).ttl
ifneq ($(BUILDOPENGL), no)
	sed "s/@UI_URI_SUFFIX@/_gl/;s/@UI_TYPE@/$(UI_TYPE)/;s/@UI_REQ@/$(LV2UIREQ)/" \
	    lv2ttl/$(LV2NAME).gui.ttl.in >> $(BUILDDIR)$(LV2NAME).ttl
endif
	sed "s/@URI_SUFFIX@//g;s/@NAME_SUFFIX@//g;s/@DPMGUI@/$(DPMGUI)_gl/g;s/@EBUGUI@/$(EBUGUI)_gl/g;s/@GONGUI@/$(GONGUI)_gl/g;s/@MTRGUI@/$(MTRGUI)_gl/g;" \
	  lv2ttl/$(LV2NAME).lv2.ttl.in >> $(BUILDDIR)$(LV2NAME).ttl
	sed "s/@URI_SUFFIX@/_gtk/g;s/@NAME_SUFFIX@/ GTK/g;s/@DPMGUI@/$(DPMGUI)_gtk/g;s/@EBUGUI@/$(EBUGUI)_gtk/g;s/@GONGUI@/$(GONGUI)_gtk/g;s/@MTRGUI@/$(MTRGUI)_gtk/g;" \
	  lv2ttl/$(LV2NAME).lv2.ttl.in >> $(BUILDDIR)$(LV2NAME).ttl

$(BUILDDIR)$(LV2NAME)$(LIB_EXT): src/meters.cc $(DSPDEPS) src/ebulv2.cc src/uris.h src/goniometerlv2.c src/goniometer.h src/spectrumlv2.c Makefile
	@mkdir -p $(BUILDDIR)
	$(CXX) $(CPPFLAGS) $(CFLAGS) $(CXXFLAGS) \
	  -o $(BUILDDIR)$(LV2NAME)$(LIB_EXT) src/$(LV2NAME).cc $(DSPSRC) \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(LOADLIBES)

$(BUILDDIR)$(LV2GTK1)$(LIB_EXT): $(ROBGTK) \
	$(UIIMGS) src/uris.h gui/needle.c gui/meterimage.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=c99  $(GTKUICFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/needle.c\"" \
	  -o $(BUILDDIR)$(LV2GTK1)$(LIB_EXT) $(RW)ui_gtk.c \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GTKUILIBS)

$(BUILDDIR)$(LV2GTK2)$(LIB_EXT): $(ROBGTK) \
	gui/ebur.c src/uris.h
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=c99 $(GTKUICFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/ebur.c\"" \
	  -o $(BUILDDIR)$(LV2GTK2)$(LIB_EXT) $(RW)ui_gtk.c \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GTKUILIBS)

$(BUILDDIR)$(LV2GTK3)$(LIB_EXT): $(ROBGTK) \
	gui/goniometerui.cc src/goniometer.h \
	zita-resampler/resampler.cc zita-resampler/resampler-table.cc \
	zita-resampler/resampler.h zita-resampler/resampler-table.h
	@mkdir -p $(BUILDDIR)
	$(CXX) $(CPPFLAGS) $(CFLAGS) $(GTKUICFLAGS) $(CXXFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/goniometerui.cc\"" \
	  -o $(BUILDDIR)$(LV2GTK3)$(LIB_EXT) $(RW)ui_gtk.c \
	  zita-resampler/resampler.cc zita-resampler/resampler-table.cc \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GTKUILIBS)

$(BUILDDIR)$(LV2GTK4)$(LIB_EXT): $(ROBGTK) \
	gui/dpm.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=c99 $(GTKUICFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/dpm.c\"" \
	  -o $(BUILDDIR)$(LV2GTK4)$(LIB_EXT) $(RW)ui_gtk.c \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GTKUILIBS)

$(BUILDDIR)$(LV2GUI2)$(LIB_EXT): $(ROBGL) \
	gui/ebur.c src/uris.h
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=c99 $(GLUICFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/ebur.c\"" \
	  `pkg-config --cflags glu` \
	  -o $(BUILDDIR)$(LV2GUI2)$(LIB_EXT) $(RW)ui_gl.c \
	  $(PUGL_SRC) \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GLUILIBS)

$(BUILDDIR)$(LV2GUI3)$(LIB_EXT):$(ROBGL) \
	gui/goniometerui.cc src/goniometer.h \
	zita-resampler/resampler.cc zita-resampler/resampler-table.cc \
	zita-resampler/resampler.h zita-resampler/resampler-table.h
	@mkdir -p $(BUILDDIR)
	$(CXX) $(CPPFLAGS) $(CFLAGS) $(GLUICFLAGS) $(CXXFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/goniometerui.cc\"" \
	  `pkg-config --cflags glu` \
	  -o $(BUILDDIR)$(LV2GUI3)$(LIB_EXT) $(RW)ui_gl.c \
	  $(PUGL_SRC) \
	  zita-resampler/resampler.cc zita-resampler/resampler-table.cc \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GLUILIBS)

$(BUILDDIR)$(LV2GUI4)$(LIB_EXT): $(ROBGL) \
	gui/dpm.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=c99 $(GLUICFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/dpm.c\"" \
	  `pkg-config --cflags glu` \
	  -o $(BUILDDIR)$(LV2GUI4)$(LIB_EXT) $(RW)ui_gl.c \
	  $(PUGL_SRC) \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GLUILIBS)

$(BUILDDIR)$(LV2GUI1)$(LIB_EXT): $(ROBGL) \
	src/uris.h gui/needle.c gui/meterimage.c
	@mkdir -p $(BUILDDIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=gnu99 $(GLUICFLAGS) \
	  -DPLUGIN_SOURCE="\"gui/needle.c\"" \
	  `pkg-config --cflags glu` \
	  -o $(BUILDDIR)$(LV2GUI1)$(LIB_EXT) $(RW)ui_gl.c \
	  $(PUGL_SRC) \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(GLUILIBS)

# install/uninstall/clean target definitions

install: all
	install -d $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m755 $(targets) $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m644 $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(DESTDIR)$(LV2DIR)/$(BUNDLE)

uninstall:
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/manifest.ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME).ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GUI1)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GUI2)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GUI3)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GUI4)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GTK1)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GTK2)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GTK3)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GTK4)$(LIB_EXT)
	-rmdir $(DESTDIR)$(LV2DIR)/$(BUNDLE)

clean:
	rm -f $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl \
	  $(BUILDDIR)$(LV2NAME)$(LIB_EXT) \
	  $(BUILDDIR)$(LV2GUI1)$(LIB_EXT) $(BUILDDIR)$(LV2GUI2)$(LIB_EXT) \
	  $(BUILDDIR)$(LV2GUI3)$(LIB_EXT) $(BUILDDIR)$(LV2GUI4)$(LIB_EXT) \
	  $(BUILDDIR)$(LV2GTK1)$(LIB_EXT) $(BUILDDIR)$(LV2GTK2)$(LIB_EXT) \
	  $(BUILDDIR)$(LV2GTK3)$(LIB_EXT) $(BUILDDIR)$(LV2GTK4)$(LIB_EXT)
	-test -d $(BUILDDIR) && rmdir $(BUILDDIR) || true

distclean: clean
	rm -f cscope.out cscope.files tags

.PHONY: clean all install uninstall distclean
