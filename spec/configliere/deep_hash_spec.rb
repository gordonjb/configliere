require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class AwesomeHash < DeepHash ; end

describe DeepHash do
  before(:each) do
    @deep_hash = DeepHash.new.merge!({ :nested_1 => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => "val2" }, :leaf_at_top => 'val1b' })
    @hash = { "str_key" => "strk_val", :sym_key => "symk_val"}
    @sub  = AwesomeHash.new("str_key" => "strk_val", :sym_key => "symk_val")
  end

  describe "#initialize" do
    it 'adopts a Hash when given' do
      deep_hash = DeepHash.new(@hash)
      @hash.each{|k,v| deep_hash[k].should == v }
      deep_hash.keys.any?{|key| key.is_a?(String) }.should be_false
    end

    it 'converts all pure Hash values into DeepHashes if param is a Hash' do
      deep_hash = DeepHash.new :sym_key => @hash
      deep_hash[:sym_key].should be_an_instance_of(DeepHash)
      # sanity check
      deep_hash[:sym_key][:sym_key].should == "symk_val"
    end

    it 'does not convert Hash subclass values into DeepHashes' do
      deep_hash = DeepHash.new :sub => @sub
      deep_hash[:sub].should be_an_instance_of(AwesomeHash)
    end

    it 'converts all value items if value is an Array' do
      deep_hash = DeepHash.new :arry => { :sym_key => [@hash] }
      deep_hash[:arry].should be_an_instance_of(DeepHash)
      # sanity check
      deep_hash[:arry][:sym_key].first[:sym_key].should == "symk_val"
    end

    it 'delegates to superclass constructor if param is not a Hash' do
      deep_hash = DeepHash.new("dash berlin")

      deep_hash["unexisting key"].should == "dash berlin"
    end
  end # describe "#initialize"

  describe "#update" do
    it 'converts all keys into symbols when param is a Hash' do
      deep_hash = DeepHash.new(@hash)
      deep_hash.update("starry" => "night")

      deep_hash.keys.any?{|key| key.is_a?(String) }.should be_false
    end

    it 'converts all Hash values into DeepHashes if param is a Hash' do
      deep_hash = DeepHash.new :hash => @hash
      deep_hash.update(:hash => { :sym_key => "is buggy in Ruby 1.8.6" })

      deep_hash[:hash].should be_an_instance_of(DeepHash)
    end
  end # describe "#update"

  describe '#[]=' do
    it 'symbolizes keys' do
      @deep_hash['leaf_at_top'] = :fedora
      @deep_hash['new']         = :unseen
      @deep_hash.should == {:nested_1 => {:nested_2 => {:leaf_3 => "val3"}, :leaf_2 => "val2"}, :leaf_at_top => :fedora, :new => :unseen}
    end
    it 'deep-sets dotted vals, replacing values' do
      @deep_hash['moon.man'] = :cheesy
      @deep_hash[:moon][:man].should == :cheesy
    end
    it 'deep-sets dotted vals, creating new values' do
      @deep_hash['moon.cheese.type'] = :tilsit
      @deep_hash[:moon][:cheese][:type].should == :tilsit
    end
    it 'deep-sets dotted vals, auto-vivifying intermediate hashes' do
      @deep_hash['this.that.the_other'] = :fuhgeddaboudit
      @deep_hash[:this][:that][:the_other].should == :fuhgeddaboudit
    end
    it 'converts all Hash value into DeepHash' do
      deep_hash = DeepHash.new :hash => @hash
      deep_hash[:hash] = { :sym_key => "is buggy in Ruby 1.8.6" }
      deep_hash[:hash].should be_an_instance_of(DeepHash)
    end
  end

  describe '#[]' do
    it 'deep-gets dotted vals' do
      hsh = { :hat => :cat, :basket => :lotion, :moon => { :man => :smiling, :cheese => {:type => :tilsit} } }
      @deep_hash = Configliere::Param.new hsh.dup
      @deep_hash['moon.man'].should == :smiling
      @deep_hash['moon.cheese.type'].should == :tilsit
      @deep_hash['moon.cheese.smell'].should be_nil
      @deep_hash['moon.non.existent.interim.values'].should be_nil
      @deep_hash['moon.non'].should be_nil
      if (RUBY_VERSION >= '1.9') then lambda{ @deep_hash['hat.cat'] }.should raise_error(TypeError)
      else                            lambda{ @deep_hash['hat.cat'] }.should raise_error(NoMethodError, 'undefined method `[]\' for :cat:Symbol') end
      @deep_hash.should == hsh # shouldn't change from reading (specifically, shouldn't autovivify)
    end
  end

  def arrays_should_be_equal arr1, arr2
    arr1.sort_by{|s| s.to_s }.should == arr2.sort_by{|s| s.to_s }
  end

  describe "#to_hash" do
    it 'returns instance of Hash' do
      DeepHash.new(@hash).to_hash.should be_an_instance_of(Hash)
    end

    it 'preserves keys' do
      deep_hash = DeepHash.new(@hash)
      converted  = deep_hash.to_hash
      arrays_should_be_equal deep_hash.keys, converted.keys
    end

    it 'preserves value' do
      deep_hash = DeepHash.new(@hash)
      converted = deep_hash.to_hash
      arrays_should_be_equal deep_hash.values, converted.values
    end
  end

  describe '#compact' do
    it 'removes nils but not empties or falsehoods' do
      DeepHash.new({ 1 => nil }).compact.should == {}
      DeepHash.new({ 1 => nil, 2 => false, 3 => {}, 4 => "", :remains => true }).compact!.should == { 2 => false, 3 => {}, 4 => "", :remains => true }
    end

    it 'leaves original alone' do
      deep_hash = DeepHash.new({ 1 => nil, :remains => true })
      deep_hash.compact.should == { :remains => true }
      deep_hash.should == { 1 => nil, :remains => true }
    end
  end

  describe '#compact!' do
    it 'removes nils but not empties or falsehoods' do
      DeepHash.new({ 1 => nil}).compact!.should == {}
      DeepHash.new({ 1 => nil, 2 => false, 3 => {}, 4 => "", :remains => true }).compact!.should == { 2 => false, 3 => {}, 4 => "", :remains => true }
    end

    it 'modifies in-place' do
      deep_hash = DeepHash.new({ 1 => nil, :remains => true })
      deep_hash.compact!.should == { :remains => true }
      deep_hash.should == { :remains => true }
    end
  end

  describe '#slice' do
    before do
      @deep_hash = DeepHash.new({ :a => 'x', :b => 'y', :c => 10 })
    end

    it 'returns a new hash with only the given keys' do
      @deep_hash.slice(:a, :b).should == { :a => 'x', :b => 'y' }
      @deep_hash.should == { :a => 'x', :b => 'y', :c => 10 }
    end

    it 'with bang replaces the hash with only the given keys' do
      @deep_hash.slice!(:a, :b).should == { :c => 10 }
      @deep_hash.should == { :a => 'x', :b => 'y' }
    end

    it 'ignores an array key' do
      @deep_hash.slice([:a, :b], :c).should == { :c => 10 }
      @deep_hash.should == { :a => 'x', :b => 'y', :c => 10 }
    end

    it 'with bang ignores an array key' do
      @deep_hash.slice!([:a, :b], :c).should == { :a => 'x', :b => 'y' }
      @deep_hash.should == { :c => 10 }
    end

    it 'uses splatted keys individually' do
      @deep_hash.slice(*[:a, :b]).should == { :a => 'x', :b => 'y' }
      @deep_hash.should == { :a => 'x', :b => 'y', :c => 10 }
    end

    it 'with bank uses splatted keys individually' do
      @deep_hash.slice!(*[:a, :b]).should == { :c => 10 }
      @deep_hash.should == { :a => 'x', :b => 'y' }
    end
  end

  describe '#extract' do
    before do
      @deep_hash = DeepHash.new({ :a => 'x', :b => 'y', :c => 10 })
    end

    it 'replaces the hash with only the given keys' do
      @deep_hash.extract!(:a, :b).should == { :a => 'x', :b => 'y' }
      @deep_hash.should == { :c => 10 }
    end

    it 'leaves the hash empty if all keys are gone' do
      @deep_hash.extract!(:a, :b, :c).should == { :a => 'x', :b => 'y', :c => 10 }
      @deep_hash.should == {}
    end

    it 'gets values for all given keys even if missing' do
      @deep_hash.extract!(:bob, :c).should == { :bob => nil, :c => 10 }
      @deep_hash.should == { :a => 'x', :b => 'y' }
    end

    it 'is OK when empty' do
      DeepHash.new.slice!(:a, :b, :c).should == {}
    end

    it 'returns an instance of the same class' do
      @deep_hash.slice(:a).should be_a(DeepHash)
    end
  end

  describe 'assert_valid_keys' do
    before do
      @deep_hash = DeepHash.new({ :failure => "stuff", :funny => "business" })
    end

    it 'is true and does not raise when valid' do
      @deep_hash.assert_valid_keys([ :failure, :funny ]).should be_nil
      @deep_hash.assert_valid_keys(:failure, :funny).should be_nil
    end

    it 'fails when invalid' do
      @deep_hash[:failore] = @deep_hash.delete(:failure)
      lambda{ @deep_hash.assert_valid_keys([ :failure, :funny ]) }.should raise_error(ArgumentError, "Unknown key(s): failore")
      lambda{ @deep_hash.assert_valid_keys(:failure, :funny)     }.should raise_error(ArgumentError, "Unknown key(s): failore")
    end
  end

  describe "#delete" do
    it 'converts Symbol key into String before deleting' do
      deep_hash = DeepHash.new(@hash)

      deep_hash.delete(:sym_key)
      deep_hash.key?("hash").should be_false
    end

    it 'works with String keys as well' do
      deep_hash = DeepHash.new(@hash)

      deep_hash.delete("str_key")
      deep_hash.key?("str_key").should be_false
    end
  end

  describe "#merge" do
    before(:each) do
      @deep_hash = DeepHash.new(@hash).merge(:no => "in between")
    end

    it 'returns instance of DeepHash' do
      @deep_hash.should be_an_instance_of(DeepHash)
    end

    it 'merges in give Hash' do
      @deep_hash["no"].should == "in between"
    end
  end

  describe "#fetch" do
    before(:each) do
      @deep_hash = DeepHash.new(@hash).merge(:no => "in between")
    end

    it 'converts key before fetching' do
      @deep_hash.fetch("no").should == "in between"
    end

    it 'returns alternative value if key lookup fails' do
      @deep_hash.fetch("flying", "screwdriver").should == "screwdriver"
    end
  end


  describe "#values_at" do
    before(:each) do
      @deep_hash = DeepHash.new(@hash).merge(:no => "in between")
    end

    it 'is indifferent to whether keys are strings or symbols' do
      @deep_hash.values_at("sym_key", :str_key, :no).should == ["symk_val", "strk_val", "in between"]
    end
  end

  describe "#symbolize_keys" do
    it 'with bang returns the deep_hash itself' do
      deep_hash = DeepHash.new(@hash)
      deep_hash.symbolize_keys!.object_id.should == deep_hash.object_id
    end

    it 'returns a dup of itself' do
      deep_hash = DeepHash.new(@hash)
      deep_hash.symbolize_keys.should == deep_hash
    end
  end

  describe "#reverse_merge" do
    before do
      @defaults  = { :a => "x", :b => "y", :c => 10 }.freeze
      @deep_hash = DeepHash.new({ :a => 1, :b => 2 })
    end

    it 'merges defaults into options, creating a new hash' do
      @deep_hash.reverse_merge(@defaults).should == { :a => 1, :b => 2, :c => 10 }
      @deep_hash.should == { :a => 1, :b => 2 }
    end

    it 'with bang merges! defaults into options, replacing options' do
      @deep_hash.reverse_merge!(@defaults).should == { :a => 1, :b => 2, :c => 10 }
      @deep_hash.should == { :a => 1, :b => 2, :c => 10 }
    end
  end

  describe "#deep_merge!" do
    it "merges two subhashes when they share a key" do
      @deep_hash.deep_merge!(:nested_1 => { :nested_2  => { :leaf_3_also  => "val3a" } })
      @deep_hash.should == { :nested_1 => { :nested_2  => { :leaf_3_also  => "val3a", :leaf_3 => "val3" }, :leaf_2 => "val2" }, :leaf_at_top => 'val1b' }
    end
    it "merges two subhashes when they share a symbolized key" do
      @deep_hash.deep_merge!(:nested_1 => { "nested_2" => { "leaf_3_also" => "val3a" } })
      @deep_hash.should == { :nested_1 => { :nested_2  => { :leaf_3_also  => "val3a", :leaf_3 => "val3" }, :leaf_2 => "val2" }, :leaf_at_top => "val1b" }
    end
    it "preserves values in the original" do
      @deep_hash.deep_merge! :other_key => "other_val"
      @deep_hash[:nested_1][:leaf_2].should == "val2"
      @deep_hash[:other_key].should == "other_val"
    end
    # it "converts all Hash values into DeepHashes if param is a Hash"  do
    #   @deep_hash.deep_merge!({:nested_1 => { :nested_2 => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
    #   @deep_hash[:nested_1].should be_an_instance_of(DeepHash)
    #   @deep_hash[:nested_1][:nested_2].should be_an_instance_of(DeepHash)
    #   @deep_hash[:other1].should be_an_instance_of(DeepHash)
    # end
    it "replaces values from the given DeepHash" do
      @deep_hash.deep_merge!(:nested_1 => { :nested_2 => { :leaf_3 => "new_val3" }, :leaf_2 => { "other2" => "other_val2" }})
      @deep_hash[:nested_1][:nested_2][:leaf_3].should == 'new_val3'
      @deep_hash[:nested_1][:leaf_2].should == { :other2 => "other_val2" }
    end

    it "replaces values from the given DeepHash" do
      @deep_hash.deep_merge!(:nested_1 => { :nested_2 => { :leaf_3 => [] }, :leaf_2 => nil }, :leaf_at_top => '')
      @deep_hash[:nested_1][:nested_2][:leaf_3].should == []
      @deep_hash[:nested_1][:leaf_2].should == "val2"
      @deep_hash[:leaf_at_top].should == ""
    end
  end

  describe "#deep_set" do
    it 'should set a new value (single arg)' do
      @deep_hash.deep_set :new_key, 'new_val'
      @deep_hash[:new_key].should == 'new_val'
    end
    it 'should set a new value (multiple args)' do
      @deep_hash.deep_set :nested_1, :nested_2, :new_key, 'new_val'
      @deep_hash[:nested_1][:nested_2][:new_key].should == 'new_val'
    end
    it 'should replace an existing value (single arg)' do
      @deep_hash.deep_set :leaf_at_top, 'new_val'
      @deep_hash[:leaf_at_top].should == 'new_val'
    end
    it 'should replace an existing value (multiple args)' do
      @deep_hash.deep_set :nested_1, :nested_2, 'new_val'
      @deep_hash[:nested_1][:nested_2].should == 'new_val'
    end
    it 'should auto-vivify intermediate hashes' do
      @deep_hash.deep_set :one, :two, :three, :four, 'new_val'
      @deep_hash[:one][:two][:three][:four].should == 'new_val'
    end
  end

  describe "#deep_delete" do
    it 'should remove the key from the array (multiple args)' do
      @deep_hash.deep_delete(:nested_1)
      @deep_hash[:nested_1].should be_nil
      @deep_hash.should == { :leaf_at_top => 'val1b'}
    end
    it 'should remove the key from the array (multiple args)' do
      @deep_hash.deep_delete(:nested_1, :nested_2, :leaf_3)
      @deep_hash[:nested_1][:nested_2][:leaf_3].should be_nil
      @deep_hash.should == {:leaf_at_top => "val1b", :nested_1 => {:leaf_2 => "val2", :nested_2 => {}}}
    end
    it 'should return the value if present (single args)' do
      returned_val = @deep_hash.deep_delete(:leaf_at_top)
      returned_val.should == 'val1b'
    end
    it 'should return the value if present (multiple args)' do
      returned_val = @deep_hash.deep_delete(:nested_1, :nested_2, :leaf_3)
      returned_val.should == 'val3'
    end
    it 'should return nil if the key is absent (single arg)' do
      returned_val = @deep_hash.deep_delete(:nested_1, :nested_2, :missing_key)
      returned_val.should be_nil
    end
    it 'should return nil if the key is absent (multiple args)' do
      returned_val = @deep_hash.deep_delete(:missing_key)
      returned_val.should be_nil
    end
  end

end
