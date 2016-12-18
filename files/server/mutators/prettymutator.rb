#!/usr/bin/env ruby

require 'rubygems'
require 'json'

puts JSON.pretty_generate(JSON.parse(STDIN.read))
