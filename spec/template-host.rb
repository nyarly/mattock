require 'mattock'

describe Mattock::TemplateHost do
  let :template_host do
    Object.new.tap do |host|
      host.extend Mattock::TemplateHost
      def host.test_value; "A test value"; end
    end
  end

  it "should be able to do easy templating" do
    template_host.valise = Mattock::ValiseManager.default_valise("spec_help")
    template_host.render("test.erb").should == "Templated: A test value\n"

  end

end
