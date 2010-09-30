# -*- coding: utf-8 -*-

require_relative '../stratum'

class AuthInfo < Stratum::Model
  table :auth_info
  field :valid, :bool, :default => true
  field :name, :string, :length => 32
end

class TestData < Stratum::Model
  OPTS = ['OPT1', 'OPT2', 'OPT3'].freeze

  table :testtable
  field :flag1, :bool, :default => true
  field :flag2, :bool, :default => false
  field :string1, :string, :length => 32
  field :string2, :string, :selector => OPTS, :default => 'OPT2'
  field :string3, :string, :validator => 'string3validator'
  field :text, :string, :column => 'string4', :length => 1024, :empty => :allowed
  field :string5, :string, :length => 50, :normalizer => 'string5normalizer'
  field :list1, :stringlist, :separator => "\t", :length => 32, :empty => :allowed
  field :list2, :stringlist, :separator => "\t", :length => 4096
  field :list3, :stringlist, :separator => ',', :length => 4096, :empty => :allowed
  field :taglist, :ref, :model => 'TestTag', :empty => :allowed
  field :testex1, :ref, :column => 'ref_oid', :model => 'TestEX1', :empty => :allowed
  field :testex2, :ref, :model => 'TestEX2', :strict => true
  field :testex1s, :reflist, :column => 'testex1_oids', :model => 'TestEX1', :strict => true
  field :testex2s, :reflist, :model => 'TestEX2', :empty => :allowed

  def string3validator(val)
    val =~ //
  end

  def self.string5normalizer(val)
    val.tr('Ａ-Ｚａ-ｚ', 'A-Za-z')
  end
end

class TestEX1 < Stratum::Model
  table :testex1
  field :name, :string, :length => 128
end

class TestEX2 < Stratum::Model
  table :testex2
  field :name, :string, :length => 128
end

class TestTag < Stratum::Model
  table :testtags
  field :tags, :taglist
end
