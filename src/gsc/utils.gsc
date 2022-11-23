/*

    utils (hud stuff & more)

*/

get_number_of_zombies()
{
    return (maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total);
}

// birchy utils
draw_text_2(text, align, relative, x, y, fontscale, font, color, alpha, sort)
{
    //element = self createfontstring(font, fontscale);
    element = self createfontstring(font, fontscale);
    element setpoint(align, relative, x, y);
    element settext(text);
    element.hidewheninmenu = false;
    element.color = color;
    element.alpha = alpha;
    element.sort = sort;
    return element;
}

draw_shader(align, relative, x, y, shader, width, height, color, alpha, sort)
{
    element = newclienthudelem(self);
    element.elemtype = "bar";
    element.hidewheninmenu = false;
    element.shader = shader;
    element.width = width;
    element.height = height;
    element.align = align;
    element.relative = relative;
    element.xoffset = 0;
    element.yoffset = 0;
    element.children = [];
    element.sort = sort;
    element.color = color;
    element.alpha = alpha;
    element setparent(level.uiparent);
    element setshader(shader, width, height);
    element setpoint(align, relative, x, y);
    return element;
}

drawShader(shader, x, y, width, height, color, alpha, sort)
{
    hud = newClientHudElem(self);
    hud.elemtype = "icon";
    hud.color = color;
    hud.alpha = alpha;
    hud.sort = sort;
    hud.children = [];
    hud setParent(level.uiParent);
    hud setShader(shader, width, height);
    hud.x = x;
    hud.y = y;
    return hud;
}

draw_text(text, font, fontScale, x, y, color, alpha, glowColor, glowAlpha, sort)
{
    hud = self createFontString(font, fontScale);
    hud.x = x;
    hud.y = y;
    hud.color = color;
    hud.alpha = alpha;
    hud.glowColor = glowColor;
    hud.glowAlpha = glowAlpha;
    hud.sort = sort;
    hud.alpha = alpha;
    hud set_safe_text(self, text);
    return hud;
}

draw_value(value, font, fontScale, align, relative, x, y, color, alpha, glowColor, glowAlpha, sort)
{
    hud = self createFontString(font, fontScale);

    hud setpoint(align, relative, x, y);
    hud.color = color;
    hud.alpha = alpha;
    hud.glowColor = glowColor;
    hud.glowAlpha = glowAlpha;
    hud.sort = sort;
    hud.alpha = alpha;
    hud setvalue(value);
    return hud;
}

/*
    overflow fix
*/

overflow_fix()
{
    self.stringTable = [];
    self.stringTableEntryCount = 0;
    self.textTable = [];
    self.textTableEntryCount = 0;
    if (!isdefined(level.anchorText))
    {
        level.anchorText = createServerFontString("default", 1.5);
        level.anchorText setText("anchor");
        level.anchorText.alpha = 0;
        level.stringCount = 0;
        level thread overflow_monitor();
    }
}

overflow_monitor()
{
    level endon("disconnect");
    level endon("game_ended");
    for(;;)
    {
        wait 0.05;

        if (level.stringCount >= 50)
        {
            level.anchorText clearAllTextAfterHudElem();
            level.stringCount = 0;

            players = getplayers();
            foreach(player in players)
            {
                if (!isdefined(player))
                    continue;

                player purge_text_table();
                player purge_string_table();
                player recreate_text();
            }
        }
    }
}

set_safe_text(player, text)
{
    stringId = player get_string_id(text);
    if (stringId == -1)
    {
        player add_string_table_entry(text);
        stringId = player get_string_id(text);
    }
    player edit_text_table_entry(self.textTableIndex, stringId);
    self setText(text);
}

recreate_text()
{
    foreach(entry in self.textTable)
        entry.element set_safe_text(self, lookup_string_by_id(entry.stringId));
}

add_string_table_entry(string)
{
    entry = spawnStruct();
    entry.id = self.stringTableEntryCount;
    entry.string = string;
    self.stringTable[self.stringTable.size] = entry;
    self.stringTableEntryCount++;
    level.stringCount++;
}

lookup_string_by_id(id)
{
    string = "";
    foreach(entry in self.stringTable)
    {
        if (entry.id == id)
        {
            string = entry.string;
            break;
        }
    }
    return string;
}

get_string_id(string)
{
    id = -1;
    foreach(entry in self.stringTable)
    {
        if (entry.string == string)
        {
            id = entry.id;
            break;
        }
    }
    return id;
}

get_string_table_entry(id)
{
    stringTableEntry = -1;
    foreach(entry in self.stringTable)
    {
        if (entry.id == id)
        {
            stringTableEntry = entry;
            break;
        }
    }
    return stringTableEntry;
}

purge_string_table()
{
    stringTable = [];
    foreach(entry in self.textTable)
    {
        stringTable[stringTable.size] = get_string_table_entry(entry.stringId);
    }
    self.stringTable = stringTable;
}

purge_text_table()
{
    textTable = [];
    foreach(entry in self.textTable)
    {
        if (entry.id != -1)
        {
            textTable[textTable.size] = entry;
        }
    }
    self.textTable = textTable;
}

edit_text_table_entry(id, stringId)
{
    foreach(entry in self.textTable)
    {
        if (entry.id == id)
        {
            entry.stringId = stringId;
            break;
        }
    }
}

delete_text_table_entry(id)
{
    foreach(entry in self.textTable)
    {
        if (entry.id == id)
        {
            entry.id = -1;
            entry.stringId = -1;
        }
    }
}

clear(player)
{
    if (self.type == "text")
        player delete_text_table_entry(self.textTableIndex);

    if (isdefined(self))
        self destroy();
}
