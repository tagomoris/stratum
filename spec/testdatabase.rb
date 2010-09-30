#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'mysql'

module TestDatabase
  def self.prepare
    conn = Mysql.connect('localhost', 'root', nil, nil)
    conn.charset = 'utf8'
    conn.query_with_result = false
    conn.query('CREATE DATABASE testdb')
    conn.close()

    conn = Mysql.connect('localhost', 'root', nil, 'testdb')
    conn.query(<<-EOSQL
CREATE TABLE oids (
id INT PRIMARY KEY NOT NULL AUTO_INCREMENT
) ENGINE=InnoDB
EOSQL
               )
    conn.query(<<-EOSQL
INSERT INTO oids SET id=1
EOSQL
               )
    conn.query(<<-EOSQL
CREATE TABLE auth_info (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
valid       ENUM('0','1')   NOT NULL DEFAULT '1',
name        VARCHAR(32)     NOT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL
               )
    conn.query(<<-EOSQL
INSERT INTO auth_info SET oid=0,name='root',operated_by=0
EOSQL
               )
    conn.query(<<-EOSQL
INSERT INTO auth_info SET oid=1,name='tagomoris',operated_by=0
EOSQL
               )
    conn.query(<<-EOSQL
CREATE TABLE testtable (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
flag1       ENUM('0','1')   NOT NULL DEFAULT '1',
flag2       ENUM('0','1'),
string1     VARCHAR(32)     NOT NULL,
string2     VARCHAR(16)     NOT NULL DEFAULT 'OPT1',
string3     VARCHAR(16)     NOT NULL,
string4     TEXT,
string5     VARCHAR(50)     NOT NULL,
list1       VARCHAR(32),
list2       TEXT            NOT NULL,
list3       TEXT,
taglist     TEXT,
ref_oid     INT             NOT NULL,
testex2     INT,
testex1_oids TEXT           NOT NULL,
testex2s    TEXT,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL
               )
    conn.query(<<-EOSQL
CREATE TABLE testex1 (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(128)    NOT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL
               )
    conn.query(<<-EOSQL
CREATE TABLE testex2 (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
name        VARCHAR(128)    NOT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0'
) ENGINE=InnoDB charset='utf8'
EOSQL
               )
    conn.query(<<-EOSQL
CREATE TABLE testtags (
id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
oid         INT             NOT NULL,
tags        TEXT            NOT NULL,
inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
operated_by INT             NOT NULL,
head        ENUM('0','1')   NOT NULL DEFAULT '1',
removed     ENUM('0','1')   NOT NULL DEFAULT '0',
FULLTEXT INDEX tag_indx (tags)
) ENGINE=MyISAM charset='utf8'
EOSQL
               )

    conn.close()
  end

  def self.drop
    conn = Mysql.connect('localhost', 'root', nil, nil)
    conn.charset = 'utf8'
    conn.query_with_result = false

    conn.query('DROP DATABASE testdb')

    conn.close()
  end
end
