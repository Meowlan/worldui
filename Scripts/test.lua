Test = class()

function Test:client_onCreate()
    self.chars = "☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~⌂ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■"
    self.charmap = {}
    self.icharmap = {}

    self.count = 0
    for uchar in string.gmatch(self.chars, "([%z\1-\127\194-\244][\128-\191]*)") do
        self.charmap[uchar] = self.count
        self.icharmap[self.count] =  uchar
        self.count = self.count + 1
    end

    self.index = self.charmap["S"]
    self.interactable:setUvFrameIndex(self.index)

    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)

    local ratio = 0.5352112676056338

    self.effect:setOffsetPosition(sm.vec3.new(0, 0.25 + (0.5352112676056338 / 4), 0))
    self.effect:setScale(sm.vec3.one()*0.25)
    self.effect:setParameter("uuid", sm.uuid.new("dc1aba75-5cc9-4c8e-b80d-387046abb3c8"))
    self.effect:start()
end

function Test:client_onRefresh()
    self:client_onCreate()
end