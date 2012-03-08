require 'mattock/configuration-store'
require 'file-sandbox'

describe Mattock::ConfigurationStore do
  include FileSandbox
  let :store do
    described_class.new("test", "default_configs").tap do |store|
      store.register_search_path('./Rakefile')
    end
  end

  before :each do
    sandbox["default_configs/preferences.yaml"].contents = YAML::dump({"defaults" => "a", "local" => "b"})
    sandbox[".test/preferences.yaml"].contents = YAML::dump({"local" => "c"})
  end

  it "should make default configs available" do
    store.user_preferences["defaults"].should == "a"
  end

  it "should make local configs available" do
    store.user_preferences["local"].should == "c"
  end
end
