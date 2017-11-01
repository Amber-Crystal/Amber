{% if flag?(:run_build_tests) %}
require "../../spec_helper"

module Amber::CLI
  begin
    describe "building a generated app" do
      ENV["AMBER_ENV"] = "test"
      MainCommand.run ["new", TESTING_APP]
      Dir.cd(TESTING_APP)
      MainCommand.run ["generate", "scaffold", "Animal", "name:string"]
      Amber::CLI::Spec.prepare_yaml(Dir.current)

      build_result = `shards build`
      db_result = `amber db drop create migrate`

      it `generates a binary` do
        File.exists?("bin/#{TEST_APP_NAME}").should be_true
      end

      context "crystal spec" do
        spec_result = `crystal spec`

        it "can be executed" do
          spec_result.should contain "Finished in"
        end

        it "has no errors" do
          spec_result.should_not contain "Error in line"
        end

        it "has no failures" do
          spec_result.should_not contain "Failures"
        end
      end
    end
  ensure
    Amber::CLI::Spec.cleanup
  end
end
{% end %}
