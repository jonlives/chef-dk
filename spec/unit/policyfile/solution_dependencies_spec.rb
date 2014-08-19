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
require 'chef-dk/policyfile/solution_dependencies'

describe ChefDK::Policyfile::SolutionDependencies do

  def c(constraint_str)
    Semverse::Constraint.new(constraint_str)
  end

  let(:dependency_data) { {} }

  let(:solution_dependencies) do
    s = described_class.new
    s.consume_lock_data(dependency_data)
    s
  end

  it "has a list of dependencies declared in the Policyfile" do
    expect(solution_dependencies.policyfile_dependencies).to eq([])
  end

  it "has a map of dependencies declared by cookbooks" do
    expect(solution_dependencies.cookbook_dependencies).to eq({})
  end

  context "when populated with dependency data from a lockfile" do

    let(:dependency_data) do
      {
        "Policyfile" => [
          [ "nginx", "~> 1.0"], ["postgresql", ">= 0.0.0" ]
        ],
        "dependencies" => {
          "nginx (1.2.3)" => [ ["apt", "~> 2.3"], ["yum", "~>3.4"] ],
          "apt (2.5.6)" => [],
          "yum (3.4.1)" => [],
          "postgresql (5.0.0)" => []
        }
      }
    end

    it "has a list of dependencies from the policyfile" do
      expected = [ "nginx", c("~> 1.0")], ["postgresql", c(">= 0.0.0") ]
      expect(solution_dependencies.policyfile_dependencies).to eq(expected)
    end

    it "has a list of dependencies from cookbooks" do
      expected = {
        "nginx (1.2.3)" => [ ["apt", c( "~> 2.3" )], ["yum", c( "~>3.4" )] ],
        "apt (2.5.6)" => [],
        "yum (3.4.1)" => [],
        "postgresql (5.0.0)" => []
      }
      expect(solution_dependencies.cookbook_deps_for_lock).to eq(expected)
    end

  end

  context "when populated with dependency data" do

    before do
      solution_dependencies.add_policyfile_dep("nginx", "~> 1.0")
      solution_dependencies.add_policyfile_dep("postgresql", ">= 0.0.0")
      solution_dependencies.add_cookbook_dep("nginx", "1.2.3", [ ["apt", "~> 2.3"], ["yum", "~>3.4"] ])
      solution_dependencies.add_cookbook_dep("apt", "2.5.6", [])
      solution_dependencies.add_cookbook_dep("yum", "3.4.1", [])
      solution_dependencies.add_cookbook_dep("postgresql", "5.0.0", [])
    end

    it "has a list of dependencies from the Policyfile" do
      expected = [ "nginx", c("~> 1.0")], ["postgresql", c(">= 0.0.0") ]
      expect(solution_dependencies.policyfile_dependencies).to eq(expected)
    end

    it "has a list of dependencies from cookbooks" do
      expected = {
        "nginx (1.2.3)" => [ ["apt", c( "~> 2.3" )], ["yum", c( "~>3.4" )] ],
        "apt (2.5.6)" => [],
        "yum (3.4.1)" => [],
        "postgresql (5.0.0)" => []
      }
      expect(solution_dependencies.cookbook_deps_for_lock).to eq(expected)
    end

    describe "checking for dependency conflicts" do

      it "does not raise if a cookbook does not conflict" do
        expect(solution_dependencies.test_conflict!('foo', '1.0.0')).to be(false)
      end

      it "does not raise if a cookbook that's in the dependency set with a different version doesn't conflict" do
        expect(solution_dependencies.test_conflict!('yum', '3.5.0')).to be(false)
      end

      it "raises when a cookbook conflicts with a Policyfile constraint" do
        expected_message = "Cookbook nginx (2.0.0) conflicts with other dependencies:\nPolicyfile depends on nginx ~> 1.0"
        expect { solution_dependencies.test_conflict!('nginx', '2.0.0') }.to raise_error(ChefDK::DependencyConflict, expected_message)
      end

      it "raises when a cookbook conflicts with another cookbook's dependency constraint" do
        expected_message = "Cookbook apt (3.0.0) conflicts with other dependencies:\nnginx (1.2.3) depends on apt ~> 2.3"
        expect { solution_dependencies.test_conflict!('apt', '3.0.0') }.to raise_error(ChefDK::DependencyConflict, expected_message)
      end
    end
  end

end
