require 'mattock'

describe Mattock::Configurable do
  class TestSuperStruct
    include Mattock::Configurable

    setting(:three, 3)
    required_field(:four)
  end

  class TestStruct < TestSuperStruct
    settings(:one => 1, :two => nested(:a => "a"){ required_field(:b)} )
    nil_field(:five)
  end

  subject do
    TestStruct.new.setup_defaults
  end

  it "should set defaults" do
    subject.one.should == 1
    subject.two.a.should == "a"
    subject.three.should == 3
    subject.five.should be_nil
  end

  it "#to_hash" do
    hash = subject.to_hash
    hash[:one].should == 1
    hash[:two][:a].should == "a"
  end

  it "should complain about unset required fields" do
    expect do
      subject.check_required
    end.to raise_error
  end

  it "should complain about unset nested required fields" do
    subject.four = 4
    expect do
      subject.check_required
    end.to raise_error
  end

  it "should not complain when required fields are set" do
    subject.four = 4
    subject.two.b = "b"
    expect do
      subject.check_required
    end.to_not raise_error
  end

  describe "with DirectoryStructure" do
    class DirectoryThing
      include Mattock::Configurable
      include DirectoryStructure

      dir(:ephemeral_mountpoint,
          dir(:bundle_workdir, "bundle_workdir",
              path(:bundle_manifest),
              path(:credentials_archive, "aws-creds.tar.gz"),
              dir(:credentials_dir, "aws-creds",
                  path(:private_key_file, "pk.pem"),
                  path(:certificate_file, "cert.pem")
                 )
             )
         )
    end

    def subject
      DirectoryThing.new.tap do |thing|
        thing.setup_defaults
      end
    end

    it "should complain about missing fields" do
      expect do
        subject.check_required
      end.to raise_error /Required field/
    end

    describe "with root path configured, but missing a relative path" do
      def subject
        DirectoryThing.new.tap do |thing|
          thing.setup_defaults
          thing.ephemeral_mountpoint.absolute_path = "/tmp"
          thing.resolve_paths
        end
      end

      it "should complain about missing fields" do
        expect do
          subject.check_required
        end.to raise_error /Required field/
      end
    end

    describe "with required paths configured" do
      def subject
        DirectoryThing.new.tap do |thing|
          thing.setup_defaults
          thing.ephemeral_mountpoint.absolute_path = "/tmp"
          thing.bundle_manifest.relative_path = "image.manifest.xml"
          thing.resolve_paths
        end
      end

      it "should not complain about required fields" do
        expect do
          subject.check_required
        end.not_to raise_error
      end

      its("certificate_file.absolute_path"){ should == "/tmp/bundle_workdir/aws-creds/cert.pem" }
      its("bundle_manifest.absolute_path"){ should == "/tmp/bundle_workdir/image.manifest.xml" }
      its("credentials_dir.absolute_path"){ should == "/tmp/bundle_workdir/aws-creds" }
    end
  end

  describe "multiple instances" do
    class MultiSource
      include Mattock::Configurable

      setting :one, 1
      setting :nest, nested{
        setting :two, 2
      }
    end

    let :first do
      MultiSource.new.setup_defaults
    end

    let :second do
      MultiSource.new.setup_defaults
    end

    before :each do
      first.one = "one"
      first.nest.two = "two"
      second
    end

    it "should not have any validation errors" do
      expect do
        first.check_required
        second.check_required
      end.not_to raise_error
    end

    it "should accurately reflect settings" do
      first.one.should == "one"
      second.one.should == 1

      first.nest.two.should == "two"
      second.nest.two.should == 2
    end
  end

  describe "copying settings" do
    class LeftStruct
      include Mattock::Configurable

      setting(:normal, 1)
      setting(:no_copy, 2).isnt(:copiable)
      setting(:no_proxy, 3).isnt(:proxiable)
      setting(:no_nothing, 4).isnt(:copiable).isnt(:proxiable)
      setting(:not_on_target, 5)
    end

    class RightStruct
      include Mattock::Configurable

      required_fields(:normal, :no_copy, :no_proxy, :no_nothing)
    end

    let :left do
      LeftStruct.new.setup_defaults
    end

    let :right do
      RightStruct.new.setup_defaults
    end

    it "should not copy no_copy" do
      left.copy_settings.to(right)
      right.unset?(right.normal).should be_false
      right.normal.should == 1
      right.unset?(right.no_copy).should be_true
      right.unset?(right.no_proxy).should be_false
      right.no_proxy.should == 3
      right.unset?(right.no_nothing).should be_true
    end

    it "should not proxy no_proxy" do
      left.proxy_settings.to(right)
      right.unset?(right.normal).should be_false
      right.normal.should == 1
      right.unset?(right.no_copy).should be_false
      right.no_copy.should == 2
      right.unset?(right.no_proxy).should be_true
      right.unset?(right.no_nothing).should be_true
    end
  end
end
