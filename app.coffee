# This project is a modification of https://github.com/validkeys/rss_feed_discoverer
#
# USAGE:
# Comprehensive CSV: coffee --nodejs --stack_size=32768 app.coffee url_list_short.txt --open --no-images
# Compact CSV: coffee --nodejs --stack_size=32768 app.coffee url_list_short.txt --open --no-images --compact=true
# OPML: coffee --nodejs --stack_size=32768 app.coffee url_list_short.txt --open --no-images --filetype=opml

exec = require('child_process').exec
fs = require('fs')
opml = require("opml-generator")
LinkDispatcher = require('./link_dispatcher')

opts = require('nomnom').options({
  open: {
    abbr: 'o',
    flag: true,
    default: false,
    help: 'Opens the CSV when done.'
  },
  'no-images': {
    abbr: 'i',
    flag: true,
    help: 'Skips fetching images from feeds.'
  },
  concurrency: {
    abbr: 'c',
    default: 5,
    help: 'Set the number of pages/feeds we load simultaneously.',
  },
  depth: {
    abbr: 'd',
    default: 3,
    help: 'Set how deep of a chain (maximum) we follow before giving up.'
  },
  'compact': {
    abbr: 'u',
    default: false,
    help: 'Output list of feed URLs only...no analysis'
  },
  'filetype': {
    abbr: 'f',
    default: 'csv',
    help: 'Save output as CSV or OPML'
  }
}).nom()


opts.images = true if !opts.images?

# Simultaneous request limit for pages and feeds.
# At most one image request will occur per feed at once.
SIMULTANEOUS_PAGE_REQUEST_LIMIT = opts.concurrency

# Limit the number of pages we'll pass through before stopping (on each path).
process.MAX_DEPTH = opts.depth

# Limit output to just a list of URL's for processing
process.COMPACT = opts.compact

# File output type
process.FILETYPE = opts.filetype

# If outputting an OPML, force output type to compact
if process.FILETYPE == "opml"
  process.COMPACT = true

# Prepare a property to contain an OPML title
process.OPML_TITLE = "Genereic RSS Feed OPML Title"

filename = process.argv[2]
csv = null
opmlXML = null

console.log "---------------------------------------------------------------"
console.log "Starting crawler with URLs from #{filename}..."
console.log "Max depth: #{process.MAX_DEPTH}, concurrency: #{SIMULTANEOUS_PAGE_REQUEST_LIMIT}, fetching images: #{opts.images}."
console.log "---------------------------------------------------------------"

if filename?
  fs.readFile(filename, 'utf8', (err, data) ->
    csv = null
    
    # we might get a CSV with \r breaks and not \n
    urls = data.split('\n')
    if(urls.length == 1) 
      urls = data.split('\r')

    @urlsToProcess = {}
    @urlsInProgress = {}  
    @urlResults = {}
    
    if(process.FILETYPE == "opml") #expect first line to contain OPML file title
      process.OPML_TITLE = urls[0]
      useUrls = urls[1...] #remove the first 'url' which is actually the OPML title      
    else
      useUrls = urls[0...]

    for url in useUrls
      @urlsToProcess[url] = { depth: 0 }
        
    @dispatcher = new LinkDispatcher(@urlsToProcess, @urlsInProgress, @urlResults)
    
    for i in [1..SIMULTANEOUS_PAGE_REQUEST_LIMIT]
      processNextURL()
  )
else
  console.log "ERROR: please provide a file to read URLs from."
  process.exit(2)
  


processNextURL = ->
  urls = Object.keys(@urlsToProcess)
  if urls.length > 0
    url = urls[0]
    @urlsInProgress[url] = { depth: @urlsToProcess[url].depth }
    delete @urlsToProcess[url]
    
    @dispatcher.get(url, @urlsInProgress[url].depth, (properties) =>
      @urlResults[url] = properties
      if !process.COMPACT
        @urlResults[url].depth = @urlsInProgress[url].depth
      delete @urlsInProgress[url]
    
      processNextURL()
    
      if Object.keys(@urlsToProcess).length is 0 and Object.keys(@urlsInProgress).length is 0 and not process.saving?
        if process.FILETYPE == "csv"
          saveAsCSV()
        else
          saveAsOPML()
    )

saveAsCSV = ->
  process.saving = true

  for properties in Object.keys(@urlResults)
    if Object.keys(@urlResults[properties]).length > 1
      if !csv?
        csv = Object.keys(@urlResults[properties]).join(',') + '\n'

      csv += Object.keys(@urlResults[properties]).map((key) ->
        if typeof @urlResults[properties][key] is "string"
          @urlResults[properties][key].replace(/[,\n]/g, " ")
        else
          @urlResults[properties][key]
      ).join(',') + '\n'

  file = "./results/rss_scrape_results_#{new Date().getTime()}.csv"
  fs.writeFile(file, csv, (err) ->
    if err?
      # Write failed, but we've done all our processing so we'll output the CSV data to STDOUT
      # (so we don't have to start over)
      console.log err
      console.log "Done, but couldn't save CSV. Here's the data we were trying to save:"
      console.log csv
      process.exit(1)
    else
      console.log "All done. The results were saved into #{file}."
      if opts.open
        console.log "Opening #{file}..."
        exec("open #{file}")
      process.exit(0)
  )

saveAsOPML = ->
  process.saving = true
  header = {
    "title": process.OPML_TITLE
    "dateCreated": new Date(),
    "ownerName": "tdb"
  }

  outlines = []
  thisItem = {}

  for properties in Object.keys(@urlResults)
    if Object.keys(@urlResults[properties]).length > 1
      Object.keys(@urlResults[properties]).map((key) ->
        thisItem = {
          "text": @urlResults[properties]["title"],
          "title": @urlResults[properties]["title"]
          "type": @urlResults[properties]["type"]
          "xmlUrl": @urlResults[properties]["url"]
        }
      )
      outlines.push(thisItem)

      #   Object.keys(@urlResults[properties]).map((key) ->
      #   if typeof @urlResults[properties][key] is "string"
      #     @urlResults[properties][key].replace(/[,\n]/g, " ")
      #   else
      #     @urlResults[properties][key]
      # ).join(',') + '\n'

  console.log(header);
  console.log(outlines);

  file = "./results/cassandra_opml_#{new Date().getTime()}.opml"
  opmlXML = opml(header, outlines); # => XML 

  fs.writeFile(file, opmlXML, (err) ->
    if err?
      # Write failed, but we've done all our processing so we'll output the CSV data to STDOUT
      # (so we don't have to start over)
      console.log err
      console.log "Done, but couldn't save OPML. Here's the data we were trying to save:"
      console.log csv
      process.exit(1)
    else
      console.log "All done. The results were saved into #{file}."
      if opts.open
        console.log "Opening #{file}..."
        exec("open #{file}")
      process.exit(0)
  )



