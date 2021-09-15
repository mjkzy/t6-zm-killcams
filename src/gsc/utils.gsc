/*

    utils (hud stuff & more)

*/

// birchy utils
drawtext2(text, align, relative, x, y, fontscale, font, color, alpha, sort)
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

shader(align, relative, x, y, shader, width, height, color, alpha, sort)
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

// CMT frosty utils
drawText(text, font, fontScale, x, y, color, alpha, sort)
{
    hud = self createFontString(font, fontScale);
    hud setText(text);
    hud.x = x;
    hud.y = y;
    hud.color = color;
    hud.alpha = alpha;
    hud.sort = sort;
    hud.alpha = alpha;
    return hud;
    level.result += 1;
    textElem setText(text);
    level notify("textset");
}

drawValue(value, font, fontScale, align, relative, x, y, color, alpha, sort)
{
    hud = self createFontString(font, fontScale);
    level.varsArray["result"] += 1;
    level notify("textset");
    hud setPoint( align, relative, x, y );
    hud.color = color;
    hud.alpha = alpha;
    hud.sort = sort;
    hud.alpha = alpha;
    hud setValue(value);
    hud.foreground = true;
    hud.hideWhenInMenu = true;
    return hud;
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
