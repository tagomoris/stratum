# Stratum

* http://github.com/tagomoris/Stratum

## DESCRIPTION

Stratum is a O/R Mapper library for Ruby(1.9) and MySQL (and ruby-mysql). Stratum saves all model-objects by INSERT, and provides ways to access historical data of all objects.

## Status

EXPERIMENTAL

## Overview

Define your data model as below:

    class AuthInfo < Stratum::Model
      PRIV_LIST = ['ROOT', 'ADMIN'].freeze
      table :auth_info
      field :name, :string, :validator => 'accountname_checker'
      field :fullname, :string, :length => 64
      field :priv, :string, :selector => PRIV_LIST, :empty => :allowed
    
      def accountname_checker(str)
        # some code to validate username
        str =~ /\Ald.*\Z/
      end
    end

And define database schema of models, and :

    CREATE TABLE auth_info (
    id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    oid         INT             NOT NULL,
    name        VARCHAR(64)     NOT NULL,
    fullname    VARCHAR(64)     NOT NULL,
    priv        VARCHAR(16)     DEFAULT NULL,
    inserted_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operated_by INT             NOT NULL,
    head        ENUM('0','1')   NOT NULL DEFAULT '1',
    removed     ENUM('0','1')   NOT NULL DEFAULT '0'
    ) ENGINE=InnoDB charset='utf8'

writing...


* * * * *

## License

Copyright 2010 TAGOMORI Satoshi (tagomoris)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

