require 'firecracker'
require 'timeout'
require 'work_queue'
require 'resolv'

# Oh yeah, let's just monkey with this here
$LOAD_PATH << File.join(File.dirname(__FILE__))


# This is a little class representing how I think this should work
class Tracker
  attr_accessor :url

  def initialize(url)
    unless url.match(/^http:/) || url.match(/^udp:/)
      raise "Invalid tracker URL"
    end
    self.url = url
  end

  # Attempt to scrape the hash
  # Raises Timeout::Error of sundry protocol errors 
  def scrape(hash, timeout=5)
    if url.match(/^udp/)
      klass = Firecracker::UDPScraper
    else
      klass = Firecracker::TCPScraper
    end
    Timeout::timeout(5) do
      klass.new({
        tracker: url,
        hashes: [hash]
      }).process!
    end
  end
end


# TODO - This doesn't make a lot of sense as a class, TBH...
class TrackerScraper

  # Return an array of trackers from tracker_list.txt
  # Randomized order each time because it seemed like a good idea at the time
  def tracker_list
    return @trackers.shuffle if !@trackers.nil?
    @trackers = []
    f = File.new("tracker_list.txt")
    f.each do |line|
      @trackers << line.strip
    end
    return @trackers.shuffle
  end
  
  # Scrape tracker for an array of hashes
  # This is dirrrrttttyyyy
  def scrape_all(hash)
    # TODO: don't hardcode the limit of 25 threads here...
    queue = WorkQueue.new 25
    @scrapes = []
    tracker_list.each do |tracker_url|
      queue.enqueue_b do
        t = Tracker.new(tracker_url)

        begin
          result = t.scrape(hash)
          status = :success
        rescue => e
          status = :failure
          message = e.message
        end
        
        @scrapes << {
          :tracker => tracker_url,
          :status => status,
          # Don't index result by hash since there's only 1 here
          :result => result.is_a?(Hash) ? result[hash] : result,
          :message => message
        }

      end
    end
    queue.join
    @scrapes
  end

  # Scrape everybody for a hash
  # Return those that aren't errors
  def find(hash)
    ret = []
    scrape_all(hash).select{|x| x[:status] == :success}.each do |match|
      _ret = match[:result]
      _ret.merge!({:tracker => match[:tracker]})
      ret << _ret
    end
    ret
  end
  
  # Print a table of those that have a given hash
  def print_find(hash)
    find(hash).each do |row|
      puts "#{row[:seeders]}\t#{row[:leechers]}\t#{row[:downloads]}\t#{row[:tracker]}"
    end
    return nil
  end
  
  # Query everyone for 5 hashes; return those that succeeded one or more times
  def find_working_trackers
    # We could pass an array in, but the purpose is to do 5 scrapes and see
    # how often the host responds. Using different ones looks less like abuse.
    hashes = [
      '867bdcaec9b522809aebc1e7085ef8f0a1e7f290',
      '1354AC45BFB3E644A04D69CC519E83283BD3AC6A',
      '66FC47BF95D1AA5ECA358F12C70AF3BA5C7E8F9A',
      '39eac8c9fcb529d518184d45cdaa558771089835',
      '3C7534B034FE8FD46B5AF3A52AC3AA1B89DDEF03'
    ]

    results = {}

    hashes.each do |hash|
      puts "Fetching hash #{hash}..."
      scrape_all(hash).each do |res|
        tracker = res[:tracker]
        status = res[:status]
        if results.has_key?(tracker)
          results[tracker] << status
        else
          results[tracker] = [status]
        end
      end
    end
    
    puts "Finished scanning #{hashes.size} hashes across #{results.size} trackers..."
    results.each do |tracker, res|
      puts "#{res}: #{tracker}"
      success = res.select{|x| x == :success}.count * 20
      if success > 0
        puts "GOOD: #{tracker} (#{success}%)"
      else
        puts "BAD: #{tracker} (0%)"
      end
    end
    nil
  end
end
