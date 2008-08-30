# $Id$

# strobes ===========================================================
var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);

# open canopy when engaging the parking brakes ======================
var parkingNode = props.globals.getNode("/controls/gear/brake-parking");
var wowNode = props.globals.getNode("/gear/gear/wow");
var canopy = aircraft.door.new("sim/model/f16/canopy", 10);

setlistener(parkingNode, func {
   var is_parked = func { parkingNode.getValue() and wowNode.getValue() };
   if (is_parked()) {
      var delay = 10 + 10*rand();
      settimer( func { if (is_parked()) { canopy.open() }}, delay );
   } else {
      canopy.close();
   }
}, 1);

# lower or extract arrester hook ====================================
var hook = aircraft.door.new("sim/model/f16/arrester-hook", 2.5);
var hookNode = props.globals.getNode("sim/model/f16/arrester-hook/engaged");
var testHook = func {
   if (hookNode.getValue()) {
      hook.close();
   } else {
      hook.open();
   }
   hookNode.setValue(!hookNode.getValue());
}

setlistener("/sim/current-view/view-number", func(n) {
    setprop("/sim/hud/visibility[1]", !n.getValue());
}, 1);
