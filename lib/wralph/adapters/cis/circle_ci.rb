# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../../interfaces/shell'
require_relative '../../interfaces/print'

module Wralph
  module Adapters
    module Cis
      module CircleCi
        def self.http_get(url, api_token: nil)
          uri = URI(url)
          req = Net::HTTP::Get.new(uri)
          req['Circle-Token'] = api_token if api_token
          res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
          [res.body, res.is_a?(Net::HTTPSuccess)]
        end

        # Get CircleCI build status for a PR
        def self.build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)
          unless api_token
            Interfaces::Print.error 'ci_api_token is not set in .wralph/secrets.yaml'
            return nil
          end

          # Get the branch name from the PR
          branch_name, = Interfaces::Shell.run_command("gh pr view #{pr_number} --json headRefName -q .headRefName")
          branch_name = branch_name.strip
          Interfaces::Print.info "Checking CircleCI build for branch: #{branch_name}" if verbose && $stderr.respond_to?(:puts)

          # Get the pipeline for this branch
          project_slug = "gh/#{repo_owner}/#{repo_name}"
          pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"

          stdout, success = http_get(pipeline_url, api_token: api_token)
          unless success
            Interfaces::Print.warning "No CircleCI pipeline found for branch #{branch_name}" if verbose
            return 'not_found'
          end

          begin
            pipeline_data = JSON.parse(stdout)
            pipeline_item = pipeline_data['items']&.first
            return 'not_found' unless pipeline_item

            pipeline_id = pipeline_item['id']
            pipeline_state = pipeline_item['state']

            Interfaces::Print.info "Pipeline ID: #{pipeline_id}, State: #{pipeline_state}" if verbose

            return 'running' if %w[running pending].include?(pipeline_state)

            # Get workflow details to check if it succeeded
            workflow_url = "https://circleci.com/api/v2/pipeline/#{pipeline_id}/workflow"
            stdout, success = http_get(workflow_url, api_token: api_token)
            unless success
              Interfaces::Print.warning "No workflow found for pipeline #{pipeline_id}" if verbose
              return 'unknown'
            end

            workflow_data = JSON.parse(stdout)
            workflow_item = workflow_data['items']&.first
            unless workflow_item
              Interfaces::Print.warning "No workflow found for pipeline #{pipeline_id}" if verbose
              return 'unknown'
            end

            workflow_status = workflow_item['status']&.strip
            Interfaces::Print.info "Workflow status: #{workflow_status}" if verbose

            workflow_status
          rescue JSON::ParserError => e
            Interfaces::Print.warning "Failed to parse JSON response: #{e.message}" if verbose
            'unknown'
          end
        end

        # Wait for CircleCI build to complete
        def self.wait_for_build(pr_number, repo_owner, repo_name, api_token)
          max_wait_time = 3600 # 1 hour max wait
          wait_interval = 30   # Check every 30 seconds
          elapsed = 0

          Interfaces::Print.info 'Waiting for CircleCI build to complete...'

          last_status = nil
          while elapsed < max_wait_time
            # Get status quietly first to check if it changed
            status = build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

            # If status hasn't changed since last check, just print a dot
            if last_status && last_status == status
              print '.'
              sleep wait_interval
              elapsed += wait_interval
              next
            end

            # Status changed (or first check) - get verbose output with pipeline/workflow details
            status = build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)

            case status
            when 'success'
              Interfaces::Print.success 'CircleCI build passed!'
              return true
            when 'failed', 'error', 'canceled', 'unauthorized'
              Interfaces::Print.warning "CircleCI build failed with status: #{status}"
              return false
            when 'running', 'on_hold'
              Interfaces::Print.info "Build still running... (elapsed: #{elapsed}s)"
            when 'not_found'
              Interfaces::Print.warning 'Build not found yet, waiting...'
            else
              Interfaces::Print.warning "Unknown build status: #{status}, waiting..."
            end
            sleep wait_interval
            elapsed += wait_interval
            last_status = status
          end

          Interfaces::Print.error 'Timeout waiting for CircleCI build to complete'
          exit 1
          false
        end

        # Get CircleCI build failures
        def self.build_failures(pr_number, repo_owner, repo_name, api_token)
          return 'ci_api_token is not set in .wralph/secrets.yaml' unless api_token

          # 1. Get branch name from PR
          branch_name, = Interfaces::Shell.run_command("gh pr view #{pr_number} --json headRefName -q .headRefName")
          branch_name = branch_name.strip

          # 2. Get the latest pipeline for that branch
          project_slug = "gh/#{repo_owner}/#{repo_name}"
          pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
          stdout, success = http_get(pipeline_url, api_token: api_token)
          return 'Could not fetch pipeline' unless success

          pipeline_id = JSON.parse(stdout)['items']&.first&.[]('id')
          return 'No pipeline found' unless pipeline_id

          # 3. Get the workflow ID
          workflow_url = "https://circleci.com/api/v2/pipeline/#{pipeline_id}/workflow"
          stdout, success = http_get(workflow_url, api_token: api_token)
          workflow_id = JSON.parse(stdout)['items']&.first&.[]('id')
          return 'No workflow found' unless workflow_id

          # 4. Get jobs and filter for failures
          jobs_url = "https://circleci.com/api/v2/workflow/#{workflow_id}/job"
          stdout, success = http_get(jobs_url, api_token: api_token)
          jobs_data = JSON.parse(stdout)

          failed_jobs = jobs_data['items']&.select { |j| %w[failed error].include?(j['status']) }
          return "All jobs passed for branch #{branch_name}." if failed_jobs.nil? || failed_jobs.empty?

          # 5. For each failed job, reach into v1.1 API to get the logs
          failed_jobs.map do |job|
            job_num = job['job_number']
            job_name = job['name']

            # We use v1.1 because v2 does not provide step-level output URLs
            v1_api_url = "https://circleci.com/api/v1.1/project/github/#{repo_owner}/#{repo_name}/#{job_num}"
            v1_stdout, v1_success = http_get(v1_api_url, api_token: api_token)

            log_content = "Job: #{job_name} (##{job_num}) failed."

            if v1_success
              job_details = JSON.parse(v1_stdout)
              # Find the step that actually failed
              failed_step = job_details['steps']&.find { |s| s['actions'].to_a.any? { |a| a['failed'] } }

              if failed_step
                action = failed_step['actions'].find { |a| a['failed'] }
                output_url = action&.[]('output_url')

                if output_url
                  # The output_url provides a JSON array of log lines
                  raw_log_json, = http_get(output_url)
                  begin
                    logs = JSON.parse(raw_log_json)
                    # Join the last 30 lines of the log for context
                    tail_logs = logs.map { |l| l['message'] }.last(30).join("\n")
                    log_content += "\nFAILED STEP: #{failed_step['name']}\n\nLOG TAIL:\n#{tail_logs}"
                  rescue
                    log_content += "\n(Could not parse raw log output)"
                  end
                end
              end
            end

            log_content
          end.join("\n\n" + "=" * 40 + "\n\n")
        end
      end
    end
  end
end
