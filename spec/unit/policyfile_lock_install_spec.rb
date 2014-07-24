#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'chef-dk/policyfile_lock.rb'

describe ChefDK::PolicyfileLock, "installing cookbooks from a lockfile" do

  let(:cache_path) do
    File.expand_path("spec/unit/fixtures/cookbook_cache", project_root)
  end

  let(:policyfile_lock_path) { "/fakepath/Policyfile.lock.json" }

  let(:local_cookbooks_root) { File.join(fixtures_path, "local_path_cookbooks") }

  let(:name) { "application-server" }

  let(:run_list) { [ 'recipe[erlang::default]', 'recipe[erchef::prereqs]', 'recipe[erchef::app]' ] }

  let(:storage_config) do
    ChefDK::Policyfile::StorageConfig.new( cache_path: cache_path, relative_paths_root: local_cookbooks_root )
  end

  let(:lock_generator) do
    ChefDK::PolicyfileLock.build(storage_config) do |policy|

      policy.name = name

      policy.run_list = run_list

      policy.cached_cookbook("foo") do |c|
        c.origin = "https://artifact-server.example/foo/1.0.0"
        c.cache_key = "foo-1.0.0"
        c.source_options = { artifactserver: "https://artifact-server.example/foo/1.0.0", version: "1.0.0" }
      end

      policy.local_cookbook("local-cookbook") do |c|
        c.source = "local-cookbook"
        c.source_options = { path: "local-cookbook" }
      end

    end
  end

  let(:lock_data) do
    lock_generator.to_lock
  end

  let(:policyfile_lock) do
    ChefDK::PolicyfileLock.new(storage_config).build_from_lock_data(lock_data)
  end

  describe "Populating a PolicyfileLock from a lockfile data structure" do

    it "imports the name attribute" do
      expect(policyfile_lock.name).to eq(name)
    end

    it "imports the run_list attribute" do
      expect(policyfile_lock.run_list).to eq(run_list)
    end

    it "imports cached cookbook lock data" do
      expect(policyfile_lock.cookbook_locks).to have_key("foo")
      cookbook_lock = policyfile_lock.cookbook_locks["foo"]
      expect(cookbook_lock.name).to eq("foo")
      expect(cookbook_lock.cache_key).to eq("foo-1.0.0")
      expect(cookbook_lock.version).to eq("1.0.0")
      expect(cookbook_lock.identifier).to eq("c8a81f2cf2b09f26909df549a477f515bb75ec89")
      expect(cookbook_lock.dotted_decimal_identifier).to eq("56479847193686175.10855057214514295.269473688185993")
      expect(cookbook_lock.origin).to eq("https://artifact-server.example/foo/1.0.0")
      expect(cookbook_lock.source_options).to eq({ artifactserver: "https://artifact-server.example/foo/1.0.0", version: "1.0.0" })
      expect(cookbook_lock.cookbook_location_spec.version_constraint).to eq(Semverse::Constraint.new("= 1.0.0"))
    end

    it "imports local cookbook lock data" do
      expect(policyfile_lock.cookbook_locks).to have_key("local-cookbook")
      cookbook_lock = policyfile_lock.cookbook_locks["local-cookbook"]
      expect(cookbook_lock.name).to eq("local-cookbook")
      expect(cookbook_lock.version).to eq("2.3.4")
      expect(cookbook_lock.identifier).to eq("3b0f0f73d291dc4cc763f2f5b14806b4fcb8dc25")
      expect(cookbook_lock.dotted_decimal_identifier).to eq("16623582668034524.21611330321887560.7374403853349")
      expect(cookbook_lock.source).to eq("local-cookbook")
      expect(cookbook_lock.source_options).to eq({ path: "local-cookbook" })
      expect(cookbook_lock.cookbook_location_spec.version_constraint).to eq(Semverse::Constraint.new("= 2.3.4"))
    end

  end

  describe "installing cookbooks" do

    let(:remote_cookbook_lock) { policyfile_lock.cookbook_locks["foo"] }

    let(:local_cookbook_lock) { policyfile_lock.cookbook_locks["local-cookbook"] }

    it "configures the cookbook location spec for a remote cookbook" do
      location_spec = remote_cookbook_lock.cookbook_location_spec
      expect(location_spec).to be_an_instance_of(ChefDK::Policyfile::CookbookLocationSpecification)
      expect(location_spec.uri).to eq("https://artifact-server.example/foo/1.0.0")
      expect(location_spec.source_options[:version]).to eq("1.0.0")
    end

    it "configures the installer for a local cookbook" do
      location_spec = local_cookbook_lock.cookbook_location_spec
      expect(location_spec).to be_an_instance_of(ChefDK::Policyfile::CookbookLocationSpecification)

      expect(location_spec.relative_path).to eq('local-cookbook')
    end


    it "ensures the cookbooks are installed" do
      expect(remote_cookbook_lock.cookbook_location_spec).to receive(:ensure_cached)
      expect(local_cookbook_lock.cookbook_location_spec).to receive(:ensure_cached)

      policyfile_lock.install_cookbooks
    end

  end

end
