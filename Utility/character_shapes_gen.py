from PIL import Image, ImageDraw, ImageFont
import uuid
import json
import copy

chars = u"☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~⌂ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▉▊▋▍▎▏▌▄▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■"

font = ImageFont.truetype("SourceCodePro-Regular.ttf", 250)

maxwidth, maxheight = 0, 0
for char in chars:
    _, _, w, h = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox((0, 0), char, font=font)
    maxwidth = max(maxwidth, w)
    maxheight = max(maxheight, h)
    
namespace = uuid.UUID("cae5bfe0-5385-41f7-bbc7-3ff135f8226f")

csv_string = ""

shapeset = json.loads("""
    {
        "partList": [
            
        ]
    }                      
""")

dummyshape = json.loads("""
    {
        "physicsMaterial": "Default",
        "box" : {
            "x" : 1,
            "y" : 1,
            "z" : 1
        },
        "renderable": {
            "lodList": [
                {
                    "mesh": "$CONTENT_DATA/Objects/Mesh/char_solo.fbx",
                    "subMeshList": [
                        {
                            "material": "DifAsgAlpha",
                            "textureList": [
                                "$CONTENT_DATA/Objects/Textures/empty_dif.png",
                                ""
                            ]
                        }
                    ]
                }
            ]
        },
        "rotationSet" : "PropZ",
        "showInInventory" : false,
        "uuid": ""
    }
""")

i = 0
uuids_lua = ""
for char in chars:
    uv_map = Image.new("RGBA", (maxwidth, maxheight))
    draw = ImageDraw.Draw(uv_map)
        
    draw.text((0, 0), char, fill="#ff00a0ff", font=font)
    sexyuuid = uuid.uuid5(namespace, char)
    csv_string = csv_string + f"{sexyuuid}, {char}\n"
    uuids_lua = uuids_lua + f"[\"{sexyuuid}\"] = \"{char}\",\n"
    i = i + 1
    uv_map.save(f"texture/{sexyuuid}.png")
    
    shape = copy.deepcopy(dummyshape)
    shape["name"] = f"Character {char.encode()}"
    shape["uuid"] = str(sexyuuid)
    shape["renderable"]["lodList"][0]["subMeshList"][0]["textureList"][1] = f"$CONTENT_DATA/Objects/Textures/Characters/{str(sexyuuid)}.png"
    
    shapeset["partList"].append(shape)
    
with open("characters.shapeset", "w") as outfile:
    outfile.write( json.dumps(shapeset, indent=4))

with open("uuids.csv", "w", encoding="utf-8") as outfile  :
    outfile.write(csv_string)
    
with open("uuids.lua", "w", encoding="utf-8") as outfile  :
    outfile.write(uuids_lua)