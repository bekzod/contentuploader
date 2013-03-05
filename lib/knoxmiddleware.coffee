bytesUtil =	 	  require 'bytes'
formidable= require 'formidable'

noop = (req,res,next)->next()

hasBody = (req)-> 
	'transfer-encoding' of req.headers || 'content-length' of req.headers;


mime = (req)->
	str = req.headers['content-type'] || ''
	str.split(';')[0]

limit = (bytes)->
	bytes = bytesUtil(bytes) if ('string' == typeof bytes)
	throw new Error('limit() bytes required') if 'number' != typeof bytes 

	(req,res,next)->
		received=0
		len= if req.headers["content-length"] then parseInt(req.headers["content-length"],10);

		return next() if req._limit
		req._limit = true
		return next(413) if (len && len > bytes)

		req.on 'data', (chunk)->
			received += chunk.length;
			req.destroy() if received > bytes

		next();





exports = module.exports =(options={})->
	
	limit = if options.limit then limit(options.limit) else noop
	client= options.client

	(req,res,next)->
		return next() if req._body
		return next() if 'GET' == req.method || 'HEAD' == req.method
		return next() if !hasBody(req)
		return next() if 'multipart/form-data' != mime(req)
		
		req.body = req.body || {}
		req.files = req.files || {}
		done = false
		req._body = true
		
		form = new formidable.IncomingForm()
		form.onPart=(part)->
			return form.handlePart(part) if !part.filename 
			acumulator = ""	
			
			req.pause()
			cp = require("cloud-pipe")(process.env.AWS_BUCKET,process.env.AWS_KEY,process.env.AWS_SECRET,part.filename,bytesUtil('20mb'))

			cp.on "cp-ready",()->
				req.resume()

			cp.on "cp-drained",()->
				console.log "drained"
				req.resume()

			cp.on "cp-error",(err)->
				console.log err


			part.on 'end',()->
				console.log "ended"
				cp.finish();

			part.on 'data',(data)->
				acumulator+=data

				if cp.write(acumulator)
					acumulator = ""
					console.log "success"
				else
					req.pause()
					console.log "failure"





			part.on 'data',(data)->
			# console.log(ofType data) 
			 #    if (!cp.write(String(data))
			 #    	console.log "written"
			 #    else 
			 #    	console.log "bad"

				# part.on 'end',()->
				# 	cp.finish()

			part.on 'error',(err)->console.log err

		form.on 'error',(err)->
			if !options.defer
				err.status = 400;
			next(err)
			done = true

		form.on 'end',->
			return if done	
			next() if !options.defer 

		form.parse req
	
		if options.defer
			req.form = form
			next()




