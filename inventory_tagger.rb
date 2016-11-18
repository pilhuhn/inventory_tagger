#!/usr/local/bin/ruby

require 'hawkular/hawkular_client'

class Inventory_Tagger

  def run
    creds = {:username => 'jdoe', :password => 'password'}

    remote_host = ENV['HOST'] || 'localhost'

    hash = {}
    hash[:credentials] = creds
    hash[:options] = { :tenant => 'hawkular' }
    hash[:entrypoint] = "http://#{remote_host}:8080"

    client = ::Hawkular::Client.new(hash)

    client.inventory.events(type = 'metric') do |metric|

      if metric.id.include? '~Heap Used'
        puts "Found #{metric.id}"
        do_tag client, metric
      end

    end

    puts 'Started ...'
    while true do
      sleep 0.5
    end

  end

  def do_tag(client, inv_metric)

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

    md.tags ||= { :heap => :used}

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