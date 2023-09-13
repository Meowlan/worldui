from PIL import Image, ImageDraw, ImageFont

# Define the list of characters
chars = u"☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~⌂ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■"

font = ImageFont.truetype("cour.ttf", 250)

# Create a blank image to draw the UV map
maxwidth, maxheight = 0, 0
for char in chars:
    _, _, w, h = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox((0, 0), char, font=font)
    maxwidth = max(maxwidth, w)
    maxheight = max(maxheight, h)

# Calculate the number of rows and columns for a perfect rectangle
num_chars = len(chars)
num_columns = int(num_chars ** 0.5)
num_rows = (num_chars - 1) // num_columns + 1

# Calculate the cell size based on the dimensions of the largest character
cell_width = maxwidth
cell_height = maxheight

# Calculate the image size based on the cell size and number of rows and columns
image_width = num_columns * cell_width
image_height = num_rows * cell_height

# Create the UV map image
uv_map = Image.new("RGB", (image_width, image_height), color="white")
draw = ImageDraw.Draw(uv_map)

# Draw characters on the UV map
x, y = 0, 0
for char in chars:
    #draw.rectangle([x, y, x + cell_width, y + cell_height], outline="black")
    draw.text((x, y), char, fill="black", font=font)
    x += cell_width
    if x >= image_width:
        x = 0
        y += cell_height

print("Rows: {0} Cols: {1}\nWidth: {2} Height: {3}\nRatio: {4}\nW%: {5} H%: {6}".format(num_rows, num_columns, cell_width, cell_height, cell_width/cell_height, cell_width/image_width, cell_height/image_height))

# Save the UV map
uv_map.save("uv_map.png")

# Display the UV map
uv_map.show()
