mongoose = require 'mongoose'
async    = require 'async'

Schema   = mongoose.Schema
ObjectId = Schema.Types.ObjectId


exports = module.exports = (url)->
	connection=mongoose.createConnection url

	# 
	# Content
	# 
	content = new Schema
		size:Number
		duration:{type:Number,default:0}
		owner:[String]
		type:{type: String, enum: ['application/x-shockwave-flash','image/jpeg','image/png','audio/mp3','video/mp4']}
		description:{
			name:String
		}
	connection.model "Content",content