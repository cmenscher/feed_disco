*This project is a modification of https://github.com/validkeys/rss_feed_discoverer*

# RSS Scraper

This is a simple script that will crawl a set of given URLs to try to determine any RSS feeds that are associated with that URL.

We not only look for RSS feeds on the pages whose links you provide, but we also look for other pages that *may* contain connections to RSS feeds.

For every RSS feed we find, we perform a small analysis on it. We output those results to a `.csv` file that can be opened in Excel, Numbers, etc., for further analysis.

There is some overlap between this and Chromebot (and to a lesser degree, Spiderbite). This solution is ideal for RSS scraping because we don't need access to JavaScript objects, whereas Chromebot needs access to the JS objects on the pages it loads. This is faster for processing RSS because we don't need to worry about the overhead of Chrome.

## Usage

A comprehensive CSV (the default from the original project) contains multiple columns of info about discovered URL's

A compact CSV contains just the URLs, Titles, Counts, and Type (RSS or Atom)

An OPML file can be output from the discovery, which expects the first line of the input file to contain a description for the file.

### tl;dr

	Comprehensive CSV: coffee --nodejs --stack_size=32768 app.coffee url_list_short.txt --open --no-images
	Compact CSV: coffee --nodejs --stack_size=32768 app.coffee url_list_short.txt --open --no-images --compact=true
	OPML: coffee --nodejs --stack_size=32768 app.coffee url_list_short.txt --open --no-images --filetype=opml


### More details
Run `app.coffee` followed by the location of a file containing a list of links. Each link must be on its own line, and all links must include `http://` or `https://`.

The `--open` option will open the CSV file containing the results when it's done. The file will also be saved into `./results/`. If this option is not specified, the file will be saved but not opened.

Using the `--no-images` option will greatly improve performance of this script. If this option *is* specified, we won't fetch any of the images in the RSS feeds to check their dimensions. This has the effect of not calculating the pixel counts and average image dimensions. By default, we will fetch all images found in RSS feeds (both in their content and as image enclosures).

`--concurrency 10` allows the crawler to send off 10 HTTP(S) requests simultaneously to fetch pages/feeds. Images are always fetched one at a time.

`--depth 2` tells the crawler that it can only process links of depth 2 or less. The URLs in the given file have a depth of 0. If on those pages, we find other pages we want to crawl, those will have depth 1, and so on. We have to set this so we don't continue on forever.

**This is a major hack**: we need to override V8's `--stack_size` due to the way we're limiting the number of simultaneous page/feed requests. We're processing URLs recursively in order to achieve that, which makes our call stack insanely large. 

The `--stack_size` option needs to be passed directly to the `node` process, which is why we have specified `--nodejs` immediately prior to `--stack_size`.