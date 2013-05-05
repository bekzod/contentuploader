path       = require 'path'
autos3     = require 'autos3'
check      = require('validator').check
express    = require 'express'
knox       = require 'knox'
async      = require 'async'
signMaker  = require './aws-url'
RedisStore = require('connect-redis')(express)

allowCrossDomain = (req, res, next)->
	res.header('Access-Control-Allow-Credentials', true);
	res.header('Access-Control-Allow-Origin', "*")
	res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS');
	res.header('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');
	next();


aws = signMaker.urlSigner(
	key    : process.env.AWS_KEY
	secret : process.env.AWS_SECRET
	bucket : process.env.AWS_BUCKET
);


knoxClient = knox.createClient(
	key    : process.env.AWS_KEY
	secret : process.env.AWS_SECRET
	bucket : process.env.AWS_BUCKET
);

con = require('./schema')(process.env.DATABASE)

Content = con.model 'Content' 

app = express()

app.configure ->
	app.set 'port', process.env.PORT || 5000
	app.use allowCrossDomain
	app.use express.favicon()
	# app.use express.cookieParser()
	# app.use express.session(
	# 	secret: 'khorezmtashkent'
	# 	cookie:
	# 		path     : '/'
	# 		httpOnly : true
	# 		maxAge   : 12*60*60*1000 
	# 	store : new RedisStore(
	# 		host  : "nodejitsudb6982986524.redis.irstack.com"
	# 		port  : 6379
	# 		db    : "session"
	# 		pass  : "nodejitsudb6982986524.redis.irstack.com:f327cfe980c971946e80b8e975fbebb4"
	# 	)
	# )
	app.use autos3(
		key           : process.env.AWS_KEY
		secret        : process.env.AWS_SECRET
		bucket        : process.env.AWS_BUCKET
		defer         : false
		uploadDir     : '/content/'
		acceptedTypes : Content.schema.path('type').enumValues
	)
	app.use express.methodOverride()
	app.use app.router
	app.use express.static(path.join(__dirname,'../public'))


app.get '/management', (req, res)->
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

	console.log file

	req.body.name     = req.body.name.trim()
	req.body.duration = req.body.duration || 0
		
	content = new Content {
		_id       	  : file.id
		description:
			name : req.body.name
		type     : file.type
		duration : req.body.duration
		size     : file.size
	}

	content.save (err,content)->
		return res.send 300 if err
		res.send {success:true}



# REMOVE CONTENT

app.del '/content/:contentid',(req,res)->

	try
		check(req.params.contentid,'content id').len(24)
	catch e
		return res.send {error:e,succes:false}

	async.parallel [
		(callback)->knoxClient.deleteFile('/content/'+req.params.contentid,callback)
		(callback)->Content.remove({_id:req.params.contentid},callback)
	],(err)->
		if err then return res.send succes:false
		res.send {succes:true}
		




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
	opts.sort[req.query.sort||'_id'] = parseInt(req.query.order);
	query = {}
	console.log opts
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

