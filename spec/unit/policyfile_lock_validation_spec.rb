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
# TODO: remove if we don't end up using these:
#require 'shared/setup_git_cookbooks'
#require 'shared/fixture_cookbook_checksums'
#require 'chef-dk/policyfile/storage_config'
require 'chef-dk/policyfile_lock.rb'

describe ChefDK::PolicyfileLock, "validating locked cookbooks" do

  # TODO: most setup here is duplicated from policyfile_lock_install_spec

  let(:cache_path) do
    File.expand_path("spec/unit/fixtures/cookbook_cache", project_root)
  end

  let(:policyfile_lock_path) { "/fakepath/Policyfile.lock.json" }

  let(:local_cookbooks_root) do
    temp_local_path_cookbooks = File.join(tempdir, "local_path_cookbooks")
    FileUtils.cp_r(File.join(fixtures_path, "local_path_cookbooks"), temp_local_path_cookbooks)
    temp_local_path_cookbooks
  end

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

  context "when no cookbooks have changed" do

    it "validation succeeds" do
      expect(policyfile_lock.validate_cookbooks!).to be true
    end

  end

  context "when a :path sourced cookbook is missing" do

    let(:local_cookbook_path) { File.join(local_cookbooks_root, "local-cookbook") }

    before do
      FileUtils.rm_rf(local_cookbook_path)
    end

    it "reports the missing cookbook and fails validation" do
      skip # code below isn't working at the moment
      message = "lockfile `Policyfile.lock.json' contains cookbook `local-cookbook' at path `#{local_cookbook_path}', but nothing is there"
      expect(policyfile_lock.validate_cookbooks!).to raise_error(ChefDK::MissingLockedCookbook, message)
    end

  end

  context "when a :path sourced cookbook has an incorrect name" do

    it "reports the unexpected cookbook and fails validation"

  end

  context "when a :path sourced cookbook has an updated version that violates no dependency constraints" do

    it "updates the version information in the lockfile"

  end

  context "when a :path sourced cookbook has an updated version that violates other dependency constraints" do

    it "reports the dependency conflict and fails validation"

  end


  context "when a cached cookbook is missing" do

    it "reports the missing cookbook and fails validation"

  end

  context "when a :path sourced cookbook has updated content" do

    it "updates the lockfile with the new checksum and validation succeeds"

  end

  context "when a :path source cookbook has added a dependency satisfied by the current cookbook set" do

    it "updates the lockfile with the new checksum and validation succeeds"

  end

  context "when a :path source cookbook has added a dependency not satisfied by the current cookbook set" do

    it "reports the not-satisfied dependency and validation fails"

  end

  context "when a :path source cookbook has modified a dep constraint and the new constraint is satisfied" do

    it "updates the lockfile with the new checksum and validation succeeds"

  end

  context "when a :path source cookbook has modified a dep constraint and the new constraint is not satisfied" do

    it "reports the not-satisfied dependency and validation fails"

  end

  # Cached cookbook is both supermarket and git
  context "when a cached cookbook is modified" do

    # This basically means the user modified the cached cookbook. There's no
    # technical reason we need to be whiny about this, but if we treat it like
    # we would a path cookbook, you could end up with two cookbooks that look
    # like the canonical (e.g.) apache2 1.2.3 cookbook from supermarket with no
    # indication of which is which.
    #
    # We'll treat it like an error, but we need to provide a "pristine"
    # function to let the user recover.
    it "reports the modified cached cookbook and validation fails"
  end
end
