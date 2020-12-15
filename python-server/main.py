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

import asyncio
import time

@app.route('/', methods=['POST'])
def sendCommand():

	print(request.form['request_type'])
	customRequestType = serverDataTypes[ int(request.form['request_type']) ]
	print("Received request:", customRequestType)

	if customRequestType == "clearServer":

		# useless
		return "Pass"

	if customRequestType == "init":

		print("Creating new image")
		print("size_x:",request.form['image_size_x'])
		print("size_y:",request.form['image_size_y'])

		global currentImage 
		currentImage = Image.new('RGB', ( int( request.form['image_size_x'] ), int( request.form['image_size_y'] ) ) )

	if customRequestType == "writePixelRow":

		decodedTable = json.loads(request.form["pixel_data"], parse_float=Decimal)
		color_i = 1
		print("Processing row", int(request.form["y_row"]))

		for decodedImageData in decodedTable:
			for key in decodedImageData:
				print(key)
				# haha yes type converter go brrr
				currentImage.putpixel( ( int(color_i) - 1, int(request.form["y_row"] ) - 1), (int(float(key["r"]) * 255), int(float(key["g"]) * 255), int(float(key["b"]) * 255) ) ) 
				color_i = color_i + 1   
			
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
