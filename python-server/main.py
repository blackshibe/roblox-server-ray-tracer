# BlackShibe 15/12/2020
# too lazy to convert to snake_case

from flask import Flask, abort, request
from tkinter import * 
from PIL import Image, ImageDraw, ImageFont, ImageTk
import os
import httplib2
import json
import tkinter
import base64
import shutil
import time
from decimal import Decimal 

app = Flask(__name__)

serverDataTypes = [
	"clearServer",
	"init",
	"writePixelRow",
	"writeToImage"
]
pixelRows = []
currentImage = Image.new('RGB', (0, 0) )
receivedLines = 0
imageSizeY = 0
globalMessageLoop = 0
img_size_x = 0
img_size_y = 0

import asyncio
import time

@app.route('/', methods=['POST'])
def sendCommand():

	print(request.form['request_type'])
	customRequestType = serverDataTypes[ int(request.form['request_type']) ]
	print("Received request:", customRequestType)

	# top 10 reasons why python is bad
	global img_size_x
	global img_size_y

	if customRequestType == "clearServer":

		# useless
		return "Pass"

	if customRequestType == "init":

		print("Creating new image")
		print("size_x:",request.form['image_size_x'])
		print("size_y:",request.form['image_size_y'])

		global currentImage

		img_size_x = int( request.form['image_size_x'] )
		img_size_y = int( request.form['image_size_y'] )

		currentImage = Image.new('RGB', ( int( request.form['image_size_x'] ), int( request.form['image_size_y'] ) ) )

	if customRequestType == "writePixelRow":

		decodedTable = json.loads(request.form["pixel_data"], parse_float=Decimal)
		color_i = 1
		y_row = 0

		print("Processing row", int(request.form["y_row"]))

		for decodedImageData in decodedTable:
			decodedImageDataTable = json.loads(decodedImageData, parse_float=Decimal)
			y_row = y_row + 1
			color_i = 0
			for key in decodedImageDataTable:

				# this crap
				x = int(color_i) - 1
				y = int(request.form["y_row"]) + y_row - 1
				color_i = color_i + 1   

				if x < img_size_x:
					if y < img_size_y:
						currentImage.putpixel( (x, y), (int(float(key["r"]) * 255), int(float(key["g"]) * 255), int(float(key["b"]) * 255)) ) 
		
	if customRequestType == "writeToImage":

		imageName = time.strftime("%Y %m %d - %H %M %S") + ".png"
		currentImage.save(imageName, "PNG")
		
		root = Tk()
		img = ImageTk.PhotoImage(currentImage)
		panel = Label(root, image = img)
		panel.pack(side = "bottom", fill = "both", expand = "yes")
		root.mainloop()

		return "Pass"

	return "Pass"
