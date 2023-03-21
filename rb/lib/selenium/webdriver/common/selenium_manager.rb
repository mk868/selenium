# frozen_string_literal: true

# Licensed to the Software Freedom Conservancy (SFC) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The SFC licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'open3'

module Selenium
  module WebDriver
    #
    # Wrapper for getting information from the Selenium Manager binaries.
    # This implementation is still in beta, and may change.
    # @api private
    #
    class SeleniumManager
      BIN_PATH = '../../../../../bin'

      class << self
        # @param [Options] options browser options.
        # @return [String] the path to the correct driver.
        def driver_path(options)
          unless options.is_a?(Options)
            raise ArgumentError, "SeleniumManager requires a WebDriver::Options instance, not a #{options.inspect}"
          end

          command = [binary, '--browser', options.browser_name, '--output', 'json']
          if options.browser_version
            command << '--browser-version'
            command << options.browser_version
          end
          if options.respond_to?(:binary) && !options.binary.nil?
            command << '--browser-path'
            command << "\"#{options.binary.gsub('\ ', ' ').gsub(' ', '\ ')}\""
          end

          location = run(command.join(' '))
          WebDriver.logger.debug("Driver found at #{location}")
          Platform.assert_executable location

          location
        end

        private

        # @return [String] the path to the correct selenium manager
        def binary
          @binary ||= begin
            path = File.expand_path(BIN_PATH, __FILE__)
            path << if Platform.windows?
                      '/windows/selenium-manager.exe'
                    elsif Platform.mac?
                      '/macos/selenium-manager'
                    elsif Platform.linux?
                      '/linux/selenium-manager'
                    end
            location = File.expand_path(path, __FILE__)
            unless location.is_a?(String) && File.exist?(location) && File.executable?(location)
              raise Error::WebDriverError, 'Unable to obtain Selenium Manager'
            end

            WebDriver.logger.debug("Selenium Manager found at #{location}")
            location
          end
        end

        def run(command)
          WebDriver.logger.debug("Executing Process #{command}")

          begin
            stdout, stderr, status = Open3.capture3(command)
            json_output = JSON.parse(stdout)
            result = json_output['result']['message']
          rescue StandardError => e
            raise Error::WebDriverError, "Unsuccessful command executed: #{command}", e.message
          end

          if status.exitstatus.positive?
            raise Error::WebDriverError, "Unsuccessful command executed: #{command}\n#{result}#{stderr}"
          end

          json_output['logs'].each do |log|
            WebDriver.logger.warn(log['message']) if log['level'] == 'WARN'
          end

          result
        end
      end
    end # SeleniumManager
  end # WebDriver
end # Selenium
