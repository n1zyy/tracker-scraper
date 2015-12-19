# tracker-scraper

This is some kind-of-nasty code I cobbled together, to do two things:

1. Whittle a huge list of known trackers down to a smaller list of those that actually work.
2. Search across them for a given torrent hash.

Please note that the tracker-list file is mostly bad trackers, and that this is
not a functional torrent client. It just scrapes a list of trackers for a given hash.

I play with `work_queue` doing 25 (number from a hat) concurrent workers here.

### Finding good trackers

This is slow. It'll query about 300 trackers, most of them defunct, 5 times, once
per hash. (The hashes are random things found on public trackers.) It then prints
whether each is good or bad, and what percentage of queries succeeded.

I don't _think_ a hash unknown to the tracker counts as a failure?

```ruby
require 'tracker_scraper'
t = TrackerScraper.new
t.find_working_trackers
```

### Scraping trackers for a hash

```ruby
require 'tracker_scraper'
t = TrackerScraper.new
t.print_find('3F19B149F53A50E14FC0B79926A391896EABAB6F')
````

It'll print a crude little table of seeders/leechers/downloads for each tracker
that returns something.

Everything except my implementation supports taking an array of hashes, but I wasn't
using it that way so I didn't add it.