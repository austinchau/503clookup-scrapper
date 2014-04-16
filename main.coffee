async = require 'async'
qs = require 'querystring'
request = require 'request'
jsdom = require 'jsdom'
fs = require('fs')
jquery = fs.readFileSync('./jquery-latest.min.js').toString()

options =
  uri: 'http://501c3lookup.org/'
  headers:
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
    'Accept-Language': 'en-US,en;q=0.8'
    'Cache-Control': 'max-age=0'
    DNT: 1
    Host: '501c3lookup.org'
    Origin: 'http://501c3lookup.org'
    'Referer': 'http://501c3lookup.org/'
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36'
    
parse = (html, cb)->
  return cb 'empty html', null if not html
  jsdom.env
    html: html
    src: [jquery]
    done: (err, window)->
      $ = window.$
      cb err, $, window

search = (str, callback)->
  postdata = 
    this_ein: ''
    this_name: ''
    this_city: ''
    this_state: ''
    this_activity_code: ''
    this_nteecc: ''
  if /^\d+$/.test str
    # it's EIN
    "#{str}0" if str.length is 8
    postdata.this_ein = str
  else
    kw = str.replace /[^a-z0-9\s-]+/ig, ''
    kw = kw.replace /\s/ig, '+'
    postdata.this_name = kw
  console.log "...working on #{str}"
      
  options.uri = 'http://501c3lookup.org/Results/'
  options.method = 'POST'
  options.headers['Content-Type'] = 'application/x-www-form-urlencoded'
  options.body = ("#{k}=#{v}" for k,v of postdata).join '&'
  # console.log options.body
  options.headers['Content-Length'] = options.body.length
  # console.log options

  request options, (err, status, body)->
    return callback err, null if err
    # console.log body
    parse body, (err, $)->
      # console.log $('title').text()
      if err
        console.log '### network error!', str
        return callback null, '#{str},Network error' 
      # console.dir status.headers
      # console.log status.statusCode
      # console.log status.headers.location
      if not status.headers.location
        console.log '### N/A! for', str
        return callback err, "#{str},N/A" 
      request uri: "http://501c3lookup.org/#{status.headers.location}", (err, status, body)->
        return callback err, null if err
        parse body, (err, $)->
          return callback err, null if err
          data = []
          ein = postdata.this_ein or ''
          name = $('h1[itemprop="name"]').text()
          data.push ein
          data.push "#{name.trim()}".replace /,/g, ' '
          $('h5 span').each (i)->
            data.push "#{$(this).text().trim()}".replace /,/g, ' '
          console.log "DONE with #{str}"
          callback err, data.join ','

HEADINGS = 'EIN, NAME, ORGANIZATION CODE, DEDUCTIBILITY CODE, AFFILIATION CODE, SUBSECTION/CLASSIFICATION CODES, ACTIVITY CODES, NTEE COMMON CODE, NTEE CODE, FOUNDATION CODE, EXEMPT ORGANIZATION STATUS CODE, TAX PERIOD, ACCOUNTING PERIOD,INCOME CODE, INCOME AMOUNT, FORM 990 REVENUE AMOUNT, RULING DATE, ASSET CODE, ASSET AMOUNT, FILING REQUIREMENT CODE, PF FILING REQUIREMENT CODE'

if not module.parent
  inputFileName = process.argv[2] or 'input.csv'
  outputFileName = 'output.csv'

  input = fs.readFileSync("#{__dirname}/#{inputFileName}").toString().split /[\n\r]+/ig
  input = (i for i in input when i?.trim().length > 0)
  console.log 'About to process input =', input
  # inputs = ['LOWENBRAUN FAMILY FOUNDATION CHAIM LOWENBRAUN TTEE', 'pencils of promise', 'disconnect']
  # inputs = ['promise', 'pencils of promise']
  # input = input[0...60]
  
  maxConcurrentFetch = 3
  
  async.mapLimit input, maxConcurrentFetch, search, (err, result)->
    console.log err if err
    result.unshift HEADINGS
    body = result.join '\n'
    console.log body
    fs.writeFileSync "#{__dirname}/#{outputFileName}", body