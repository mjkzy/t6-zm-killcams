main()
{
    replacefunc(maps/mp/zombies/_zm_utility::has_player_equipment, ::has_player_equipment_hook);

    // trample steam
    replacefunc(maps/mp/zombies/_zm_equip_springpad::pickupspringpad, ::pickupspringpad_hook);
    replacefunc(maps/mp/zombies/_zm_equip_springpad::watchspringpaduse, ::watchspringpaduse_hook);
}

has_player_equipment_hook(weaponname)
{
    return 0; // allow unlimited player equipment
}

watchspringpaduse_hook()
{
	self notify("watchSpringPadUse");
	self endon("watchSpringPadUse");
	self endon("death");
	self endon("disconnect");
	for(;;)
	{
		self waittill("equipment_placed", weapon, weapname);
		if (weapname == level.springpad_name)
		{
            if (isdefined(self.springpad_picked_up) && self.springpad_picked_up)
            {
                self.springpad_picked_up = false;
                self maps/mp/zombies/_zm_equip_springpad::cleanupoldspringpad();
            }
			self.buildablespringpad = weapon;
			self thread maps/mp/zombies/_zm_equip_springpad::startspringpaddeploy(weapon);
		}
	}
}

pickupspringpad_hook(item)
{
    self.springpad_kills = item.springpad_kills;
    item.springpad_kills =  undefined;
    self.springpad_picked_up = true;
}
