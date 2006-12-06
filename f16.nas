# $Id$

# strobes ===========================================================
strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);

# open canopy when engaging the parking brakes ======================
parkingNode = props.globals.getNode("/controls/gear/brake-parking");
wowNode = props.globals.getNode("/gear/gear/wow");
canopy = aircraft.door.new("sim/model/f16/canopy", 5);

setlistener(parkingNode, func {
   is_parked = func { parkingNode.getValue() and wowNode.getValue() };
   if (is_parked()) {
      delay = 10 + 10*rand();
      settimer( func { if (is_parked()) { canopy.open() }}, delay );
   } else {
      canopy.close();
   }
}, 1);

# lower or extract arrester hook ====================================
hook = aircraft.door.new("sim/model/f16/arrester-hook", 2.5);
hookNode = props.globals.getNode("sim/model/f16/arrester-hook/engaged");
testHook = func {
   if (hookNode.getValue()) {
      hook.close();
   } else {
      hook.open();
   }
   hookNode.setValue(!hookNode.getValue());
}
