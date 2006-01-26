# $Id$

# strobes ===========================================================
strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/f16/lighting/strobe", 0.03, 2.013, strobe_switch);
