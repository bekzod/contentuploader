join   = require('path').join
crypto = require 'crypto'

exports.urlSigner = (options)->

  key      = options.key
  endpoint = options.host || 's3.amazonaws.com'
  protocol = options.protocol || 'http';
  bucket   = options.bucket

  hmacSha1 = (message)->
    crypto.createHmac('sha1', options.secret).update(message).digest('base64') 

  {

    getUrl:(path, expiresInMinutes)->
      expires = Math.floor((Date.now()+expiresInMinutes)/1000)

      path = '/' + path if path[0] != '/'
        
      reqstr = 'GET\n\n\n' + expires + '\n' + '/' + bucket + path
     
      hashed = hmacSha1(reqstr);

      [
        protocol
        ,"://"
        ,bucket
        ,'.'
        ,endpoint
        ,path
        ,'?Expires='
        ,expires
        ,'&AWSAccessKeyId='
        ,options.key
        ,'&Signature='
        ,encodeURIComponent(hashed)
      ].join('')
  }

