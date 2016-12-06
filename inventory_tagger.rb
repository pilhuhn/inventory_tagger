#!/usr/local/bin/ruby

require 'hawkular/hawkular_client'
require 'hawkular/hawkular_client_utils'

MATCH_TAG_PAIRS = { '~Heap Used'   => { :heap => :used},
                    '~NonHeap Used' => {:non_heap => :used},
                    '~Thread Count' => {:thread => :count}
}

class Inventory_Tagger

  include HawkularUtilsMixin

  def run
    creds = {:username => 'jdoe', :password => 'password'}

    remote_host = ENV['HOST'] || 'localhost'

    hash = {}
    hash[:credentials] = creds
    hash[:options] = { :tenant => 'hawkular' }
    hash[:entrypoint] = "http://#{remote_host}:8080"

    begin
      client = ::Hawkular::Client.new(hash)
      client.inventory.fetch_version_and_status
    rescue => e
      puts "Server not yet ready: #{e.message}"
      sleep 0.5
      retry
    end

    client.inventory.events(type = 'metric') do |metric|
      MATCH_TAG_PAIRS.keys.each do |key|
        if metric.id.include? key
          puts "Found #{metric.id}"
          do_tag client, metric, MATCH_TAG_PAIRS[key]
        end
      end
    end

    puts 'Started ...'

    # Now fetch metrics that may have been created before this was starting
    feeds = client.inventory.list_feeds
    feeds.each do |feed|
      # type = Hawkular::Inventory::CanonicalPath.new(resource_type_id: hawk_escape_id('WildFly Memory Metrics~Heap Used')).to_s
      type = Hawkular::Inventory::CanonicalPath.new(feed_id: feed,
                                                    resource_type_id: hawk_escape_id('WildFly Server')).to_s
      metrics = client.inventory.list_metrics_for_resource_type type
      metrics.each do | metric |
        MATCH_TAG_PAIRS.keys.each do |key|
          if metric.id.include? key
            puts "Found #{metric.id}"
            do_tag client, metric, MATCH_TAG_PAIRS[key]
          end
        end
      end
    end

    while true do
      sleep 0.5
    end

  end

  def do_tag(client, inv_metric, tag)

    ep = metric_endpoint client, inv_metric
    id = inv_metric.hawkular_metric_id

    md = ep.get id

    if md.nil?
      puts 'MetricDefinition did not yet exist'
      md = ::Hawkular::Metrics::MetricDefinition.new
    end

    if md.id.nil?
      puts 'MetricDefinition\'s id was nil - definition probably did not exist'
      md.id = id
    end

    md.tags ||= tag

    res = ep.update_tags md
    puts "Received #{res}"
  end

  def metric_endpoint(client, inv_metric)
    case inv_metric.type
    when 'GAUGE'
      client.metrics.gauges
    when 'COUNTER'
      client.metrics.counters
    when 'AVAILABILITY'
      client.metrics.avail
    else
      fail "Unknown type #{inv_metric.type} for #{inv_metric}"
    end
  end

  it = Inventory_Tagger.new
  it.run



end