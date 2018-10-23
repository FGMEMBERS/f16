#a better fire-control system:
var VectorNotification = {
    new: func(type) {
        var new_class = emesary.Notification.new(type, rand());
        new_class.updateV = func (vector) {
	    	me.vector = vector;
	    	return me;
	    };
        return new_class;
    },
};
var FireControl = {
	new: func (pylons, pylonOrder, typeOrder) {
		var fc = {parents:[FireControl]};
		fc.pylons = pylons;
		foreach(pyl;pylons) {
			pyl.setPylonListener(fc);
		}
		fc.selected = nil;
		fc.pylonOrder=pylonOrder;
		fc.typeOrder=typeOrder;
		fc.selectedType = nil;
		fc.triggerTime = 0;
		fc.gunTriggerTime = 0;
		fc.WeaponNotification = VectorNotification.new("WeaponNotification");
		fc.setupMFDObservers();
		setlistener("controls/armament/trigger",func{fc.trigger();fc.updateCurrent()});
		setlistener("controls/armament/master-arm",func{fc.updateCurrent()});
		return fc;
	},

	getCategory: func {
		me.cat = 1;
		foreach (pyl;me.pylons) {
			if (pyl.getCategory()>me.cat) {
				me.cat = pyl.getCategory();
			}
		}
		return me.cat;
	},

	setupMFDObservers: func {
		me.FireControlRecipient = emesary.Recipient.new("FireControlRecipient");
		me.FireControlRecipient.Receive = func(notification) {
	        if (notification.NotificationType == "WeaponRequestNotification") {
	        	#printfDebug("FireControlRecipient recv: %s", notification.NotificationType);
	        	if (me.selected != nil) {
					me.WeaponNotification.updateV(me.pylons[me.selected[0]].getWeapons()[me.selected[1]]);
					emesary.GlobalTransmitter.NotifyAll(me.WeaponNotification);
				}
	            return emesary.Transmitter.ReceiptStatus_OK;
	        } elsif (notification.NotificationType == "WeaponCommandNotification") {
	        	#printfDebug("FireControlRecipient recv: %s", notification.NotificationType);
	            if (notification.cooling == 1) {
	    		    #toggle all heatseekers to cool
	    	    }
	    	    if (notification.bore == 1) {
	    		    #toggle all heatseekers to bore
	    	    }
	    	    if (notification.slave == 1) {
	    		    #toggle all heatseekers to slave
	    	    }
	    	    # etc etc
	            return emesary.Transmitter.ReceiptStatus_OK;
	        } elsif (notification.NotificationType == "CycleWeaponNotification") {
	        	#printfDebug("FireControlRecipient recv: %s", notification.NotificationType);
	        	me.cycleWeapon();
	            return emesary.Transmitter.ReceiptStatus_OK;
	        }
	        return emesary.Transmitter.ReceiptStatus_NotProcessed;
	    };
		emesary.GlobalTransmitter.Register(me.FireControlRecipient);
	},

	cycleWeapon: func {
		# it will cycle to next weapon type, even if that one is empty.
		me.triggerTime = 0;
		me.stopCurrent();
		me.selWeapType = me.selectedType;
		if (me.selWeapType == nil) {
			me.selectedType = me.typeOrder[0];
			if (me.nextWeapon(me.typeOrder[0]) != nil) {
				printfDebug("FC: Selected first weapon: %s on pylon %d position %d",me.selectedType,me.selected[0],me.selected[1]);
			} else {
				printfDebug("FC: Selected first weapon: %s, but none is loaded.", me.selectedType);
			}
		} else {
			me.selType = me.selectedType;
			printfDebug("Already selected %s",me.selType);
			me.selTypeIndex = me.vectorIndex(me.typeOrder, me.selType);
			me.selTypeIndex += 1;
			if (me.selTypeIndex >= size(me.typeOrder)) {
				me.selTypeIndex = 0;
			}
			me.selectedType = me.typeOrder[me.selTypeIndex];
			me.selType = me.selectedType;
			printfDebug(" Now selecting %s",me.selType);
			me.wp = me.nextWeapon(me.selType);
			if (me.wp != nil) {			
				printfDebug("FC: Selected next weapon type: %s on pylon %d position %d",me.selectedType,me.selected[0],me.selected[1]);
			} else {
				printfDebug("FC: Selected next weapon type: %s, but none is loaded.", me.selectedType);
			}
		}
		screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
	},

	cycleLoadedWeapon: func {
		# it will cycle to next weapon type that is not empty.
		me.triggerTime = 0;
		me.stopCurrent();
		me.selWeapType = me.selectedType;
		if (me.selWeapType == nil) {
			me.selTypeIndex = -1;
			me.cont = size(me.typeOrder);
		} else {
			me.selType = me.selectedType;
			printfDebug("Already selected %s",me.selType);
			me.selTypeIndex = me.vectorIndex(me.typeOrder, me.selType);
			me.cont = me.selTypeIndex;
		}
		me.selTypeIndex += 1;
		while (me.selTypeIndex != me.cont) {
			if (me.selTypeIndex >= size(me.typeOrder)) {
				me.selTypeIndex = 0;
			}
			me.selectedType = me.typeOrder[me.selTypeIndex];
			me.selType = me.selectedType;
			printfDebug(" Now selecting %s",me.selType);
			me.wp = me.nextWeapon(me.selType);
			if (me.wp != nil) {			
				printfDebug("FC: Selected next weapon type: %s on pylon %d position %d",me.selectedType,me.selected[0],me.selected[1]);
				screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
				return;
			}
			me.selTypeIndex += 1;
		}		
		me.selected = nil;
		me.selectedType = nil;
		screen.log.write("Selected nothing", 0.5, 0.5, 1);
	},

	_isSelectedWeapon: func {
		# tests if current selection is a fireable weapon
		if (me.selectedType != nil) {
			if (find(" ", me.selectedType) != -1) {
				return 0;
			}
			me.first = left(me.selectedType,1);
			if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
				return 0;
			}
			if (getprop("payload/armament/"~string.lc(me.selectedType)~"/class") != nil) {
				return 1;
			}
		}
		return 0;
	},

	cycleAG: func {
		# will stop current weapon and select next A-A weapon and start it.
		# horrible programming though, but since its called seldom and in no loop, it will do for now.
		me.stopCurrent();
		if (!me._isSelectedWeapon()) {
			me.selected = nil;
			me.selectedType = nil;
		}
		if (me.selectedType == nil) {
			foreach (me.typeTest;me.typeOrder) {
				me.first = left(me.typeTest,1);
				if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
					continue;
				}
				me.class = getprop("payload/armament/"~string.lc(me.typeTest)~"/class");
				if (me.class != nil) {
					me.isAG = find("G", me.class)!=-1 or find("M", me.class)!=-1;
					if (me.isAG) {
						me.selType = me.nextWeapon(me.typeTest);
						if (me.selType != nil) {
							#me.updateCurrent();
							me.selectedType = me.selType.type;
							screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
							return;
						}
					}
				}
			}
		} else {
			me.hasSeen = 0;
			foreach (me.typeTest;me.typeOrder) {
				me.first = left(me.typeTest,1);
				if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
					continue;
				}
				if (!me.hasSeen) {
					if (me.typeTest == me.selectedType) {
						me.hasSeen = 1;
					} 
					continue;
				}
				me.class = getprop("payload/armament/"~string.lc(me.typeTest)~"/class");
				if (me.class != nil) {
					me.isAG = find("G", me.class)!=-1 or find("M", me.class)!=-1;
					if (me.isAG) {
						me.selType = me.nextWeapon(me.typeTest);
						if (me.selType != nil) {
							#me.updateCurrent();
							me.selectedType = me.selType.type;
							screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
							return;
						}
					}
				}
			}
			if (me.hasSeen) {
				foreach (me.typeTest;me.typeOrder) {
					me.first = left(me.typeTest,1);
					if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
						continue;
					}
					if (me.typeTest == me.selectedType) {
						me.selType = me.nextWeapon(me.typeTest);
						if (me.selType != nil and me.selType.parents[0] == armament.AIM and (me.selType.target_gnd == 1 or me.selType.target_sea==1)) {
							#me.updateCurrent();
							me.selectedType = me.selType.type;
							screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
							return;
						} else {
							me.selectedType = nil;
							me.selected = nil;
							screen.log.write("Selected nothing", 0.5, 0.5, 1);
						}
						return;
					}
					me.class = getprop("payload/armament/"~string.lc(me.typeTest)~"/class");
					if (me.class != nil) {
						me.isAG = find("G", me.class)!=-1 or find("M", me.class)!=-1;
						if (me.isAG) {
							me.selType = me.nextWeapon(me.typeTest);
							if (me.selType != nil) {
								me.selectedType = me.selType.type;
								#me.updateCurrent();
								screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
								return;
							}
						}
					}
				}
			}
		}
		if (me.selectedType != nil) {
			screen.log.write("Deselected "~me.selectedType, 0.5, 0.5, 1);
		} else {
			screen.log.write("Selected nothing", 0.5, 0.5, 1);
		}
		me.selectedType = nil;
		me.selected = nil;
		me.updateCurrent();
	},

	cycleAA: func {
		# will stop current weapon and select next A-A weapon and start it.
		me.stopCurrent();
		if (!me._isSelectedWeapon()) {
			me.selected = nil;
			me.selectedType = nil;
		}
		if (me.selectedType == nil) {
			foreach (me.typeTest;me.typeOrder) {
				me.first = left(me.typeTest,1);
				if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
					continue;
				}
				me.class = getprop("payload/armament/"~string.lc(me.typeTest)~"/class");
				if (me.class != nil) {
					me.isAG = find("A", me.class)!=-1;
					if (me.isAG) {
						me.selType = me.nextWeapon(me.typeTest);
						if (me.selType != nil) {
							me.selectedType = me.selType.type;
							#me.updateCurrent();
							screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
							return;
						}
					}
				}
			}
		} else {
			me.hasSeen = 0;
			foreach (me.typeTest;me.typeOrder) {
				me.first = left(me.typeTest,1);
				if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
					continue;
				}
				if (!me.hasSeen) {
					if (me.typeTest == me.selectedType) {
						me.hasSeen = 1;
					} 
					continue;
				}
				me.class = getprop("payload/armament/"~string.lc(me.typeTest)~"/class");
				if (me.class != nil) {
					me.isAG = find("A", me.class)!=-1;
					if (me.isAG) {
						me.selType = me.nextWeapon(me.typeTest);
						if (me.selType != nil) {
							me.selectedType = me.selType.type;
							#me.updateCurrent();
							screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
							return;
						}
					}
				}
			}
			if (me.hasSeen) {
				foreach (me.typeTest;me.typeOrder) {
					me.first = left(me.typeTest,1);
					if (me.first == "0" or me.first == "1" or me.first == "2" or me.first == "3" or me.first == "4" or me.first == "5" or me.first == "6" or me.first == "7" or me.first == "8" or me.first == "9") {
						continue;
					}
					if (me.typeTest == me.selectedType) {
						me.selType = me.nextWeapon(me.typeTest);
						if (me.selType != nil and me.selType.parents[0] == armament.AIM and me.selType.target_air==1) {
							#me.updateCurrent();
							me.selectedType = me.selType.type;
							screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
							return;
						} else {
							me.selectedType = nil;
							me.selected = nil;
							screen.log.write("Selected nothing", 0.5, 0.5, 1);
						}
						return;
					}
					me.class = getprop("payload/armament/"~string.lc(me.typeTest)~"/class");
					if (me.class != nil) {
						me.isAG = find("A", me.class)!=-1;
						if (me.isAG) {
							me.selType = me.nextWeapon(me.typeTest);
							if (me.selType != nil) {
								me.selectedType = me.selType.type;
								#me.updateCurrent();
								screen.log.write("Selected "~me.selectedType, 0.5, 0.5, 1);
								return;
							}
						}
					}
				}
			}
		}
		if (me.selectedType != nil) {
			screen.log.write("Deselected "~me.selectedType, 0.5, 0.5, 1);
		} else {
			screen.log.write("Selected nothing", 0.5, 0.5, 1);
		}
		me.selectedType = nil;
		me.selected = nil;
	},

	updateAll: func {
		# called from the stations when they change.
		if (me.selectedType != nil) {
			screen.log.write("Fire-control: deselecting "~me.selectedType, 0.5, 0.5, 1);
			me.selectedType = nil;
			me.selected = nil;
		}
	},

	getSelectedWeapon: func {
		# return selected weapon or nil
		if (me.selected == nil) {
			return nil;
		}
		if (me.selected[1] > size(me.pylons[me.selected[0]].getWeapons())-1) {
			return nil;
		}
		return me.pylons[me.selected[0]].getWeapons()[me.selected[1]];
	},

	getSelectedPylon: func {
		# return selected pylon or nil
		if (me.selected == nil) {
			return nil;
		}
		return me.pylons[me.selected[0]];
	},

	isLock: func {
		# returns if current weapon has lock
		me.wpn = me.getSelectedWeapon();
		if (me.wpn != nil and me.wpn.parents[0] == armament.AIM and me.wpn.status==armament.MISSILE_LOCK) {
			return 1;
		}
		return 0;
	},

	jettisonSelectedPylonContent: func {
		# jettison selected pylon
		if (me.selected == nil) {
			printDebug("Nothing to jettison");
			return nil;
		}
		me.pylons[me.selected[0]].jettisonAll();
		me.selected = nil;
		if (me.selectedType != nil) {
			me.nextWeapon(me.selectedType);
		}
	},

	jettisonAll: func {
		# jettison all stations
		foreach (pyl;me.pylons) {
			pyl.jettisonAll();
		}
	},

	jettisonFuelAndAG: func (exclude = nil) {
		# jettison all fuel and A/G stations.
		foreach (pyl;me.pylons) {
			me.myWeaps = pyl.getWeapons();
			if (me.myWeaps != nil and size(me.myWeaps)>0) {
				if (me.myWeaps[0] != nil and me.myWeaps[0].parents[0] == armament.AIM and me.myWeaps[0].target_air == 1) {
					continue;
				}
			}
			if (exclude!=nil and me.vectorIndex(exclude, pyl.id) != -1) {
				# excluded
				continue;
			}
			pyl.jettisonAll();
		}
	},

	jettisonFuel: func {
		# jettison all fuel stations
		foreach (pyl;me.pylons) {
			me.myWeaps = pyl.getWeapons();
			if (me.myWeaps != nil and size(me.myWeaps)>0) {
				if (me.myWeaps[0] != nil and me.myWeaps[0].parents[0] == armament.AIM) {
					continue;
				}
			}
			pyl.jettisonAll();
		}
	},

	getSelectedPylonNumber: func {
		# return selected pylon index or nil
		if (me.selected == nil) {
			return nil;
		}
		return me.selected[0];
	},

	selectPylon: func (p, w=nil) {
		# select a specified pylon
		# will stop previous weapon, will start next.
		me.triggerTime = 0;
		if (size(me.pylons) > p) {
			me.ws = me.pylons[p].getWeapons();
			if (me.ws != nil and w != nil and size(me.ws) > w and me.ws[w] != nil) {
				me.stopCurrent();
				me.selected = [p, w];
				me.selectedType = me.ws[w].type;
				me.updateCurrent();
				return;
			} elsif (me.ws != nil and w == nil and size(me.ws) > 0) {
				w = 0;
				foreach(me.wp;me.ws) {
					if (me.wp != nil) {
						me.stopCurrent();
						me.selected = [p, w];
						me.selectedType = me.ws[w].type;
						me.updateCurrent();
						return;
					}
					w+=1;
				}
			}
		}
		printDebug("manually select pylon failed");
	},

	trigger: func {
		# trigger pressed down should go here, this will fire weapon
		# cannon is fired in another way, but this method will print the brevity.
		printfDebug("trigger called %d %d %d",getprop("controls/armament/master-arm"),getprop("controls/armament/trigger"),me.selected != nil);
		if (getprop("controls/armament/master-arm") == 1 and getprop("controls/armament/trigger") > 0 and me.selected != nil) {
			printDebug("trigger propagating");
			me.aim = me.getSelectedWeapon();
			#printfDebug(" to %d",me.aim != nil);
			if (me.aim != nil and me.aim.parents[0] == armament.AIM and me.aim.status == armament.MISSILE_LOCK) {
				me.aim = me.pylons[me.selected[0]].fireWeapon(me.selected[1], getCompleteRadarTargetsList());
				if (me.aim != nil) {
					me.aim.sendMessage(me.aim.brevity~" at: "~me.aim.callsign);
					me.aimNext = me.nextWeapon(me.selectedType);
					if (me.aimNext != nil) {
						me.aimNext.start();
					}
				}
				me.triggerTime = 0;
			} elsif (me.aim != nil and me.aim.parents[0] == armament.AIM and me.aim.guidance=="unguided") {
				me.aim = me.pylons[me.selected[0]].fireWeapon(me.selected[1], getCompleteRadarTargetsList());
				if (me.aim != nil) {
					me.aim.sendMessage(me.aim.brevity);
					me.aimNext = me.nextWeapon(me.selectedType);
					if (me.aimNext != nil) {
						me.aimNext.start();
					}
				}
				me.triggerTime = 0;
			} elsif (me.aim != nil and me.aim.parents[0] == armament.AIM and me.aim.loal) {
				me.triggerTime = getprop("sim/time/elapsed-sec");
				settimer(func me.triggerHold(me.aim), 1.5);
			} elsif (me.aim != nil and me.aim.parents[0] == stations.SubModelWeapon and (me.aim.operableFunction == nil or me.aim.operableFunction()) and me.aim.getAmmo()>0) {
				if (getprop("sim/time/elapsed-sec")>me.gunTriggerTime+10) {
					# only say guns guns every 10 seconds.
					armament.AIM.sendMessage("Guns guns");
					me.gunTriggerTime = getprop("sim/time/elapsed-sec");
				}
				me.triggerTime = 0;
			}
		} elsif (getprop("controls/armament/trigger") < 1) {
			me.triggerTime = 0;
		}
	},

	triggerHold: func (aimer) {
		if (me.triggerTime == 0 or me.getSelectedWeapon() == nil or me.getSelectedWeapon().parents[0] != armament.AIM) {
			return;
		}
		aimer = me.pylons[me.selected[0]].fireWeapon(me.selected[1], getCompleteRadarTargetsList());
		aimer.sendMessage(aimer.brevity~" Maddog released");
		me.aimNext = me.nextWeapon(me.selectedType);
		if (me.aimNext != nil) {
			me.aimNext.start();
		}
		return;
	},

	updateCurrent: func {
		# will start/stop current weapon depending on masterarm
		# will also update mass (for cannon mainly)
		if (getprop("controls/armament/master-arm")==1 and me.selected != nil) {
			me.getSelectedWeapon().start();
		} elsif (getprop("controls/armament/master-arm")==0 and me.selected != nil) {
			me.getSelectedWeapon().stop();
		}
		if (me.selected == nil) {
			return;
		}
		printDebug("FC: Masterarm "~getprop("controls/armament/master-arm"));
		
		me.pylons[me.selected[0]].calculateMass();#kind of a hack to get cannon ammo changed.
	},

	nextWeapon: func (type) {
		# find next weapon of type. Will select and start it.
		# will NOT stop previous weapon
		# will NOT set selectedType
		if (me.selected == nil) {
			me.pylon = me.pylonOrder[size(me.pylonOrder)-1];
		} else {
			me.pylon = me.selected[0];
		}
		printDebug("");
		printfDebug("Start find next weapon of type %s, starting from pylon %d", type, me.pylon);
		me.indexWeapon = -1;
		me.index = me.vectorIndex(me.pylonOrder, me.pylon);
		for(me.i=0;me.i<size(me.pylonOrder);me.i+=1) {
			#printDebug("me.i="~me.i);
			me.index += 1;
			if (me.index >= size(me.pylonOrder)) {
				me.index = 0;
			}
			me.pylon = me.pylonOrder[me.index];
			printfDebug(" Testing pylon %d", me.pylon);
			me.indexWeapon = me._getNextWeapon(me.pylons[me.pylon], type, nil);
			if (me.indexWeapon != -1) {
				me.selected = [me.pylon, me.indexWeapon];
				printDebug(" Next weapon found");
				me.updateCurrent();#TODO: think a bit more about this
				me.wap = me.pylons[me.pylon].getWeapons()[me.indexWeapon];
				#me.selectedType = me.wap.type;
				return me.wap;
			}
		}
		printDebug(" Next weapon not found");
		me.selected = nil;
		#me.selectedType = nil;
		return nil;
	},

	_getNextWeapon: func (pylon, type, current) {
		# get next weapon on a specific pylon.
		# will return the index of the weapon inside pylon.
		# returns -1 when not found
		if (pylon.currentSet != nil and pylon.currentSet["fireOrder"] != nil and size(pylon.currentSet.fireOrder) > 0) {
			printDebug("  getting next weapon");
			if (current == nil) {
				current = pylon.currentSet.fireOrder[size(pylon.currentSet.fireOrder)-1];
			}
			me.fireIndex = me.vectorIndex(pylon.currentSet.fireOrder, current);
			for(me.j=0;me.j<size(pylon.currentSet.fireOrder);me.j+=1) {
				#printDebug("me.j="~me.j);
				me.fireIndex += 1;
				if (me.fireIndex >= size(pylon.currentSet.fireOrder)) {
					me.fireIndex = 0;
				}
				if (pylon.getWeapons()[pylon.currentSet.fireOrder[me.fireIndex]] != nil) {
					if (pylon.getWeapons()[pylon.currentSet.fireOrder[me.fireIndex]].type == type) {
						return pylon.currentSet.fireOrder[me.fireIndex];
					}
				}
			}
		}
		#printfDebug("  %d %d %d",pylon.currentSet != nil,pylon.currentSet["fireOrder"] != nil,size(pylon.currentSet.fireOrder) > 0);
		return -1;
	},

	getAmmo: func {
		# return ammo count of currently selected type
		me.count = 0;
		foreach (p;me.pylons) {
			me.count += p.getAmmo(me.selectedType);
		}
		return me.count;
	},

	vectorIndex: func (vec, item) {
		# returns index of item in vector, -1 if nothing.
		me.m = 0;
		foreach(test; vec) {
			if (test == item) {
				return me.m;
			}
			me.m += 1;
		}
		return -1;
	},

	stopCurrent: func {
		# stops current weapon, but does not deselect it.
		me.selWeap = me.getSelectedWeapon();
		if (me.selWeap != nil) {
			me.selWeap.stop();
		}
	},

	noWeapon: func {
		# deselects
		me.stopCurrent();
		me.selected = nil;
		me.selectedType = nil;
		printDebug("FC: nothing selected");
	},
};

var debug = 0;
var printDebug = func (msg) {if (debug == 1) print(msg);};
var printfDebug = func {if (debug == 1) call(printf,arg);};


# This is non-generic methods, please edit it to fit your radar setup:
var getCompleteRadarTargetsList = func {
	# A list of all MP/AI aircraft/ships/surface-targets around the aircraft.
	return awg_9.completeList;
}