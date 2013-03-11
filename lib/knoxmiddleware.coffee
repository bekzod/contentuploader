bytesUtil  = require 'bytes'
formidable = require 'formidable'

noop = (req,res,next)->next()

hasBody = (req)-> 'transfer-encoding' of req.headers || 'content-length' of req.headers;

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

		files={}
		data={}
		
		form = new formidable.IncomingForm()

		form.onPart=(part)->
			return form.handlePart(part) if !part.filename 
			
			form.emit('fileBegin', part.name, file);
			form._flushing++;
			
			acumulator = 0	
			chunkSize = bytesUtil('20mb')
			partname = 'content/'+part.filename
			partEnded= false
			needToFinsh= false

			req.pause()
			cp = require("cloud-pipe")(process.env.AWS_BUCKET,process.env.AWS_KEY,process.env.AWS_SECRET,partname,chunkSize,{maxRetry:4})
			cp.on "cp-error",(err)->form.emit 'error',err
			cp.on "cp-ready",()->req.resume()

			part.on 'data',(data)->
				acumulator+=data.toString('binary')
				if cp.write(acumulator,'binary')
					acumulator = ""
				else
					req.pause()

			part.on 'end',()->
				if acumulator.length
					cp.write(acumulator)
				needToFinsh = !cp.finish()

			
			file = {
				name: part.filename
				type: part.mime
				hash: form.hash
			}

			cp.on "cp-end",()->
				form.resume()
				form._flushing--
				form.emit('file', part.name, file)
				form._maybeEnd()

			cp.on "cp-drained",()->
				if needToFinsh
					cp.finish()
				else
					form.resume()
					
		ondata=(name, val, data)->
		  if Array.isArray(data[name])
		    data[name].push(val)
		  else if data[name]
		    data[name] = [data[name], val]
		  else
		    data[name] = val;

		form.on 'field',(name, val)->ondata(name, val, data)
		form.on 'file',(name, val)->ondata(name, val, files)
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




