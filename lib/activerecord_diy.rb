# encoding: utf-8
require 'uuid'
require 'delayed_job'
require 'active_support'
require 'active_model'
require 'active_record'

module ActiverecordDIY
  CONFIG = {}
  require 'activerecord_diy/version'
  require 'activerecord_diy/json/backed'
  require 'activerecord_diy/json/hook'
  require 'activerecord_diy/index/model'
  require 'activerecord_diy/index/relation'
  require 'activerecord_diy/index/hook'
end
