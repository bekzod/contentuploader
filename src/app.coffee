path       = require 'path'
autos3     = require 'autos3'
check      = require('validator').check
express    = require 'express'
signMaker  = require './aws-url'
RedisStore = require('connect-redis')(express)


aws = signMaker.urlSigner(
	key    : process.env.AWS_KEY
	secret : process.env.AWS_SECRET
	bucket : process.env.AWS_BUCKET
);

con = require('./schema')(process.env.DATABASE)

Content = con.model 'Content'

app = express()

app.configure ->
	app.set 'port', process.env.PORT || 5000
	app.use express.favicon()
	app.use express.cookieParser()
	app.use express.session(
		secret: 'khorezmtashkent'
		cookie:
			path     : '/'
			httpOnly : true
			maxAge   : 12*60*60*1000 
		store : new RedisStore(
			host  : "nodejitsudb6982986524.redis.irstack.com"
			port  : 6379
			db    : "session"
			pass  : "nodejitsudb6982986524.redis.irstack.com:f327cfe980c971946e80b8e975fbebb4"
		)
	)
	app.use autos3(
		key           : process.env.AWS_KEY
		secret        : process.env.AWS_SECRET
		bucket        : process.env.AWS_BUCKET
		defer         : false
		uploadDir     : '/content/'
		acceptedTypes :['application/x-shockwave-flash','image/jpeg','image/png','audio/mp3','video/mp4']
	)
	app.use express.methodOverride()
	app.use app.router
	app.use (req,res,next)->


	app.use express.static(path.join(__dirname,'../public'))


app.get '/', (req, res)->
	res.redirect 'index.html'



# Content Management API

# ADD CONTENT

app.post '/content',(req,res)->
	file = req.files['qqfile']
	return res.send 300 if !file

	try
		check(req.body.name,'name').notEmpty();
	catch e
		return res.send error:e

	req.body.name     = req.body.name.trim()
	req.body.duration = req.body.duration || 0

	content = new Content {
		_id       	  : file.id
		name          : req.body.name
		type    	  : file.type
		duration      : req.body.duration
	}

	content.save (err,content)->
		return res.send 300 if err
		res.send {success:true}



# REMOVE CONTENT

app.del '/content/:contentid',(req,res)->
	try
		check(contentid,'content id').len(24)
	catch e
		return res.send error:e


app.get '/content/:contentid',(req,res)->
	contentid = req.params.contentid
	try
		check(contentid,'player id').len(24)
	catch e
		return res.send success:false

	Content.findById contentid,(err,content)->
		return res.send success:false if err||!content
		res.send 
			success:true
			result:content



app.get '/content',(req,res)->
	opts = {}

	opts.limit = req.query.limit || 30 
	opts.skip  = req.query.skip  || 0;
	opts.sort  = {}
	opts.sort[req.query.sort||'_id'] = parseInt(req.query.asc||-1);

	query = {}
	i=0
	for k,v of req.query.query
		break if i++ > 3
		if v && v[0] == '\/' && v[v.length-1] == '\/'
			query[k] = new RegExp v.substring(1,v.length-1)
		else
			query[k] = v
	
	Content.find query,null,opts,(err,contents)->
		return res.send success:false if err
		res.send
			result  : contents
			success : true
			options : opts 




app.get '/media/:contentid',(req,res)->
	contentid = req.params.contentid
	if true
		url = aws.getUrl('content/'+contentid,1000*60)
		res.redirect url
	else
		res.send 300


app.listen app.get('port')

