knox= require 'knox'
path= require 'path'
# knoxmiddleware= require './knoxmiddleware'

express = require 'express'
app = express()



knoxClient=knox.createClient(
	key:     process.env.AWS_KEY
	secret:  process.env.AWS_SECRET
	bucket:  process.env.AWS_BUCKET
	endpoint:process.env.AWS_ENDPOINT
)


app.configure ->
	app.set 'port', process.env.PORT || 5000
	app.use express.favicon()
	app.use express.json()
	app.use express.urlencoded()
	# app.use knoxmiddleware(
	# 	client:knoxClient
	# 	limit:'1gb'
	# )
	app.use express.methodOverride()
	app.use app.router
	app.use express.static(path.join(__dirname,'public'))


app.get '/', (req, res)->
	res.send '''
	<form method="post" enctype="multipart/form-data" action='/'>
		<input type="text" name='text' value="dwadaw"/>
		<p>Image: <input type="file" name="video" /></p>
		<p><input type="submit" value="Upload" /></p>
	</form>
	'''


app.post '/', (req,res)->
	res.send("da")



app.listen app.get('port')

