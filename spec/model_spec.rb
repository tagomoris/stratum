# -*- coding: utf-8 -*-

require_relative '../stratum'

require_relative './testdatabase'
require_relative './testdatamodel'

SERVERNAME = 'localhost'
USERNAME = 'root'
PASSWORD = nil
DATABASE = 'testdb'

describe Stratum::Model, "を継承してモデル定義するとき" do
  # DSL, getter/setter definition
  # この場でクラス定義しては結果を見る
  
  it "に .table でセットしたテーブル名が .tablename で正常に読み出せること" do
    class Test01 < Stratum::Model
      table :hogetable
    end
    Test01.tablename.should eql('hogetable')
  end

  it "に .field で不明な型名を指定すると例外が発生すること" do
    lambda { class Test02 < Stratum::Model ; field :tes2, :moge ; end }.should raise_exception(Stratum::InvalidFieldType)
  end

  it "に .field でセットしたフィールド定義が .fields .columns .field_by .column_by で正常に読み出せること" do
    class Test03 < Stratum::Model
      field :f1, :bool, :default => true
      field :f2, :string, :length => 10
    end
    (Test03.fields - ([:f1, :f2] + Stratum::Model::RESERVED_FIELDS)).should eql([])
    (Test03.columns - (['f1', 'f2'] + Stratum::Model::RESERVED_FIELDS.map{|f| f.to_s})).should eql([])
    Test03.field_by('f1').should eql(:f1)
    Test03.field_by('f2').should eql(:f2)
    Test03.column_by(:f1).should eql('f1')
    Test03.column_by(:f2).should eql('f2')
  end

  it "に 予約フィールド名 id/oid/inserted_at/operated_by/head/removed を使用しようとしたら例外となること" do
    lambda { class Test04a < Stratum::Model ; field :id, :bool, :default => true ; end }.should raise_exception(Stratum::InvalidFieldDefinition)
    lambda { class Test04b < Stratum::Model ; field :oid, :bool, :default => true ; end }.should raise_exception(Stratum::InvalidFieldDefinition)
    lambda { class Test04c < Stratum::Model ; field :inserted_at, :bool, :default => true ; end }.should raise_exception(Stratum::InvalidFieldDefinition)
    lambda { class Test04d < Stratum::Model ; field :operated_by, :bool, :default => true ; end }.should raise_exception(Stratum::InvalidFieldDefinition)
    lambda { class Test04e < Stratum::Model ; field :head, :bool, :default => true ; end }.should raise_exception(Stratum::InvalidFieldDefinition)
    lambda { class Test04f < Stratum::Model ; field :removed, :bool, :default => true ; end }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に .field(:column => name) でセットしたカラム名が .columns .column_by で正常に読み出せること" do
    class Test05 < Stratum::Model
      field :f1, :bool, :default => true
      field :fb, :string, :column => 'fb_string', :length => 10
      field :Ax, :ref, :column => 'ax_oid', :model => 'Ax', :empty => :allowed
    end
    (Test05.columns - (['f1', 'fb_string', 'ax_oid'] + Stratum::Model::RESERVED_FIELDS.map{|f| f.to_s})).should eql([])
    Test05.column_by(:f1).should eql('f1')
    Test05.column_by(:fb).should eql('fb_string')
    Test05.column_by(:Ax).should eql('ax_oid')
  end

  it "に .field でセットしたフィールド定義が .definition .datatype で正常に読み出せること" do
    class Test06a < Stratum::Model
      field :f1, :bool, :default => false
      field :f2l, :string, :length => 27
      field :f2s, :string, :selector => ['X', 'Y', 'Z']
      field :f2v, :string, :validator => 'ftwovalidator'
      field :f3, :stringlist, :separator => "\n", :length => 1029
      field :ft, :taglist, :empty => :allowed
      field :f4, :ref, :model => 'Hoge::FFour'
      field :f5, :reflist, :model => 'FFive'
    end
    Test06a.definition(:f1).should eql({:datatype => :bool, :default => false})
    Test06a.definition(:f2l).should eql({:datatype => :string, :length => 27})
    Test06a.definition(:f2s).should eql({:datatype => :string, :selector => ['X', 'Y', 'Z']})
    Test06a.definition(:f2v).should eql({:datatype => :string, :validator => 'ftwovalidator'})
    Test06a.definition(:f3).should eql({:datatype => :stringlist, :separator => "\n", :length => 1029})
    Test06a.definition(:ft).should eql({:datatype => :taglist, :empty => true})
    Test06a.definition(:f4).should eql({:datatype => :ref, :model => 'Hoge::FFour'})
    Test06a.definition(:f5).should eql({:datatype => :reflist, :model => 'FFive'})

    class Test06b < Stratum::Model
      field :g1, :bool, :default => true, :column => 'GGG1'
      field :g2l, :string, :length => 4099, :column => 'GGGGG2LLL', :empty => :allowed
      field :g2s, :string, :selector => ['1','2','3'], :column => 'G2SSS', :empty => :ok
      field :g2v, :string, :validator => 'hoge', :column => 'GGG2222VVV', :empty => :allowed
      field :g3, :stringlist, :separator => '-', :length => 100000, :column => 'GG333vvv', :empty => :ok
      field :g4, :ref, :model => 'G4', :column => 'g4', :empty => :allowed
      field :g5, :reflist, :model => 'Geee::G5', :column => 'g5_oids', :empty => :ok
    end
    Test06b.definition(:g1).should eql({:datatype => :bool, :default => true})
    Test06b.definition(:g2l).should eql({:datatype => :string, :length => 4099, :empty => true})
    Test06b.definition(:g2s).should eql({:datatype => :string, :selector => ['1','2','3'], :empty => true})
    Test06b.definition(:g2v).should eql({:datatype => :string, :validator => 'hoge', :empty => true})
    Test06b.definition(:g3).should eql({:datatype => :stringlist, :separator => '-', :length => 100000, :empty => true})
    Test06b.definition(:g4).should eql({:datatype => :ref, :model => 'G4', :empty => true})
    Test06b.definition(:g5).should eql({:datatype => :reflist, :model => 'Geee::G5', :empty => true})
  end

  it "に :empty を指定するときは :allowed/:ok のみ許可され、内部状態としては true に変換されること" do
    lambda {
      class Test06c < Stratum::Model
        field :h1, :string, :length => 20, :empty => :allowed
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    Test06c.definition(:h1)[:empty].should equal(true)

    lambda {
      class Test06d < Stratum::Model
        field :h2, :stringlist, :separator =>',', :length => 20, :empty => :ok
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    Test06d.definition(:h2)[:empty].should equal(true)
    
    lambda {
      class Test06e < Stratum::Model
        field :h3, :ref, :model => 'Model20', :empty => true
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に :bool は :default を要求すること" do
    lambda {
      class Test07a < Stratum::Model
        field :f71, :bool, :default => false
        field :f72, :bool, :default => true
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test07b < Stratum::Model
        field :f73, :bool
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に :bool は :empty を拒絶すること" do
    lambda {
      class Test08 < Stratum::Model
        field :f8, :bool, :default => true, :empty => :allowed
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に :string はvalidation用として :selector/:length/:validator のどれかを要求すること" do
    lambda {
      class Test09a < Stratum::Model
        field :f9, :string, :selector => ['a']
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test09b < Stratum::Model
        field :f9, :string, :length => 10
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test09c < Stratum::Model
        field :f9, :string, :validator => 'dummyfunc09'
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test09d < Stratum::Model
        field :f9, :string, :empty => :allowed
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に :stringlist は :separator および :length を要求すること" do
    lambda {
      class Test10a < Stratum::Model
        field :f10, :stringlist, :separator => ' ', :length => 10
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test10b < Stratum::Model
        field :f10, :stringlist, :separator => ' '
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test10a < Stratum::Model
        field :f10, :stringlist, :length => 10
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に :ref および :reflist は :model を要求すること" do
    lambda {
      class Test11a < Stratum::Model
        field :f1, :ref, :model => 'F1Model'
        field :f2, :reflist, :model => 'F2Model'
      end
    }.should_not raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test11b < Stratum::Model
        field :f1, :ref
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)

    lambda {
      class Test11c < Stratum::Model
        field :f2, :reflist
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
  end

  it "に :bool のフィールド定義により #fieldname #fieldname? #fieldname= の3メソッドが定義されること" do
    class Test12 < Stratum::Model
      field :efef, :bool, :default => true
    end
    Test12.public_instance_methods(true).should include(:efef)
    Test12.public_instance_methods(true).should include(:efef?)
    Test12.public_instance_methods(true).should include(:efef=)
  end

  it "に :string :stringlist および :taglist のフィールド定義により #fieldname #fieldname= の2メソッドが定義されること" do
    class Test13 < Stratum::Model
      field :ofof, :string, :length => 12, :empty => :allowed
      field :wfwf, :stringlist, :length => 1000, :separator => ' '
      field :efef, :taglist
    end
    Test13.public_instance_methods(true).should include(:ofof)
    Test13.public_instance_methods(true).should include(:ofof=)
    Test13.public_instance_methods(true).should include(:wfwf)
    Test13.public_instance_methods(true).should include(:wfwf=)
    Test13.public_instance_methods(true).should include(:efef)
    Test13.public_instance_methods(true).should include(:efef=)
  end

  it "に :ref および :reflist のフィールド定義により #fieldname #fieldname_by_id #fieldname= #fieldname_by_id= の4メソッドが定義されること" do
    class Test14 < Stratum::Model
      field :fff, :ref, :model => 'Moge'
      field :ggg, :reflist, :model => 'GGG', :empty => :allowed
    end
    Test14.public_instance_methods(true).should include(:fff)
    Test14.public_instance_methods(true).should include(:fff=)
    Test14.public_instance_methods(true).should include(:fff_by_id)
    Test14.public_instance_methods(true).should include(:fff_by_id=)
    Test14.public_instance_methods(true).should include(:ggg)
    Test14.public_instance_methods(true).should include(:ggg=)
    Test14.public_instance_methods(true).should include(:ggg_by_id)
    Test14.public_instance_methods(true).should include(:ggg_by_id=)
  end

  it "に :bool のフィールドがinitialize内で正常に :default で指定した値にセットされること" do
    class Test15 < Stratum::Model
      field :hoge, :bool, :default => true
      field :moge, :bool, :default => false
    end
    t15 = Test15.new
    t15.hoge.should be_true
    t15.moge.should be_false
  end

  it "に :bool のフィールドに対して true/false が代入可能で正しく読み出せること、および内部状態が正常にBOOL_TRUE/BOOL_FALSEにセットされること" do
    class Test16 < Stratum::Model
      field :val1, :bool, :default => false
      field :val2, :bool, :default => true
    end
    t16 = Test16.new
    t16.val1.should be_false
    t16.val2.should be_true
    t16.val1 = true
    t16.val2 = false
    t16.val1.should be_true
    t16.val2.should be_false
    t16.raw_values[Test16.column_by(:val1)].should equal(Stratum::Model::BOOL_TRUE)
    t16.raw_values[Test16.column_by(:val2)].should equal(Stratum::Model::BOOL_FALSE)
  end

  it "に :bool のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    class Test17 < Stratum::Model
      field :val1, :bool, :default => false
      field :val2, :bool, :default => true
    end
    t17 = Test17.new
    t17.sqlvalue(:val1).should eql('0')
    t17.sqlvalue(:val2).should eql('1')
  end

  it "に :string のフィールドに対して文字列が代入可能で正しく読み出せること、および内部状態が正常に文字列になっていること" do
    class Test18 < Stratum::Model
      field :val1, :string, :length => 10
      field :val2, :string, :selector => ['A']
    end
    t18 = Test18.new
    t18.val1 = "hogehoge"
    t18.val2 = 'A'
    t18.raw_values[Test18.column_by(:val1)].should eql("hogehoge")
    t18.raw_values[Test18.column_by(:val2)].should eql('A')
    t18.val1.should eql("hogehoge")
    t18.val2.should eql('A')
  end

  it "に :string のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    class Test19 < Stratum::Model
      field :val1, :string, :length => 20
    end
    t19 = Test19.new
    t19.val1 = "hogehoge pospos"
    t19.sqlvalue(:val1).should eql("hogehoge pospos")
  end

  it "に :string のvalidationで :selector が正常に働いていること" do
    lambda {
      class Test20a < Stratum::Model
        field :val, :string, :selector => []
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
    class Test20b < Stratum::Model
      field :val1, :string, :selector => ['1', '2', '3']
      field :val2, :string, :selector => ['1', '2', '3'], :empty => :allowed
    end
    t20b = Test20b.new
    lambda {t20b.val1 = '1'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val1 = '2'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val1 = '3'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val1 = '4'}.should raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val1 = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val1 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val2 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t20b.val2 = nil}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "に :string のvalidationで :length が正常に文字数として働いていること" do
    lambda {
      class Test21a < Stratum::Model
        field :val, :string, :length => 0
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test21b < Stratum::Model
        field :val, :string, :length => -1
      end
    }.should raise_exception(Stratum::InvalidFieldDefinition)
    
    lambda {
      class Test21c < Stratum::Model
        field :val, :string, :length => '10'
      end
    }.should raise_exception(ArgumentError)

    class Test21d < Stratum::Model
      field :val, :string, :length => 5
    end
    t21 = Test21d.new
    lambda {t21.val = 'aaaaa'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'a'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'aaaaaa'}.should raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'あああああ'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'あ'}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'ああああああ'}.should raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'あああああA'}.should raise_exception(Stratum::FieldValidationError)
    lambda {t21.val = 'ああああA'}.should_not raise_exception(Stratum::FieldValidationError)
  end

  it "に :string のvalidationで :validator が正常に働くこと" do
    class Test22a < Stratum::Model
      field :val, :string, :validator => 'checker'
      def checker(value)
        value =~ /\A[0-9]{1,20}\Z/
      end
    end
    class Test22b < Stratum::Model
      field :val, :string, :validator => 'checker'
      def checker(value)
        value =~ /\A[a-z]{1,20}\Z/
      end
    end
    number_str = "20100819"
    alphabet_str = "hogehogepospos"
    t22a = Test22a.new
    t22b = Test22b.new
    lambda {t22a.val = number_str}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t22b.val = alphabet_str}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t22a.val = alphabet_str}.should raise_exception(Stratum::FieldValidationError)
    lambda {t22b.val = number_str}.should raise_exception(Stratum::FieldValidationError)
  end

  it "に :string のvalidationで :empty の値が :ok/allowed の場合にのみ空文字列およびnilの代入を許し、内部状態が空文字列にセットされること" do
    class Test23a < Stratum::Model
      field :val1, :string, :length => 1
      field :val2, :string, :length => 1, :empty => :allowed
    end
    class Test23b < Stratum::Model
      field :val1, :string, :selector => ['1']
      field :val2, :string, :selector => ['1'], :empty => :allowed
    end
    class Test23c < Stratum::Model
      field :val1, :string, :validator => 'checker'
      field :val2, :string, :validator => 'checker', :empty => :allowed
      def checker(value)
        true
      end
    end

    t23a = Test23a.new
    lambda {t23a.val1 = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t23a.val1 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t23a.val2 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    t23a.raw_values[t23a.class.column_by(:val2)].should eql('')
    lambda {t23a.val2 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    t23a.raw_values[t23a.class.column_by(:val2)].should eql('')

    t23b = Test23b.new
    lambda {t23b.val1 = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t23b.val1 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t23b.val2 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    t23b.raw_values[t23b.class.column_by(:val2)].should eql('')
    lambda {t23b.val2 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    t23b.raw_values[t23b.class.column_by(:val2)].should eql('')

    t23c = Test23c.new
    lambda {t23c.val1 = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t23c.val1 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t23c.val2 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    t23c.raw_values[t23c.class.column_by(:val2)].should eql('')
    lambda {t23c.val2 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    t23c.raw_values[t23c.class.column_by(:val2)].should eql('')
  end

  it "に :string のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    class Test24 < Stratum::Model
      field :val, :string, :length => 200
    end
    t24 = Test24.new
    t24.val = "ほげほげ株式会社"
    t24.sqlvalue(:val).should eql("ほげほげ株式会社")
  end

  it "に :stringlist のフィールドに対して文字列のリストが代入可能で正しく読み出せること、および内部状態が正常にリストになっていること" do
    class Test25 < Stratum::Model
      field :val, :stringlist, :separator => "\t", :length => 1024
      field :val2, :stringlist, :separator => ' ', :length => 1024
    end
    t25 = Test25.new
    lambda {t25.val = ['HOGE', 'POS', "もげ"]}.should_not raise_exception(Stratum::FieldValidationError)
    t25.raw_values[t25.class.column_by(:val)].should eql(['HOGE', 'POS', 'もげ'])
    lambda {t25.val = ['HOGE', 'POS', "もげ"] * 200}.should raise_exception(Stratum::FieldValidationError)
    lambda {t25.val = 'HOGE'}.should_not raise_exception(Stratum::FieldValidationError)
    t25.raw_values[t25.class.column_by(:val)].should eql(['HOGE'])
    lambda {t25.val = 'HOGE' * 400}.should raise_exception(Stratum::FieldValidationError)
    lambda {t25.val = "HOGE\tPOS"}.should_not raise_exception(Stratum::FieldValidationError)
    t25.raw_values[t25.class.column_by(:val)].should eql(['HOGE', 'POS'])

    lambda {t25.val2 = "HOGE POS MOGE"}.should_not raise_exception(Stratum::FieldValidationError)
    t25.raw_values[t25.class.column_by(:val2)].should eql(['HOGE', 'POS', 'MOGE'])
  end

  it "に :stringlist のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    class Test26 < Stratum::Model
      field :val1, :stringlist, :separator => "\t", :length => 1024
      field :val2, :stringlist, :separator => "-", :length => 1024
    end
    t26 = Test26.new
    t26.val1 = ["A", "B", "C"]
    t26.val2 = ["A", "B", "C"]
    t26.sqlvalue(:val1).should eql("A\tB\tC")
    t26.sqlvalue(:val2).should eql("A-B-C")
  end

  it "に :stringlist のvalidationで :length が正常に文字数として働いていること" do
    class Test27 < Stratum::Model
      field :val, :stringlist, :separator => ' ', :length => 5
    end
    t27 = Test27.new
    lambda {t27.val = ['AA', 'BB']}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t27.val = ['AAA', 'BB']}.should raise_exception(Stratum::FieldValidationError)
    lambda {t27.val = ['ああ', 'BB']}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {t27.val = ['ああ', 'いBB']}.should raise_exception(Stratum::FieldValidationError)
  end

  it "に :stringlist のvalidationで :empty の値が :ok/allowed の場合にのみ空文字列、空リストおよびnilの代入を許し、内部状態が空リストにセットされること" do
    class Test28 < Stratum::Model
      field :val1, :stringlist, :separator => ',', :length => 512
      field :val2, :stringlist, :separator => ',', :length => 512, :empty => :allowed
      field :val3, :stringlist, :separator => ',', :length => 512, :empty => :ok
    end
    t28 = Test28.new
    lambda {t28.val1 = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t28.val1 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t28.val1 = []}.should raise_exception(Stratum::FieldValidationError)

    lambda {t28.val2 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    t28.raw_values[t28.class.column_by(:val2)].should eql([])
    lambda {t28.val2 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    t28.raw_values[t28.class.column_by(:val2)].should eql([])
    lambda {t28.val2 = []}.should_not raise_exception(Stratum::FieldValidationError)
    t28.raw_values[t28.class.column_by(:val2)].should eql([])
 
    lambda {t28.val3 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    t28.raw_values[t28.class.column_by(:val3)].should eql([])
    lambda {t28.val3 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    t28.raw_values[t28.class.column_by(:val3)].should eql([])
    lambda {t28.val3 = []}.should_not raise_exception(Stratum::FieldValidationError)
    t28.raw_values[t28.class.column_by(:val3)].should eql([])
  end

  it "に :taglist のフィールドに対して文字列のリストが代入可能で正しく読み出せること、および内部状態が正常にリストになっていること" do
    class Test30 < Stratum::Model
      field :val1, :taglist
    end
    t30 = Test30.new
    t30.val1 = ['hoge', 'hogemoge', 'hoge_pos', '日本語も', '日本語とASCIIが混ざったのも', 'ぜんぶOKデスカね?']
    t30.val1.should eql(['hoge', 'hogemoge', 'hoge_pos', '日本語も', '日本語とASCIIが混ざったのも', 'ぜんぶOKデスカね?'])

    t30.val1 = 'HOGE'
    t30.val1.should eql(['HOGE'])
  end

  it "に :taglist のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    class Test31 < Stratum::Model
      field :val1, :taglist
    end
    t31 = Test31.new
    t31.val1 = ['hoge', 'hogemoge', 'hoge_pos', '日本語も', '日本語とASCIIが混ざったのも', 'ぜんぶOKデスカね?']
    t31.sqlvalue(:val1).should eql(['hoge', 'hogemoge', 'hoge_pos', '日本語も', '日本語とASCIIが混ざったのも', 'ぜんぶOKデスカね?'].join(' '))
  end

  it "に :taglist のvalidationで :empty の値が :ok/allowed の場合にのみ空文字列、空リストおよびnilの代入を許し、内部状態が空リストにセットされること" do 
    class Test29 < Stratum::Model
      field :val1, :taglist
      field :val2, :taglist, :empty => :ok
    end
    t29 = Test29.new
    lambda {t29.val1 = ''}.should raise_exception(Stratum::FieldValidationError)
    lambda {t29.val1 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {t29.val1 = []}.should raise_exception(Stratum::FieldValidationError)

    lambda {t29.val2 = ''}.should_not raise_exception(Stratum::FieldValidationError)
    t29.raw_values[t29.class.column_by(:val2)].should eql([])
    lambda {t29.val2 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    t29.raw_values[t29.class.column_by(:val2)].should eql([])
    lambda {t29.val2 = []}.should_not raise_exception(Stratum::FieldValidationError)
    t29.raw_values[t29.class.column_by(:val2)].should eql([])
  end
end

# これより下では TestData をinstanciateして試す

describe Stratum::Model, "のオブジェクトへの基本的な操作を行うとき" do
  # initialize/raw_values/overwrite/id/oid/.../updatable?/saved?

  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
    Stratum.operator_model(AuthInfo)
    Stratum.current_operator(AuthInfo.query(:name => "tagomoris", :unique => true))
  end

  before do
    @conn = Stratum::Connection.new()
  end

  after do
    @conn.close()
  end

  it "に .new 後に各フィールドの内部状態は正しく初期化されていること" do
    ex1 = TestEX1.new
    ex1.raw_values.size.should eql(0)
    ex1.saved?.should be_false
    ex1.updatable?.should be_true
    ex1.instance_eval{@pre_update_id}.should be_nil

    ex2 = TestEX2.new
    ex2.raw_values.size.should eql(0)
    ex2.saved?.should be_false
    ex2.updatable?.should be_true
    ex2.instance_eval{@pre_update_id}.should be_nil
  end
  
  it "に .new 後の状態で :default 指定のあるフィールドは正しくセットされていること" do
    ai = AuthInfo.new
    ai.raw_values.size.should eql(1)
    ai.raw_values['valid'].should eql(Stratum::Model::BOOL_TRUE)
    ai.valid.should be_true
    ai.valid?.should be_true
    ai.saved?.should be_false
    ai.updatable?.should be_true
    ai.instance_eval{@pre_update_id}.should be_nil

    td = TestData.new
    td.raw_values.size.should eql(3)
    td.raw_values['flag1'].should eql(Stratum::Model::BOOL_TRUE)
    td.raw_values['flag2'].should eql(Stratum::Model::BOOL_FALSE)
    td.flag1.should be_true
    td.flag2.should be_false
    td.raw_values['string2'].should eql('OPT2')
    td.string2.should eql('OPT2')
  end

  it "に .new にカラム名と値ペアをもったハッシュを与えると内部状態にセットされること、およびそれは :default 指定を上書きすること" do
    td = TestData.new(
                      {
                        'flag1' => Stratum::Model::BOOL_FALSE,
                        'string1' => 'HOGE',
                        'string2' => 'OPT3',
                        'list1' => "1\t2",
                        'id' => 1024,
                        'oid' => 512,
                        'inserted_at' => Mysql::Time.new,
                        'operated_by' => 0,
                        'head' => Stratum::Model::BOOL_TRUE,
                        'removed' => Stratum::Model::BOOL_FALSE
                      })
    td.raw_values['flag1'].should eql(Stratum::Model::BOOL_FALSE)
    td.flag1.should be_false
    td.raw_values['string1'].should eql('HOGE')
    td.string1.should eql('HOGE')
    td.raw_values['string2'].should eql('OPT3')
    td.string2.should eql('OPT3')
    td.raw_values['list1'].should eql(['1','2'])
    td.list1.should eql(['1','2'])
    
    tt = TestTag.new(
                     {
                       'tags' => "HOGE POS MOGE",
                       'id' => 1025,
                       'oid' => 513,
                       'inserted_at' => Mysql::Time.new,
                       'operated_by' => 0,
                       'head' => Stratum::Model::BOOL_TRUE,
                       'removed' => Stratum::Model::BOOL_FALSE
                     })
    tt.raw_values['tags'].should eql(['HOGE', 'POS', 'MOGE'])
    tt.tags.should eql(['HOGE', 'POS', 'MOGE'])
  end

  it "に #sqlvaule で各フィールドのデータのSQL表現が取り出せること" do
    td = TestData.new
    td.flag1 = false
    td.string1 = "string1string1"
    td.text = nil
    td.list1 = []
    td.list2 = ['hoge', 'pos', 'moge']
    td.list3 = ['hoge', nil, 'moge']
    td.testex1_by_id = 10
    td.testex2s_by_id = [1,2,3,4]

    td.sqlvalue(:flag1).should eql(Stratum::Model::BOOL_FALSE)
    td.sqlvalue(:string1).should eql('string1string1')
    td.sqlvalue(:text).should eql('')
    td.sqlvalue(:list1).should eql('')
    td.sqlvalue(:list2).should eql("hoge\tpos\tmoge")
    td.sqlvalue(:list3).should eql("hoge,,moge")
    td.sqlvalue(:testex1).should eql(10)
    td.sqlvalue(:testex2s).should eql("1,2,3,4")

    tt = TestTag.new
    tt.tags = ['HOGE', 'POS', '20100825-14:41']
    tt.sqlvalue(:tags).should eql("HOGE POS 20100825-14:41")
  end
  
  it "に .sqlvalue で読み出したデータが正常に .rawvalue で内部表現に戻せること" do
    td = TestData.new
    td.flag1 = false
    td.string1 = "string1string1"
    td.text = nil
    td.list1 = []
    td.list2 = ['hoge', 'pos', 'moge']
    td.list3 = 'hoge'
    td.testex1_by_id = 10
    td.testex2s_by_id = [1,2,3,4]

    TestData.rawvalue(TestData.datatype(:flag1), TestData.definition(:flag1), td.sqlvalue(:flag1)).should eql(td.raw_values[TestData.column_by(:flag1)])
    TestData.rawvalue(TestData.datatype(:string1), TestData.definition(:string1), td.sqlvalue(:string1)).should eql(td.raw_values[TestData.column_by(:string1)])
    TestData.rawvalue(TestData.datatype(:text), TestData.definition(:text), td.sqlvalue(:text)).should eql(td.raw_values[TestData.column_by(:text)])
    TestData.rawvalue(TestData.datatype(:list1), TestData.definition(:list1), td.sqlvalue(:list1)).should eql(td.raw_values[TestData.column_by(:list1)])
    TestData.rawvalue(TestData.datatype(:list2), TestData.definition(:list2), td.sqlvalue(:list2)).should eql(td.raw_values[TestData.column_by(:list2)])
    TestData.rawvalue(TestData.datatype(:list3), TestData.definition(:list3), td.sqlvalue(:list3)).should eql(td.raw_values[TestData.column_by(:list3)])
    TestData.rawvalue(TestData.datatype(:testex1), TestData.definition(:testex1), td.sqlvalue(:testex1)).should eql(td.raw_values[TestData.column_by(:testex1)])
    TestData.rawvalue(TestData.datatype(:testex2s), TestData.definition(:testex2s), td.sqlvalue(:testex2s)).should eql(td.raw_values[TestData.column_by(:testex2s)])

    tt = TestTag.new
    tt.tags = ['HOGE', 'POS', '20100825-14:41', 'サーバ', 'Webサーバ']
    TestTag.rawvalue(TestTag.datatype(:tags), TestTag.definition(:tags), tt.sqlvalue(:tags)).should eql(tt.raw_values[TestTag.column_by(:tags)])
  end
  
  it "に #overwrite で他オブジェクトの内部表現値が正しく上書きされ、保存済みオブジェクトのフラグ(saved=trueなど)がセットされること" do
    @conn.query("INSERT INTO testtable SET id=1777,oid=17770,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11'")
    td1 = TestData.get(17770)
    td2 = TestData.new
    td2.overwrite(td1)

    td2.raw_values['id'].should eql(1777)
    td2.raw_values['oid'].should eql(17770)
    td2.raw_values['flag1'].should eql('1')
    td2.raw_values['flag2'].should eql('0')
    td2.raw_values['string1'].should eql('hoge1')
    td2.raw_values['string3'].should eql('000')
    td2.raw_values['list2'].should eql(['HOGE'])
    td2.raw_values['ref_oid'].should eql(10)
    td2.raw_values['testex1_oids'].should eql([11])

    @conn.query("INSERT INTO testtags SET id=1050,oid=171,tags='ほげ サーバ1 もうWebサーバって書くの飽きてきた 20100825-14:52'")
    tt1 = TestTag.get(171)
    tt2 = TestTag.new
    tt2.overwrite(tt1)
    tt2.raw_values['tags'].should eql(['ほげ','サーバ1', 'もうWebサーバって書くの飽きてきた', '20100825-14:52'])
  end

  it "に、保存済みの場合は #id でid値(Integer)がとれ、未保存の場合は nil となること" do
    @conn.query("INSERT INTO testtable SET id=1778,oid=17771,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11'")
    td1 = TestData.get(17771)
    td1.id.should eql(1778)
    td2 = TestData.new
    td2.id.should be_nil
  end

  it "に、既存オブジェクトの場合は #oid でoid値(Integer)がとれ、新オブジェクトの場合は nil となること" do
    @conn.query("INSERT INTO testtable SET id=1779,oid=17772,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11'")
    td1 = TestData.get(17772)
    td1.oid.should eql(17772)
    td2 = TestData.new
    td2.oid.should be_nil
  end
  
  it "に、保存済みの場合は #inserted_at でタイムスタンプが取得でき、未保存の場合は nil となること" do
    @conn.query("INSERT INTO testtable SET id=1780,oid=17801,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11'")
    td1 = TestData.get(17801)
    td1.inserted_at.should_not be_nil
    td2 = TestData.new
    td2.inserted_at.should be_nil
  end

  it "に、保存済みの場合は #operated_by_id および #operated_by で操作ユーザのoidおよびAuthInfoオブジェクトが取得でき、未保存の場合は nil となること" do
    @conn.query("INSERT INTO testtable SET id=1781,oid=17811,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11', operated_by=1")
    td1 = TestData.get(17811)
    td1.operated_by_oid.should eql(1)
    td1.operated_by.name.should eql("tagomoris")
    td2 = TestData.new
    td2.operated_by_oid.should be_nil
    td2.operated_by.should be_nil
  end

  it "に、予約済みフィールド :head のBOOL_TRUE/BOOL_FALSEにしたがって true/false が得られること" do
    @conn.query("INSERT INTO testtable SET id=1782,oid=17821,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11',operated_by=1")
    @conn.query("INSERT INTO testtable SET id=1783,oid=17831,flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11',operated_by=1")
    @conn.query("UPDATE testtable SET head='0' WHERE id=1783")
    td1 = TestData.get(17821)
    td2 = TestData.new(@conn.query('SELECT * FROM testtable WHERE id=1783').fetch_hash())
    td1.head.should be_true
    td2.head.should be_false
  end
  
  it "に、予約済みフィールド :removed のBOOL_TRUE/BOOL_FALSEにしたがって true/false が得られること" do
    default_data_set = "flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11',operated_by=1"
    @conn.query("INSERT into testtable SET id=1784,oid=17841,#{default_data_set},head='1',removed='0'")
    @conn.query("INSERT into testtable SET id=1785,oid=17851,#{default_data_set},head='1',removed='1'")
    @conn.query("INSERT into testtable SET id=1786,oid=17861,#{default_data_set}")
    td1 = TestData.get(17841)
    td2r = TestData.get(17851)
    td2r.should be_nil
    td2 = TestData.get(17851, :force_all => true)
    td1.removed.should be_false
    td2.removed.should be_true

    td3 = TestData.get(17861)
    td3.removed.should be_false
  end

  it "に #updatable? は head が true かつ removed が false の場合にのみ true を返し、それ以外の場合には false を返すこと" do
    default_data_set = "flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11',operated_by=1"
    @conn.query("INSERT into testtable SET id=1787,oid=17871,#{default_data_set},head='1',removed='0'")
    @conn.query("INSERT into testtable SET id=1788,oid=17881,#{default_data_set},head='1',removed='1'")
    @conn.query("INSERT into testtable SET id=1789,oid=17891,#{default_data_set},head='0',removed='0'")
    @conn.query("INSERT into testtable SET id=1790,oid=17901,#{default_data_set},head='0',removed='1'")
    td1 = TestData.get(17871, :before => Time.now + 86400, :force_all => true)
    td2 = TestData.get(17881, :before => Time.now + 86400, :force_all => true)
    td3 = TestData.get(17891, :before => Time.now + 86400, :force_all => true)
    td4 = TestData.get(17901, :before => Time.now + 86400, :force_all => true)
    td1.should_not be_nil
    td1.updatable?.should be_true
    td2.should_not be_nil
    td2.updatable?.should be_false
    td3.should_not be_nil
    td3.updatable?.should be_false
    td4.should_not be_nil
    td4.updatable?.should be_false
  end

  it "に .query から得た既存オブジェクトは #saved? で true を返し、値の更新後は false を返すこと、また #save のあとは true となること" do
    default_data_set = "flag1='1',flag2='0',string1='hoge1',string3='000',list2='HOGE',ref_oid=10,testex1_oids='11',operated_by=1"
    @conn.query("INSERT into testtable SET id=1791,oid=17911,#{default_data_set},head='1',removed='0'")
    td = TestData.get(17911)
    td.saved?.should be_true

    td.flag1 = false
    td.saved?.should be_false

    result = td.save
    td.should_not be_nil
    result.should_not be_nil
    
    td.saved?.should be_true
  end
  
  it "に .new から得た新規オブジェクトは #saved? で false を返し、値の更新後も変わらないが、 #save のあとは true となること" do
    td = TestData.new
    td.saved?.should be_false

    td.flag1 = true
    td.saved?.should be_false

    td.flag2 = false
    td.string1 = 'hoge'
    td.string3 = '000'
    td.list2 = 'HOGE'
    td.testex1_by_id = 10
    td.testex2s_by_id = 11
    td.saved?.should be_false

    result = td.save
    result.should_not be_nil
    td.saved?.should be_true
  end

  after(:all) do
    TestDatabase.drop()
  end
end

describe Stratum::Model, "のオブジェクトに対してデータ操作するとき" do
  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
    Stratum.operator_model(AuthInfo)
    Stratum.current_operator(AuthInfo.query(:name => "tagomoris", :unique => true))
  end

  before do
    @conn = Stratum::Connection.new()
  end

  after do
    @conn.close()
  end

  # behavior of getter/setter and validators(:strict) of ref/reflist
  it "に :ref のフィールドに対して #NAME_by_id=() でoidが代入でき、 #NAME_by_id で正しく読み出せること" do
    td = TestData.new
    td.testex1_by_id = 9999
    td.testex1_by_id.should eql(9999)
  end
  
  it "に :ref のフィールドに対して :model で指定したclassのオブジェクトが代入可能で正しく読み出せること、および内部状態が oid にセットされること" do 
    tex1 = TestEX1.new
    tex1.name = "hoge273"
    tex1.save()
    tex1.oid.should_not be_nil

    td = TestData.new
    td.testex1 = tex1
    td.testex1.name.should eql("hoge273")
    td.raw_values['ref_oid'].should eql(tex1.oid)
  end
  
  it "に :ref のvalidationで :strict がセットされていないとき、実際には存在しないoidを代入しても例外が発生しないこと" do
    td = TestData.new
    lambda {td.testex1_by_id = 9989}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に :ref のvalidationで :strict => true がセットされているとき、 実際には存在しないoidのオブジェクトを代入したときに例外が発生すること" do 
    td = TestData.new
    lambda {td.testex2_by_id = 9989}.should raise_exception(Stratum::FieldValidationError)
    tex2 = TestEX2.new
    tex2.name = "hoge274"
    tex2.save
    lambda {td.testex2_by_id = tex2.oid}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に :ref のvalidationで :empty の値が :ok/allowed の場合にのみnilの代入を許し、内部状態がnilにセットされること" do
    td = TestData.new
    lambda {td.testex1 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {td.testex1_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {td.testex1 = nil}.should_not raise_exception(Stratum::FieldValidationError)
    td.raw_values['ref_oid'].should be_nil
    lambda {td.testex2 = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {td.testex2_by_id = nil}.should raise_exception(Stratum::FieldValidationError)
  end
  
  it "に :ref のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    tex1 = TestEX1.new
    tex1.name = "hoge275"
    tex1.save()
    tex2 = TestEX2.new
    tex2.name = "hoge276"
    tex2.save()

    td = TestData.new
    td.testex1 = tex1
    td.testex2 = tex2
    td.sqlvalue(:testex1).should eql(tex1.oid)
    td.sqlvalue(:testex2).should eql(tex2.oid)
  end
  
  it "に :reflist のフィールドに対して #NAME_by_id=() でoidのリストが代入でき、 #NAME_by_id で正しく読み出せること" do
    td = TestData.new
    td.testex2s_by_id = [1024,1025,1026,1027]
    td.testex2s_by_id.should eql([1024,1025,1026,1027])
  end

  it "に :reflist のフィールドに対して :model で指定したclassのオブジェクトが代入可能で正しく読み出せること、および内部状態が oid のリストにセットされること" do
    tex11 = TestEX1.new
    tex11.name = "hoge1024"
    tex11.save
    tex12 = TestEX1.new
    tex12.name = "hoge1025"
    tex12.save
    tex13 = TestEX1.new
    tex13.name = "hoge1026"
    tex13.save

    td = TestData.new
    
    td.testex1s = tex11
    td.raw_values['testex1_oids'].should eql([tex11.oid])

    td.testex1s = [tex11, tex12, tex13]
    td.raw_values['testex1_oids'].should eql([tex11.oid, tex12.oid, tex13.oid])
  end
  
  it "に :reflist のvalidationで :strict がセットされていないとき、実際には存在しないoidのオブジェクトを含むリストを代入しても例外が発生しないこと" do
    td = TestData.new
    lambda {td.testex2s_by_id = [9919, 9929, 19929]}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に :reflist のvalidationで :strict => true がセットされているとき、 実際には存在しないoidのオブジェクトを含むリストを代入したときに例外が発生すること" do
    td = TestData.new
    lambda {td.testex1s_by_id = [9919, 9929, 19929]}.should raise_exception(Stratum::FieldValidationError)

    tex11 = TestEX1.new
    tex11.name = "hoge9919"
    tex11.save
    tex12 = TestEX1.new
    tex12.name = "hoge9929"
    tex12.save
    tex13 = TestEX1.new
    tex13.name = "hoge19929"
    tex13.save
    lambda {td.testex1s_by_id = [tex11.oid, tex12.oid, tex13.oid]}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に :reflist のvalidationで :empty の値が :ok/allowed の場合にのみ空リストもしくはnilの代入を許し、内部状態が空リストにセットされること" do
    td = TestData.new
    lambda {td.testex1s = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {td.testex1s_by_id = nil}.should raise_exception(Stratum::FieldValidationError)
    lambda {td.testex1s = []}.should raise_exception(Stratum::FieldValidationError)
    lambda {td.testex1s_by_id = []}.should raise_exception(Stratum::FieldValidationError)

    lambda {td.testex2s = nil}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {td.testex2s_by_id = nil}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {td.testex2s = []}.should_not raise_exception(Stratum::FieldValidationError)
    lambda {td.testex2s_by_id = []}.should_not raise_exception(Stratum::FieldValidationError)
  end
  
  it "に :reflist のフィールドに格納された値が #sqlvalue(fname) メソッドで正しく出力できること" do
    td = TestData.new
    td.testex2s_by_id = [5,6,8,9]
    td.sqlvalue(:testex2s).should eql('5,6,8,9')
  end

  after(:all) do
    TestDatabase.drop()
  end
end

describe Stratum::Model, "のオブジェクトのデータを保存するとき" do
  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
    Stratum.operator_model(AuthInfo)
    Stratum.current_operator(AuthInfo.query(:name => "tagomoris", :unique => true))
  end

  before do
    @conn = Stratum::Connection.new()

    @td = TestData.new
    @td.flag1 = true
    @td.flag2 = false
    @td.string1 = 'hoge'
    @td.string3 = '000'
    @td.list2 = 'HOGE'
    @td.testex1_by_id = 10
    @td.testex2s_by_id = [11]
  end

  after do
    @conn.close()
  end

  after(:all) do
    TestDatabase.drop()
  end
  # behavior of insert/update_unheadnize/save/remove

  it "に #insert 呼び出しで oid がセットされておらず引数でも与えられていない場合、例外が発生すること" do
    lambda {@td.insert()}.should raise_exception(Stratum::FieldValidationError)
  end

  it "に #insert 呼び出しで必ず id と inserted_at にはDBの自動挿入によるものがセットされること" do
    @td.raw_values['id'] = 50940
    now = Time.now
    now_my = Mysql::Time.new(now.year, now.month, now.day + 1, now.hour, now.min, now.sec)
    @td.raw_values['inserted_at'] = now_my

    @td.insert(:oid => 1024)
    @td.id.should_not be_nil
    @td.id.should_not eql(50940)
    @td.inserted_at.should_not be_nil
    @td.inserted_at.should_not eql(now_my)
  end
  
  it "に #insert 呼び出しで必ず operated_by には Stratum.current_operator() でセットされた oid がセットされること" do
    @td.operated_by.should be_nil
    @td.insert(:oid => 1025)
    @td.operated_by.name.should eql("tagomoris")
  end
  
  it "に #insert 呼び出しで必ず head は BOOL_TRUE がセットされること" do
    @td.insert(:oid => 1026)
    @td.raw_values['head'].should eql(Stratum::Model::BOOL_TRUE)
  end
  
  it "に #insert 呼び出しで removed は :removed => true が指定された場合にのみ BOOL_TRUE にセットされること" do
    td2 = TestData.new
    td2.overwrite(@td)

    @td.insert(:oid => 1027)
    @td.raw_values['removed'].should eql(Stratum::Model::BOOL_FALSE)
    td2.insert(:oid => 1028, :removed => true)
    td2.raw_values['removed'].should eql(Stratum::Model::BOOL_TRUE)
  end

  it "に #insert 呼び出しで内部状態のデータが正しくINSERTされること" do
    prehash = @td.raw_values.dup
    @td.insert(:oid => 1029)
    td = TestData.get(1029)
    posthash = {}
    rv = td.raw_values
    for k in rv.keys
      next if Stratum::Model::RESERVED_FIELDS.include?(TestData.field_by(k))
      next if rv[k].nil? or rv[k] == '' or rv[k] == []
      posthash[k] = rv[k]
    end
    posthash.should eql(prehash)
  end

  it "に .update_unheadnize で指定された id のレコードでは head が BOOL_FALSE にセットされて更新されること" do
    @td.insert(:oid => 1030)
    @td.id.should_not be_nil
    @td.head.should be_true
    tdid = @td.id
    TestData.update_unheadnize(tdid)
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{tdid}").fetch_row.first.should eql(Stratum::Model::BOOL_FALSE)
  end

  it "に oid のセットされていないオブジェクトを #save すると、新しい oid がセットされてINSERTされること" do
    @td.oid.should be_nil
    @td.save
    @td.oid.should_not be_nil
    newoid = @td.oid
    TestData.get(newoid).should_not be_nil
  end
  
  it "に saved が true なオブジェクトを #save してもDBには何もINSERTされないこと" do
    @td.save
    @td.saved?.should be_true
    count = @conn.query("SELECT count(*) FROM #{TestData.tablename}").fetch_row.first
    @td.save
    @conn.query("SELECT count(*) FROM #{TestData.tablename}").fetch_row.first.should eql(count)
  end
  
  it "に #updatable? が false なオブジェクトを #save すると例外が発生すること" do
    @td.save
    toid = @td.oid
    TestData.update_unheadnize(@td.id)
    td1 = TestData.new(@conn.query("SELECT * FROM #{TestData.tablename} WHERE oid=#{toid}").fetch_hash)
    td1.updatable?.should be_false
    lambda {td1.save}.should raise_exception(Stratum::InvalidUpdateError)
  end

  it "に #save されるオブジェクトのもつoidについて、実際にはレコードが存在しない場合には例外が発生しINSERTが行われないこと" do
    TestData.get(1031).should be_nil
    @td.raw_values['oid'] = 1031
    lambda {@td.save()}.should raise_exception(Stratum::InvalidUpdateError)
  end
  
  it "に #save されるオブジェクトのもつoidについて、他から既に更新が入っていた場合には例外が発生しINSERTが行われないこと" do
    @td.save
    toid = @td.oid

    tdx = TestData.get(toid)
    tdx.string2 = TestData::OPTS[2]
    tdx.save

    @td.string1 = "pepepepepe"
    lambda {@td.save()}.should raise_exception(Stratum::ConcurrentUpdateError)
  end

  it "に、トランザクションを使用した処理から例外が発生する条件で #save を行ったとき #save 呼び出し前の処理もまとめてロールバックされること" do
    @td.save

    tdx = TestData.get(@td.oid)
    tdx.string2 = TestData::OPTS[0]
    tdx.save

    tex1count = @conn.query("SELECT count(*) FROM #{TestEX1}").fetch_row.first
    begin
      Stratum.transaction do |conn|
        ex1 = TestEX1.new
        ex1.name = "mamamamamamamamama"
        ex1.save
        true.should be_true ## pass through check

        @td.text = "hogemogekogehage"
        @td.save
      end
    rescue Stratum::ConcurrentUpdateError
      # shake
    end
    @conn.query("SELECT count(*) FROM #{TestEX1}").fetch_row.first.should eql(tex1count)
  end

  it "に oid のセットされているオブジェクトを #save すると、直前にheadだったレコードがheadでなくなり、新しいレコードがheadとしてINSERTされること" do
    @td.save
    preid = @td.id
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{preid}").fetch_row.first.should eql(Stratum::Model::BOOL_TRUE)

    @td.text = "hehehehehehehehehehe"
    @td.save
    postid = @td.id
    postid.should_not eql(preid)
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{preid}").fetch_row.first.should eql(Stratum::Model::BOOL_FALSE)
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{postid}").fetch_row.first.should eql(Stratum::Model::BOOL_TRUE)
  end

  it "に saved? が false のオブジェクトを #remove すると例外が発生すること" do
    @td.saved?.should be_false
    lambda {@td.remove()}.should raise_exception(Stratum::InvalidUpdateError)
    @td.save
    lambda {@td.remove()}.should_not raise_exception(Stratum::InvalidUpdateError)
  end
  
  it "に updatable? が false のオブジェクトを #remove すると例外が発生すること" do
    @td.save
    toid = @td.oid
    TestData.update_unheadnize(@td.id)
    td1 = TestData.new(@conn.query("SELECT * FROM #{TestData.tablename} WHERE oid=#{toid}").fetch_hash)
    td1.updatable?.should be_false

    lambda {td1.remove()}.should raise_exception(Stratum::InvalidUpdateError)
  end
  
  it "に oid がセットされていないオブジェクトを #remove すると例外が発生すること" do
    td = TestData.new
    lambda {td.remove()}.should raise_exception(Stratum::InvalidUpdateError)
  end
  
  it "に #remove されるオブジェクトのもつoidについて、実際にはレコードが存在しない場合には例外が発生しINSERT(removed=BOOL_TRUE)が行われないこと" do
    TestData.get(1041).should be_nil
    @td.raw_values['oid'] = 1041
    lambda {@td.remove()}.should raise_exception(Stratum::InvalidUpdateError)
  end
  
  it "に #remove されるオブジェクトのもつoidについて、他から既に更新が入っていた場合には例外が発生しINSERT(removed=BOOL_TRUE)が行われないこと" do
    @td.save

    tdx = TestData.get(@td.oid)
    tdx.flag1 = false
    tdx.save

    lambda {@td.remove()}.should raise_exception(Stratum::ConcurrentUpdateError)
  end
  
  it "に、トランザクションを使用した処理から例外が発生する条件で #remove を行ったとき #remove 呼び出し前の処理もまとめてロールバックされること" do
    @td.save

    tdx = TestData.get(@td.oid)
    tdx.flag1 = false
    tdx.save

    tex1count = @conn.query("SELECT count(*) FROM #{TestEX1}").fetch_row.first
    begin
      Stratum.transaction do |conn|
        ex1 = TestEX1.new
        ex1.name = "wewewewewewewewewewewewew"
        ex1.save
        true.should be_true ## pass through check

        @td.remove
      end
    rescue Stratum::ConcurrentUpdateError
      # shake
    end
    @conn.query("SELECT count(*) FROM #{TestEX1}").fetch_row.first.should eql(tex1count)
  end

  it "に oid のセットされているオブジェクトを #remove すると、直前にheadだったレコードがheadでなくなり、新しいレコードがheadとしてINSERTされること" do
    @td.save
    toid = @td.oid
    preid = @td.id
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{preid}").fetch_row.first.should eql(Stratum::Model::BOOL_TRUE)

    @td.remove
    tdx = TestData.get(toid, :force_all => true)
    tdx.removed.should be_true
    postid = tdx.id
    postid.should_not eql(preid)
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{preid}").fetch_row.first.should eql(Stratum::Model::BOOL_FALSE)
    @conn.query("SELECT head FROM #{TestData.tablename} WHERE id=#{postid}").fetch_row.first.should eql(Stratum::Model::BOOL_TRUE)
  end
end

# insert from xmodel_spec.rb
describe Stratum::Model, "によってDB操作を行うとき" do
  # behavior of prepare_to_update, get/retrospect/query/query_or_create
  # :before => true でget(retrospect)したときに ref/reflist のoidオブジェクトの取得も :before つきで行うこと

  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
    Stratum.operator_model(AuthInfo)
    Stratum.current_operator(AuthInfo.query(:name => "tagomoris", :unique => true))
  end

  before do
    @conn = Stratum::Connection.new()

    @td = TestData.new
    @td.flag1 = true
    @td.flag2 = false
    @td.string1 = 'hoge'
    @td.string3 = '000'
    @td.list2 = 'HOGE'
    @td.testex1_by_id = 10
    @td.testex2s_by_id = [11]
  end

  after do
    @conn.close()
  end

  after(:all) do
    TestDatabase.drop()
  end

  it "に #saved? が false なオブジェクトに対して #prepare_to_update しても内部状態が何も変わらないこと" do
    td = TestData.new
    td.flag2 = true
    td.string1 = "hogemoge"
    td.list1 = nil
    td.list2 = ["hoge","moge"]
    pre = td.raw_values.dup
    td.prepare_to_update()
    td.raw_values.should eql(pre)
  end
  
  it "に #updatable? が false なオブジェクトに対して #prepare_to_update すると例外が発生すること" do
    @td.save()
    TestData.update_unheadnize(@td.id)
    pretd = TestData.new(@conn.query("SELECT * FROM #{TestData.tablename} WHERE id=#{@td.id}").fetch_hash)
    lambda {pretd.prepare_to_update()}.should raise_exception(Stratum::InvalidUpdateError)
  end
  
  it "に #prepare_to_update すると :oid 以外のすべての予約済みフィールドの内部状態値が削除されること" do
    @td.save()
    td = TestData.get(@td.oid)
    td.prepare_to_update()
    raw = td.raw_values()
    raw['id'].should be_nil
    raw['oid'].should_not be_nil
    raw['inserted_at'].should be_nil
    raw['operated_by'].should be_nil
    raw['head'].should be_nil
    raw['removed'].should be_nil
  end
  
  it "に #prepare_to_update すると、すべてのユーザ定義値がコピーされること" do
    ex1a = TestEX1.query_or_create(:name => "ex1nameA")
    ex1b = TestEX1.query_or_create(:name => "ex1nameB")
    ex2a = TestEX2.query_or_create(:name => "ex2")
    @td.string2 = 'OPT3'
    @td.list1 = []
    @td.list3 = ['1','2','4']
    @td.testex1 = ex1a
    @td.testex2 = ex2a
    @td.testex1s = [ex1b, ex1a]
    @td.testex2s_by_id = [ex2a.oid]
    @td.save()
    td = TestData.get(@td.oid)
    preraw = td.raw_values
    td.prepare_to_update()
    postraw = td.raw_values

    postraw.object_id.should_not eql(preraw.object_id)
    keys = TestData.columns
    for k in keys
      next if Stratum::Model::RESERVED_FIELDS.include?(TestData.field_by(k))
      postraw[k].should eql(preraw[k])
    end
  end

  it "に oid ひとつのみを引数に .get し、その oid のレコードが実際には存在しない場合 nil が返ること" do
    toid = 10278
    @conn.query("SELECT count(*) FROM #{TestData.tablename} WHERE oid=#{toid}").fetch_row.first.should eql("0")
    TestData.get(toid).should be_nil
  end
  
  it "に oid ひとつのみを引数に .get し、その oid のレコードが存在して removed フラグが立っていない場合 head のオブジェクトひとつのみが返ること" do
    @td.save()
    ret = @conn.query("SELECT head,removed FROM #{TestData.tablename} WHERE oid=#{@td.oid}")
    ret.num_rows().should eql(1)
    ret.fetch_row().should eql([Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_FALSE])

    td = TestData.get(@td.oid)
    td.should be_instance_of(TestData)
    td.oid.should eql(@td.oid)
  end
  
  it "に oid ひとつのみを引数に .get し、その oid のレコードが存在して removed フラグが立っている場合 nil が返ること" do
    @td.save()
    toid = @td.oid
    @td.remove()
    ret = @conn.query("SELECT head,removed FROM #{TestData.tablename} WHERE oid=#{toid} ORDER BY id DESC LIMIT 1")
    ret.num_rows().should eql(1)
    ret.fetch_row().should eql([Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_TRUE])

    td = TestData.get(toid)
    td.should be_nil
  end
  
  it "に oid ひとつと :force_all => true を引数に .get したとき removed フラグが立っている oid でも head オブジェクトひとつが返ること" do
    @td.save()
    toid = @td.oid
    @td.remove()
    ret = @conn.query("SELECT head,removed FROM #{TestData.tablename} WHERE oid=#{toid} ORDER BY id DESC LIMIT 1")
    ret.num_rows().should eql(1)
    ret.fetch_row().should eql([Stratum::Model::BOOL_TRUE, Stratum::Model::BOOL_TRUE])

    td = TestData.get(toid, :force_all => true)
    td.should_not be_nil
    td.should be_instance_of(TestData)
    td.oid.should eql(toid)
  end
  
  it "に oid ひとつと :before => anytime を引数に .get したとき removed フラグの立っていない、かつ anytime より前で最新のオブジェクトひとつが返ること" do
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=50,testex1_oids='51,52',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=10279,head='0',removed='0',#{vals}")
    first_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-19 23:00:50',oid=10279,head='0',removed='0',#{vals}")
    second_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-23 09:01:00',oid=10279,head='1',removed='0',#{vals}")
    third_id = @conn.insert_id()

    td = TestData.get(10279, :before => Mysql::Time.new(2010, 8, 21))
    td.should_not be_nil
    td.should be_instance_of(TestData)
    td.id.should eql(second_id)
    td.head.should be_false
    
    td = TestData.get(10279, :before => Mysql::Time.new(2010, 9, 25))
    td.should_not be_nil
    td.should be_instance_of(TestData)
    td.id.should eql(third_id)
    td.head.should be_true
  end
  
  it "に oid ひとつと :before => anytime を引数に .get したとき anytime より前にオブジェクトが存在しない場合は nil が返ること" do
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=50,testex1_oids='51,52',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=10280,head='0',removed='0',#{vals}")
    first_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-19 23:00:50',oid=10280,head='0',removed='0',#{vals}")
    second_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-23 09:01:00',oid=10280,head='1',removed='0',#{vals}")
    third_id = @conn.insert_id()

    td = TestData.get(10279, :before => Time.local(2010,8,15))
    td.should be_nil
  end

  it "に :before => anytime オプションつきで .get したオブジェクトの :ref フィールドからオブジェクトを取得したとき anytime 以前のものが返ること" do
    tdoid = 10281
    ex1aoid = 50
    ex1boid = 51
    ex1coid = 52
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=#{ex1aoid},testex1_oids='#{ex1boid},#{ex1coid}',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid},head='0',removed='0',#{vals}")
    td_1st_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{ex1aoid},head='0',removed='0',name='ex1a'")
    ex1_1st_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-19 23:00:50',oid=#{tdoid},head='0',removed='0',#{vals}")
    td_2nd_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-19 23:00:50',oid=#{ex1aoid},head='1',removed='0',name='ex1a'")
    ex1_2nd_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-23 09:01:00',oid=#{tdoid},head='1',removed='0',#{vals}")
    td_3rd_id = @conn.insert_id()
    
    td = TestData.get(tdoid, :before => Time.local(2010,8,20,0,0,0))
    td.should_not be_nil
    td.id.should eql(td_2nd_id)
    td.testex1_by_id.should eql(ex1aoid)
    td.testex1.should_not be_nil
    td.testex1.id.should eql(ex1_2nd_id)

    td = TestData.get(tdoid, :before => Time.local(2010,8,17,0,0,0))
    td.should_not be_nil
    td.id.should eql(td_1st_id)
    td.testex1_by_id.should eql(ex1aoid)
    td.testex1.should_not be_nil
    td.testex1.id.should eql(ex1_1st_id)

    td = TestData.get(tdoid)
    td.should_not be_nil
    td.id.should eql(td_3rd_id)
    td.testex1.id.should eql(ex1_2nd_id)
  end
  
  it "に :before => anytime オプションつきで .get したオブジェクトの :reflist フィールドからオブジェクトを取得したとき anytime 以前のものが返ること" do
    tdoid = 10282
    ex1aoid = 60
    ex1boid = 61
    ex1coid = 62
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=#{ex1aoid},operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid},head='0',removed='0',#{vals},testex1_oids='#{ex1boid},#{ex1coid}'")
    td_1st_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{ex1boid},head='0',removed='0',name='ex1b'")
    ex1b_1st_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{ex1coid},head='0',removed='0',name='ex1c'")
    ex1c_1st_id = @conn.insert_id()

    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-19 23:00:50',oid=#{tdoid},head='0',removed='0',#{vals},testex1_oids='#{ex1boid}'")
    td_2nd_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-19 23:00:50',oid=#{ex1boid},head='1',removed='0',name='ex1b'")
    ex1b_2nd_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-19 23:00:51',oid=#{ex1coid},head='0',removed='0',name='ex1c'")
    ex1c_2nd_id = @conn.insert_id()

    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-23 09:01:00',oid=#{tdoid},head='1',removed='0',#{vals},testex1_oids='#{ex1boid},#{ex1coid}'")
    td_3rd_id = @conn.insert_id()
    @conn.query("INSERT INTO #{TestEX1.tablename} SET inserted_at='2010-08-23 09:01:32',oid=#{ex1coid},head='1',removed='0',name='ex1c'")
    ex1c_3rd_id = @conn.insert_id()

    td = TestData.get(tdoid, :before => Time.local(2010,8,20,0,0,0))
    td.should_not be_nil
    td.id.should eql(td_2nd_id)
    ex1s = td.testex1s
    ex1s.size.should eql(1)
    ex1s[0].id.should eql(ex1b_2nd_id)

    td = TestData.get(tdoid, :before => Time.local(2010,8,17,0,0,0))
    td.should_not be_nil
    td.id.should eql(td_1st_id)
    ex1s = td.testex1s
    ex1s.size.should eql(2)
    ex1s[0].id.should eql(ex1b_1st_id)
    ex1s[1].id.should eql(ex1c_1st_id)

    td = TestData.get(tdoid, :before => Time.local(2010,8,23,9,1,0))
    td.should_not be_nil
    td.id.should eql(td_3rd_id)
    ex1s = td.testex1s
    ex1s.size.should eql(2)
    ex1s[0].id.should eql(ex1b_2nd_id)
    ex1s[1].id.should eql(ex1c_2nd_id)

    td = TestData.get(tdoid)
    td.should_not be_nil
    td.id.should eql(td_3rd_id)
    ex1s = td.testex1s
    ex1s.size.should eql(2)
    ex1s[0].id.should eql(ex1b_2nd_id)
    ex1s[1].id.should eql(ex1c_3rd_id)
  end

  it "に、複数の oid を引数に .get し、その oid のレコードが実際にはひとつも存在しない場合、空の配列が返ること" do
    tdoid1 = 10283
    tdoid2 = 10284
    ret = @conn.query("SELECT * FROM #{TestData.tablename} WHERE oid=#{tdoid1} or oid=#{tdoid2}")
    ret.num_rows().should eql(0)

    ary = TestData.get(tdoid1, tdoid2)
    ary.should eql([])
    ary = TestData.get([tdoid1, tdoid2])
    ary.should eql([])
  end

  it "に、複数の oid を引数に .get し、oidに対してオブジェクトがすべて実在する場合、それらを格納した配列が返ること" do
    tdoid1 = 10285
    tdoid2 = 10286
    tdoid3 = 10287
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    id1 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    id2 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    id3 = @conn.insert_id()
    
    ary = TestData.get(tdoid1, tdoid2, tdoid3)
    ary.size.should eql(3)
    ary.map(&:id).sort.should eql([id1, id2, id3])
  end
  
  it "に、複数の oid を引数に .get し、oidに対して一部のオブジェクトしか実在しない場合、それらを格納した配列が返ること" do
    tdoid1 = 10288
    tdoid2 = 10289
    tdoid3 = 10290
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    id1 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    id3 = @conn.insert_id()

    ary = TestData.get(tdoid1, tdoid2, tdoid3)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1,tdoid3])
    ary.map(&:id).sort.should eql([id1,id3])
  end
  
  it "に、複数の oid を引数に .get し、oidに対して一部のオブジェクトが removed フラグが立っている場合、それら以外を格納した配列が返ること" do
    tdoid1 = 10291
    tdoid2 = 10292
    tdoid3 = 10293
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    id1 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    id2 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    id3 = @conn.insert_id()

    td2 = TestData.get(tdoid2)
    td2.remove()

    ary = TestData.get(tdoid1, tdoid2, tdoid3)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid3])
    ary.map(&:id).sort.should eql([id1, id3])
  end
  
  it "に、複数の oid を引数に .get し、oidに対して全部のオブジェクトで removed フラグが立っている場合、空の配列が返ること" do
    tdoid1 = 10294
    tdoid2 = 10295
    tdoid3 = 10296
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    id1 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    id2 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    id3 = @conn.insert_id()

    td1 = TestData.get(tdoid1)
    td1.remove()
    td2 = TestData.get(tdoid2)
    td2.remove()
    td3 = TestData.get(tdoid3)
    td3.remove()

    ary = TestData.get(tdoid1, tdoid2, tdoid3)
    ary.size.should eql(0)
  end

  it "に、複数の oid と :force_all => true を引数に .get したとき removed フラグの立っている oid を含めてすべてを格納した配列が返ること" do 
    tdoid1 = 10297
    tdoid2 = 10298
    tdoid3 = 10299
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    id1 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    id2 = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    id3 = @conn.insert_id()

    td2 = TestData.get(tdoid2)
    td2.remove()
    td2id = @conn.query("SELECT id FROM #{TestData.tablename} WHERE oid=#{tdoid2} ORDER BY id DESC LIMIT 1").fetch_row.first.to_i

    ary = TestData.get(tdoid1, tdoid2, tdoid3, :force_all => true)
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2, tdoid3])
    ary.map(&:id).sort.should eql([id1,id3, td2id])
  end
  
  it "に、複数の oid と :before => anytime を引数に .get したとき removed フラグの立っていない、かつ anytime より前で最新のオブジェクトの配列が返ること" do
    tdoid1 = 10301
    tdoid2 = 10302
    tdoid3 = 10303
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='0',removed='0',#{vals}")
    id1_1st = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='0',removed='0',#{vals}")
    id2_1st = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='0',removed='0',#{vals}")
    id3_1st = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 18:15:33',oid=#{tdoid1},head='1',removed='1',#{vals}")
    id1_2nd = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 17:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    id2_2nd = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 17:15:33',oid=#{tdoid3},head='0',removed='0',#{vals}")
    id3_2nd = @conn.insert_id()
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 18:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    id3_3rd = @conn.insert_id()

    ary = TestData.get(tdoid1, tdoid2, tdoid3)
    ary.size.should eql(2)

    ary = TestData.get(tdoid1, tdoid2, tdoid3, :before => Time.local(2010,8,16,18,15,00))
    ary.size.should eql(3)
    ary.map(&:id).sort.should eql([id1_1st, id2_2nd, id3_2nd])
  end
  
  it "に、複数の oid と :before => anytime を引数に .get したとき anytime より前にオブジェクトが存在しない場合は空の配列が返ること" do
    tdoid1 = 10304
    tdoid2 = 10305
    tdoid3 = 10306
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")
    
    ary = TestData.get(tdoid1, tdoid2, tdoid3, :before => Time.local(2010,8,16,12,15,0))
    ary.size.should eql(0)
  end
  
  it "に oid ひとつを引数に .retrospect し、その oid のレコードが実際には存在しない場合 nil が返ること" do
    tdoid = 10307
    @conn.query("SELECT count(*) FROM #{TestData.tablename} WHERE oid=#{tdoid}").fetch_row.first.should eql("0")

    ary = TestData.retrospect(tdoid)
    ary.should be_nil
  end
  
  it "に oid ひとつを引数に .retrospect し、その oid のレコードが存在する場合 head/removed フラグにかかわらず全てが配列で返り、新しい順(id DESC)になっていること" do
    vals = "flag2='0',string1='hoge',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"

    tdoid1 = 10308
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='0',removed='0',#{vals},string3='zero'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:34',oid=#{tdoid1},head='0',removed='0',#{vals},string3='one'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:35',oid=#{tdoid1},head='0',removed='0',#{vals},string3='two'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:36',oid=#{tdoid1},head='1',removed='0',#{vals},string3='three'")

    td1 = TestData.get(tdoid1)
    td1.string3.should eql("three")
    ary = TestData.retrospect(tdoid1)
    ary.map(&:string3).should eql(['three', 'two', 'one', 'zero'])

    tdoid2 = 10309
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 13:15:33',oid=#{tdoid2},head='0',removed='0',#{vals},string3='zero'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 14:15:33',oid=#{tdoid2},head='0',removed='0',#{vals},string3='one'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 15:15:33',oid=#{tdoid2},head='0',removed='0',#{vals},string3='two'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 16:15:33',oid=#{tdoid2},head='1',removed='1',#{vals},string3='three'")
    
    td2 = TestData.get(tdoid2)
    td2.should be_nil
    ary = TestData.retrospect(tdoid2)
    ary.map(&:string3).should eql(['three', 'two', 'one', 'zero'])
  end

  it "に、条件なし、もしくは複数の条件で .regex_match し、例外が発生すること" do
    lambda {TestData.regex_match()}.should raise_exception(ArgumentError)
    lambda {TestData.regex_match(:string1 => /HOGE.*/, :string2 => /2\Z/)}.should raise_exception(ArgumentError)
  end
  
  it "に :string 以外のフィールドに対して .regex_match し、例外が発生すること" do
    lambda {TestData.regex_match(:flag1 => /true/)}.should raise_exception(ArgumentError)
    lambda {TestData.regex_match(:list1 => /moge/)}.should raise_exception(ArgumentError)
    lambda {TestData.regex_match(:testex2s => /i/)}.should raise_exception(ArgumentError)
  end
  
  it "に、数件の結果が返るよう .regex_match し、条件に合うオブジェクトの配列が返ること" do
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    (0...1000).each do |i|
      sn = if i < 500
             "web#{i}.blog-new"
           elsif i < 600
             "db#{i}.blog-new"
           elsif i < 800
             "app#{i}.blog-new"
           else
             "dev#{i}.log"
           end
      if (i % 20) == 0
        sn += '.dev'
      end
      @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=#{i + 2000},name='#{sn}',operated_by=1")
    end

    ary = TestEX1.regex_match(:name => /db.*\.dev\Z/)
    ary.size.should eql(5)
    ary.map{|i| (i.oid - 2000)}.should eql([500, 520, 540, 560, 580])

    ary = TestEX1.regex_match(:name => /\Adev.*/)
    ary.size.should eql(200)

    ary = TestEX1.regex_match(:name => /./)
    ary.size.should eql(1000)
  end

  it "に、条件なし、もしくは複数の条件で .getlist し、例外が発生すること" do
    lambda {TestData.getlist()}.should raise_exception(ArgumentError)
    lambda {TestData.getlist(:string1, :string2)}.should raise_exception(ArgumentError)
  end

  it "に :string 以外のフィールドに対して .getlist し、例外が発生すること" do 
    lambda {TestData.regex_match(:flag1 => /true/)}.should raise_exception(ArgumentError)
    lambda {TestData.regex_match(:list1 => /moge/)}.should raise_exception(ArgumentError)
    lambda {TestData.regex_match(:testex2s => /i/)}.should raise_exception(ArgumentError)
  end

  it "に :string のフィールドを指定して .getlist し、すべてのオブジェクトがソートされて返ること" do 
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    i = 3001
    ["hogemoge", "abcsdare01","hogekakakaka","abcsdare03","abcsdare02","WAWAWA01", "wawawa02"].each do |s|
      @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=#{i},name='#{s}',operated_by=1")
      i += 1
    end
    ary = TestEX1.getlist(:name)
    ary.map(&:name).should eql(["WAWAWA01","abcsdare01","abcsdare02","abcsdare03","hogekakakaka","hogemoge","wawawa02"])
  end

  it "に :bool のみを条件に .query し、条件に該当するオブジェクトが存在しない場合に空配列が返ること" do
    tdoid1 = 10311
    tdoid2 = 10312
    tdoid3 = 10313
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:flag2 => true)
    ary.should eql([])
  end

  it "に :bool のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがすべて格納された配列で返ること" do
    tdoid1 = 10314
    tdoid2 = 10315
    tdoid3 = 10316
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:flag2 => false)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid3])
  end
  
  it "に :bool のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがひとつの場合、1要素の配列で返ること" do
    tdoid1 = 10317
    tdoid2 = 10318
    tdoid3 = 10319
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:flag2 => false)
    ary.should be_instance_of(Array)
    ary.size.should eql(1)
    ary[0].oid.should eql(tdoid3)
  end

  it "に :bool および :force_all => true を条件に .query し、条件に該当するオブジェクトがすべて格納された配列で返ること" do
    tdoid1 = 10321
    tdoid2 = 10322
    tdoid3 = 10323
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='1',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:flag2 => true, :force_all => true)
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2, tdoid3])
  end

  it "に :bool および :unique => true を条件に .query し、条件に該当するオブジェクトが存在しない場合 nil が返ること" do
    tdoid1 = 10324
    tdoid2 = 10325
    tdoid3 = 10326
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:flag2 => true, :unique => true)
    ary.should be_nil
  end
  
  it "に :bool および :unique => true を条件に .query し、条件に該当するオブジェクトが複数存在する場合は例外が発生すること" do
    tdoid1 = 10327
    tdoid2 = 10328
    tdoid3 = 10329
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    lambda {TestData.query(:flag2 => false, :unique => true)}.should raise_exception(Stratum::NotUniqueResultError)
  end
  
  it "に :bool および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつだけ存在する場合はそのオブジェクトのみが返ること" do
    tdoid1 = 10331
    tdoid2 = 10332
    tdoid3 = 10333
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    td = nil
    lambda {td = TestData.query(:flag2 => false, :unique => true)}.should_not raise_exception(Stratum::NotUniqueResultError)
    td.should be_instance_of(TestData)
    td.oid.should eql(tdoid3)
  end
  
  it "に :bool および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつを除いて removed フラグが立っている場合、それらを除いたひとつのみが返ること" do
    tdoid1 = 10334
    tdoid2 = 10335
    tdoid3 = 10336
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    td = nil
    lambda {td = TestData.query(:flag2 => false, :unique => true)}.should_not raise_exception(Stratum::NotUniqueResultError)
    td.should be_instance_of(TestData)
    td.oid.should eql(tdoid3)
  end

  it "に :string のみを条件に .query し、条件に該当するオブジェクトが存在しない場合、空配列が返ること" do
    tdoid1 = 10341
    tdoid2 = 10342
    tdoid3 = 10343
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:string1 => "moge")
    ary.should eql([])
  end
  
  it "に :string のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがすべて格納された配列で返ること" do
    tdoid1 = 10344
    tdoid2 = 10345
    tdoid3 = 10346
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:string1 => "hoge")
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2, tdoid3])
  end
  
  it "に :string のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがひとつの場合、1要素の配列で返ること" do
    tdoid1 = 10347
    tdoid2 = 10348
    tdoid3 = 10349
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='1',#{vals}")

    ary = TestData.query(:string1 => "hoge")
    ary.should be_instance_of(Array)
    ary.size.should eql(1)
    ary.map(&:oid).sort.should eql([tdoid2])
  end

  it "に :string および :force_all => true を条件に .query し、条件に該当するオブジェクトがすべて格納された配列で返ること" do
    tdoid1 = 10351
    tdoid2 = 10352
    tdoid3 = 10353
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='1',#{vals}")

    ary = TestData.query(:string1 => "hoge", :force_all => true)
    ary.should be_instance_of(Array)
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2, tdoid3])
  end

  it "に :string および :unique => true を条件に .query し、条件に該当するオブジェクトが存在しない場合 nil が返ること" do
    tdoid1 = 10354
    tdoid2 = 10355
    tdoid3 = 10356
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    ary = TestData.query(:string1 => "moge", :unique => true)
    ary.should be_nil
  end

  it "に :string および :unique => true を条件に .query し、条件に該当するオブジェクトが複数存在する場合は例外が発生すること" do
    tdoid1 = 10357
    tdoid2 = 10358
    tdoid3 = 10359
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals}")

    lambda {TestData.query(:string1 => "hoge", :unique => true)}.should raise_exception(Stratum::NotUniqueResultError)
  end
  
  it "に :string および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつだけ存在する場合はそのオブジェクトのみが返ること" do
    tdoid1 = 10361
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals}")

    ary = TestData.query(:string1 => "hoge", :unique => true)
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid1)
  end
  
  it "に :string および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつを除いて removed フラグが立っている場合、それらを除いたひとつのみが返ること" do
    tdoid1 = 10364
    tdoid2 = 10365
    tdoid3 = 10366
    @conn.query("DELETE FROM #{TestData.tablename}")
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='1',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals}")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='1',#{vals}")

    ary = TestData.query(:string1 => "hoge", :unique => true)
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid2)
  end

  it "に :stringlist のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがすべて格納された配列で返ること" do
    tdoid1 = 10401
    tdoid2 = 10402
    tdoid3 = 10403
    @conn.query("DELETE FROM #{TestData.tablename}")
    list2val = "HOGE\tPOS\tLABEL1"
    vals = "flag2='0',string1='hoge',string3='three',list2='#{list2val}',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals},list3='1,2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals},list3='2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='0',#{vals},list3='1,2'")

    ary1 = TestData.query(:list3 => ['1','2'])
    ary1.size.should eql(2)
    ary1.map(&:oid).sort.should eql([tdoid1, tdoid3])

    ary2 = TestData.query(:list2 => ['HOGE', 'POS', 'LABEL1'])
    ary2.size.should eql(3)
  end

  it "に :stringlist および :force_all => true を条件に .query し、条件に該当するオブジェクトがすべて格納された配列で返ること" do
    tdoid1 = 10404
    tdoid2 = 10405
    tdoid3 = 10406
    @conn.query("DELETE FROM #{TestData.tablename}")
    list2val = "HOGE\tPOS\tLABEL1"
    vals = "flag2='0',string1='hoge',string3='three',list2='#{list2val}',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals},list3='1,2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals},list3='2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='1',#{vals},list3='1,2'")

    ary1 = TestData.query(:list3 => ['1','2'], :force_all => true)
    ary1.size.should eql(2)
    ary1.map(&:oid).sort.should eql([tdoid1, tdoid3])

    ary2 = TestData.query(:list2 => ['HOGE', 'POS', 'LABEL1'], :force_all => true)
    ary2.size.should eql(3)
  end
  
  it "に :stringlist および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつだけ存在する場合はそのオブジェクトのみが返ること" do
    tdoid1 = 10407
    tdoid2 = 10408
    tdoid3 = 10409
    @conn.query("DELETE FROM #{TestData.tablename}")
    list2val = "HOGE\tPOS\tLABEL1"
    vals = "flag2='0',string1='hoge',string3='three',list2='#{list2val}',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals},list3='1,2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='0',#{vals},list3='2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='1',#{vals},list3='1,2'")

    ary1 = TestData.query(:list3 => ['2'], :force_all => true, :unique => true)
    ary1.should be_instance_of(TestData)
    ary1.oid.should eql(tdoid2)
  end
  
  it "に :stringlist および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつを除いて removed フラグが立っている場合、それらを除いたひとつのみが返ること" do
    tdoid1 = 10411
    tdoid2 = 10412
    tdoid3 = 10413
    @conn.query("DELETE FROM #{TestData.tablename}")
    list2val = "HOGE\tPOS\tLABEL1"
    vals = "flag2='0',string1='hoge',string3='three',list2='#{list2val}',ref_oid=70,testex1_oids='71,72',operated_by=1"
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid1},head='1',removed='0',#{vals},list3='1,2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid2},head='1',removed='1',#{vals},list3='2'")
    @conn.query("INSERT INTO #{TestData.tablename} SET inserted_at='2010-08-16 12:15:33',oid=#{tdoid3},head='1',removed='1',#{vals},list3='1,2'")

    ary1 = TestData.query(:list2 => ['HOGE', 'POS', 'LABEL1'], :unique => true)
    ary1.should be_instance_of(TestData)
    ary1.oid.should eql(tdoid1)
  end

  it "に :taglist のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがすべて格納された配列で返ること" do
    (@conn.query("SHOW VARIABLES LIKE 'ft_min_word_len'").fetch_hash['Value'].to_i <= 2).should be_true

    @conn.query("DELETE FROM #{TestTag.tablename}")
    @conn.query("INSERT INTO #{TestTag.tablename} SET oid=9901,tags='HOGE POS 20100825-15:18 blog-new Web'")
    @conn.query("INSERT INTO #{TestTag.tablename} SET oid=9902,tags='HOGE POS 20100824-15:18 blog-new Web'")
    @conn.query("INSERT INTO #{TestTag.tablename} SET oid=9903,tags='HOGE POS 20100824-15:18 blog-new DB'")
    @conn.query("INSERT INTO #{TestTag.tablename} SET oid=9904,tags='HOGE POS 20100825-15:18 m.blog-new AP'")
    @conn.query("INSERT INTO #{TestTag.tablename} SET oid=9905,tags='HOGE POS 20100825-15:18 m.search DB'")
    @conn.query("INSERT INTO #{TestTag.tablename} SET oid=9906,tags='HOGE POS 20100825-15:18 m.search Web'")

    ary = TestTag.query(:tags => "HOGE")
    ary.should_not be_nil
    ary.should be_instance_of(Array)
    ary.size.should eql(6)

    TestTag.query(:tags => ["HOGE", "POS"]).size.should eql(6)
    TestTag.query(:tags => ['20100825-15:18']).size.should eql(4)
    TestTag.query(:tags => 'blog-new').size.should eql(4)
    TestTag.query(:tags => 'DB').size.should eql(2)
  end

  it "に :ref のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがすべて格納された配列で返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX1.tablename}")

    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7001,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7002,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7003,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',operated_by=1"
    tdoid1 = 10414
    tdoid2 = 10415
    tdoid3 = 10416
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='0',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},ref_oid=7002")

    ex1 = TestEX1.get(7001)
    ex1.should_not be_nil

    ary = TestData.query(:testex1 => ex1)
    ary.should be_instance_of(Array)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2])

    ary = TestData.query(:testex1 => ex1.oid)
    ary.should be_instance_of(Array)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2])
  end

  it "に :ref および :force_all => true を条件に .query し、条件に該当するオブジェクトがすべて格納された配列で返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX1.tablename}")

    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7001,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7002,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7003,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',operated_by=1"
    tdoid1 = 10417
    tdoid2 = 10418
    tdoid3 = 10419
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='0',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='1',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},ref_oid=7002")

    ex1 = TestEX1.get(7001)
    ex1.should_not be_nil

    ary = TestData.query(:testex1 => ex1)
    ary.should be_instance_of(Array)
    ary.size.should eql(1)
    ary.map(&:oid).sort.should eql([tdoid1])

    ary = TestData.query(:testex1 => ex1, :force_all => true)
    ary.should be_instance_of(Array)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2])

    ary = TestData.query(:testex1 => ex1.oid, :force_all => true)
    ary.should be_instance_of(Array)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid2])
  end

  it "に :ref および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつだけ存在する場合はそのオブジェクトのみが返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX1.tablename}")

    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7001,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7002,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7003,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',operated_by=1"
    tdoid1 = 10421
    tdoid2 = 10422
    tdoid3 = 10423
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='0',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},ref_oid=7002")

    ex1 = TestEX1.get(7002)
    ex1.should_not be_nil

    ary = TestData.query(:testex1 => ex1, :unique => true)
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid3)
  end

  it "に :ref および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつを除いて removed フラグが立っている場合、それらを除いたひとつのみが返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX1.tablename}")

    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7001,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7002,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7003,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',operated_by=1"
    tdoid1 = 10424
    tdoid2 = 10425
    tdoid3 = 10426
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='1',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},ref_oid=7001")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},ref_oid=7002")

    ex1 = TestEX1.get(7001)
    ex1.should_not be_nil

    ary = TestData.query(:testex1 => ex1, :unique => true)
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid2)
  end

  it "に :reflist のみを条件に .query し、条件に該当し removed フラグの立っていないオブジェクトがすべて格納された配列で返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX2.tablename}")

    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7011,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7012,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7013,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=7001,operated_by=1"
    tdoid1 = 10427
    tdoid2 = 10428
    tdoid3 = 10429
    tdoid4 = 10430
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},testex2s='7012,7013'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid4},removed='1',#{vals},testex2s='7011,7012'")

    ex2a = TestEX2.get(7011)
    ex2b = TestEX2.get(7012)
    ex2c = TestEX2.get(7013)

    ary = TestData.query(:testex2s => [ex2a, ex2b])
    ary.should be_instance_of(Array)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid3])

    ary = TestData.query(:testex2s => [ex2a.oid, ex2b.oid])
    ary.should be_instance_of(Array)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid3])
  end
  
  it "に :reflist および :force_all => true を条件に .query し、条件に該当するオブジェクトがすべて格納された配列で返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX2.tablename}")

    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7011,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7012,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7013,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=7001,operated_by=1"
    tdoid1 = 10427
    tdoid2 = 10428
    tdoid3 = 10429
    tdoid4 = 10430
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},testex2s='7012,7013'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid4},removed='1',#{vals},testex2s='7011,7012'")

    ex2a = TestEX2.get(7011)
    ex2b = TestEX2.get(7012)
    ex2c = TestEX2.get(7013)

    ary = TestData.query(:testex2s => [ex2a, ex2b], :force_all => true)
    ary.should be_instance_of(Array)
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid3, tdoid4])

    ary = TestData.query(:testex2s => [ex2a.oid, ex2b.oid], :force_all => true)
    ary.should be_instance_of(Array)
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([tdoid1, tdoid3, tdoid4])
  end
  
  it "に :reflist および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつだけ存在する場合はそのオブジェクトのみが返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX2.tablename}")

    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7011,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7012,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7013,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=7001,operated_by=1"
    tdoid1 = 10427
    tdoid2 = 10428
    tdoid3 = 10429
    tdoid4 = 10430
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},testex2s='7012,7013'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid4},removed='1',#{vals},testex2s='7011,7012'")

    ex2a = TestEX2.get(7011)
    ex2b = TestEX2.get(7012)
    ex2c = TestEX2.get(7013)

    ary = TestData.query(:testex2s => [ex2c, ex2b], :unique => true)
    ary.should be_nil

    ary = TestData.query(:testex2s => [ex2b, ex2c], :unique => true)
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid2)

    ary = TestData.query(:testex2s => [ex2b.oid, ex2c.oid], :unique => true)
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid2)
  end

  it "に :reflist および :unique => true を条件に .query し、条件に該当するオブジェクトがひとつを除いて removed フラグが立っている場合、それらを除いたひとつのみが返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX2.tablename}")

    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7011,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7012,name='hoge2',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7013,name='hoge3',operated_by=1")
    
    vals = "flag2='0',string1='hoge',string3='three',list2='blank',ref_oid=7001,operated_by=1"
    tdoid1 = 10427
    tdoid2 = 10428
    tdoid3 = 10429
    tdoid4 = 10430
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid1},removed='1',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid2},removed='0',#{vals},testex2s='7012,7013'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid3},removed='0',#{vals},testex2s='7011,7012'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=#{tdoid4},removed='1',#{vals},testex2s='7011,7012'")

    ex2a = TestEX2.get(7011)
    ex2b = TestEX2.get(7012)
    ex2c = TestEX2.get(7013)

    ary = TestData.query(:testex2s => [ex2a, ex2b], :unique => true)
    ary.should_not be_nil
    ary.should be_instance_of(TestData)
    ary.oid.should eql(tdoid3)
  end

  it "に、複数の適当な条件を組み合わせて .query を行って、正常に結果が返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    @conn.query("DELETE FROM #{TestEX2.tablename}")
    
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7211,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7212,name='hoge2',operated_by=1")

    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7221,name='hogeA',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7222,name='hogeB',operated_by=1")

    ex1a = TestEX1.get(7211)
    ex1b = TestEX1.get(7212)
    ex2a = TestEX2.get(7221)
    ex2b = TestEX2.get(7222)

    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7111,operated_by=1, flag1='1', flag2='0', string1='HOGEPOS', string2='OPT1', ref_oid=7211, testex2s='7221'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7112,operated_by=1, flag1='0', flag2='0', string1='HOGEPOS', string2='OPT2', ref_oid=7211, testex2s='7222'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7113,operated_by=1, flag1='0', flag2='1', string1='HOGEPOS', string2='OPT2', ref_oid=7211, testex2s='7221,7222'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7114,operated_by=1, flag1='1', flag2='1', string1='HOGEPOS', string2='OPT2', ref_oid=7212, testex2s='7221'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7115,operated_by=1, flag1='1', flag2='0', string1='HOGE', string2='OPT3', ref_oid=7212, testex2s='7221,7222'")

    ary = TestData.query(:flag1 => true, :flag2 => false)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([7111, 7115])
    
    ary = TestData.query(:flag1 => false, :flag2 => false)
    ary.size.should eql(1)
    ary.map(&:oid).sort.should eql([7112])

    ary = TestData.query(:flag1 => true, :string1 => 'HOGEPOS')
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([7111, 7114])

    ary = TestData.query(:string1 => 'HOGEPOS', :string2 => 'OPT2')
    ary.size.should eql(3)
    ary.map(&:oid).sort.should eql([7112, 7113, 7114])

    ary = TestData.query(:string2 => 'OPT1', :testex1 => ex1a)
    ary.size.should eql(1)
    ary.map(&:oid).sort.should eql([7111])
    
    ary = TestData.query(:testex1 => ex1b, :flag1 => true)
    ary.size.should eql(2)
    ary.map(&:oid).sort.should eql([7114, 7115])
    
    ary = TestData.query(:testex1 => ex1a, :testex2s => [ex2a.oid, ex2b.oid])
    ary.size.should eql(1)
    ary.map(&:oid).sort.should eql([7113])

    ary = TestData.query(:flag1 => true, :flag2 => false, :string1 => 'HOGEPOS', :testex2s => [ex2a])
    ary.size.should eql(1)
    ary.map(&:oid).sort.should eql([7111])
  end

  it "に、複数の適当な条件を組み合わせて .query を行って、その結果が各条件で個別に .query した結果の積になっていること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    @conn.query("DELETE FROM #{TestEX2.tablename}")
    
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7211,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=7212,name='hoge2',operated_by=1")

    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7221,name='hogeA',operated_by=1")
    @conn.query("INSERT INTO #{TestEX2.tablename} SET oid=7222,name='hogeB',operated_by=1")

    ex1a = TestEX1.get(7211)
    ex1b = TestEX1.get(7212)
    ex2a = TestEX2.get(7221)
    ex2b = TestEX2.get(7222)

    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7111,operated_by=1, flag1='1', flag2='0', string1='HOGEPOS', string2='OPT1', ref_oid=7211, testex2s='7221'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7112,operated_by=1, flag1='0', flag2='0', string1='HOGEPOS', string2='OPT2', ref_oid=7211, testex2s='7222'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7113,operated_by=1, flag1='0', flag2='1', string1='HOGEPOS', string2='OPT2', ref_oid=7211, testex2s='7221,7222'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7114,operated_by=1, flag1='1', flag2='1', string1='HOGEPOS', string2='OPT2', ref_oid=7212, testex2s='7221'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=7115,operated_by=1, flag1='1', flag2='0', string1='HOGE', string2='OPT3', ref_oid=7212, testex2s='7221,7222'")

    ary1 = TestData.query(:flag1 => true, :flag2 => false).map(&:oid)
    aryA = TestData.query(:flag1 => true).map(&:oid)
    aryB = TestData.query(:flag2 => false).map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)
    
    ary1 = TestData.query(:flag1 => false, :flag2 => false).map(&:oid)
    aryA = TestData.query(:flag1 => false).map(&:oid)
    aryB = TestData.query(:flag2 => false).map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)

    ary1 = TestData.query(:flag1 => true, :string1 => 'HOGEPOS').map(&:oid)
    aryA = TestData.query(:flag1 => true).map(&:oid)
    aryB = TestData.query(:string1 => 'HOGEPOS').map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)

    ary1 = TestData.query(:string1 => 'HOGEPOS', :string2 => 'OPT2').map(&:oid)
    aryA = TestData.query(:string1 => 'HOGEPOS').map(&:oid)
    aryB = TestData.query(:string2 => 'OPT2').map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)

    ary1 = TestData.query(:string2 => 'OPT1', :testex1 => ex1a).map(&:oid)
    aryA = TestData.query(:string2 => 'OPT1').map(&:oid)
    aryB = TestData.query(:testex1 => ex1a).map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)
    
    ary1 = TestData.query(:testex1 => ex1b, :flag1 => true).map(&:oid)
    aryA = TestData.query(:testex1 => ex1b).map(&:oid)
    aryB = TestData.query(:flag1 => true).map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)
    
    ary1 = TestData.query(:testex1 => ex1a, :testex2s => [ex2a.oid, ex2b.oid]).map(&:oid)
    aryA = TestData.query(:testex1 => ex1a).map(&:oid)
    aryB = TestData.query(:testex2s => [ex2a, ex2b]).map(&:oid)
    ary2 = aryA & aryB
    ary2.should eql(ary1)

    ary1 = TestData.query(:flag1 => true, :flag2 => false, :string1 => 'HOGEPOS', :testex2s => [ex2a]).map(&:oid)
    aryA = TestData.query(:flag1 => true).map(&:oid)
    aryB = TestData.query(:flag2 => false).map(&:oid)
    aryC = TestData.query(:string1 => 'HOGEPOS').map(&:oid)
    aryD = TestData.query(:testex2s => [ex2a]).map(&:oid)
    ary2 = aryA & aryB & aryC & aryD
    ary2.should eql(ary1)
  end

  it "に、単一の適当な条件で .query_or_create を行って、複数のオブジェクトが該当する場合に例外が発生すること" do
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=8001,name='hoge1',operated_by=1")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=8002,name='hoge1',operated_by=1")

    lambda {TestEX1.query_or_create(:name => 'hoge1')}.should raise_exception(Stratum::NotUniqueResultError)
  end

  it "に、複数の適当な条件で .query_or_create を行って、複数のオブジェクトが該当する場合に例外が発生すること" do 
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=8101,operated_by=1, flag1='1', flag2='0', string1='HOGEPOS', string2='OPT1'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=8102,operated_by=1, flag1='1', flag2='0', string1='HOGEMOGE', string2='OPT1'")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=8103,operated_by=1, flag1='1', flag2='0', string1='HOGEPOS', string2='OPT2'")

    lambda {TestData.query_or_create(:flag1 => true, :flag2 => false, :string2 => 'OPT1')}.should raise_exception(Stratum::NotUniqueResultError)
  end
  
  it "に、単一の適当な条件で .query_or_create を行って、単一の既存オブジェクトが該当する場合にそのオブジェクトが返ること" do
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=8011,name='hoge1',operated_by=1")
    xid = @conn.insert_id()

    ex1 = TestEX1.query_or_create(:name => 'hoge1')
    ex1.id.should eql(xid)
    ex1.name.should eql('hoge1')
  end

  it "に、複数の適当な条件で .query_or_create を行って、単一の既存オブジェクトが該当する場合にそのオブジェクトが返ること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=8111,operated_by=1, flag1='1', flag2='0', string1='HOGEPOS', string2='OPT1'")
    xid = @conn.insert_id()
    
    td = TestData.query_or_create(:flag1 => true, :flag2 => false, :string1 => 'HOGEPOS')
    td.id.should eql(xid)
    td.flag1.should be_true
    td.flag2.should be_false
    td.string1.should eql('HOGEPOS')
  end
  
  it "に、単一の適当な条件で .query_or_create を行って、該当するオブジェクトがひとつもない場合に新しく作られたオブジェクトが返り、条件に指定した値がセットされていること" do
    @conn.query("DELETE FROM #{TestEX1.tablename}")
    @conn.query("INSERT INTO #{TestEX1.tablename} SET oid=8021,name='hoge1',operated_by=1")
    xid = @conn.insert_id()

    ex1 = TestEX1.query_or_create(:name => 'hoge12')
    ex1.should_not be_nil
    ex1.id.should_not eql(xid)
    ex1.oid.should_not eql(8021)
    ex1.name.should eql('hoge12')
  end
  
  it "に、複数の適当な条件で .query_or_create を行って、該当するオブジェクトがひとつもない場合に新しく作られたオブジェクトが返り、条件に指定した値すべてがセットされていること" do
    @conn.query("DELETE FROM #{TestData.tablename}")
    @conn.query("INSERT INTO #{TestData.tablename} SET oid=8121,operated_by=1, flag1='1', flag2='0', string1='HOGEPOS', string2='OPT1'")
    xid = @conn.insert_id()
    
    td = TestData.query_or_create(:flag1 => true, :flag2 => false, :string1 => 'HOGEMOGE')
    td.should_not be_nil
    td.id.should_not eql(xid)
    td.flag1.should be_true
    td.flag2.should be_false
    td.string1.should eql('HOGEMOGE')
  end
  
  # tag
end

