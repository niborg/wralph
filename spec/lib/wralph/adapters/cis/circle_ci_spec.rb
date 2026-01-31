# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wralph::Adapters::Cis::CircleCi do
  let(:pr_number) { 42 }
  let(:repo_owner) { 'acme' }
  let(:repo_name) { 'widgets' }
  let(:api_token) { 'test-token' }
  let(:branch_name) { 'issue-123' }
  let(:project_slug) { "gh/#{repo_owner}/#{repo_name}" }

  before do
    allow(Wralph::Interfaces::Shell).to receive(:run_command)
      .with("gh pr view #{pr_number} --json headRefName -q .headRefName")
      .and_return([branch_name, '', true])
  end

  describe '.build_status' do
    it 'exits when api_token is missing' do
      expect(Wralph::Interfaces::Print).to receive(:error).with('CircleCI requires ci_api_token in .wralph/secrets.yaml')
      expect(Wralph::Interfaces::Print).to receive(:error).with('Please add your CircleCI API token to .wralph/secrets.yaml:')
      expect(Wralph::Interfaces::Print).to receive(:error).with('  ci_api_token: your-token-here')

      expect { described_class.build_status(pr_number, repo_owner, repo_name, nil) }.to raise_error(SystemExit)
      expect(Wralph::Interfaces::Shell).not_to have_received(:run_command).with(/circleci\.com/)
    end

    it "returns 'not_found' when pipeline request fails" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(status: 404)

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('not_found')
    end

    it "returns 'not_found' when pipeline has no items" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token})
                                      .to_return(status: 200, body: '{"items":[]}', headers: {'Content-Type' => 'application/json'})

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('not_found')
    end

    it "returns 'running' when pipeline state is running" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1', state: 'running'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('running')
    end

    it "returns 'success' when workflow status is success" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1', state: 'errored'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'success'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('success')
    end

    it "returns 'failed' when workflow status is failed" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1', state: 'errored'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'failed'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('failed')
    end

    it "returns 'unknown' when workflow request fails" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1', state: 'errored'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(status: 404)

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('unknown')
    end

    it "returns 'unknown' when pipeline JSON is invalid" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token})
                                      .to_return(status: 200, body: 'not json')

      result = described_class.build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

      expect(result).to eq('unknown')
    end
  end

  describe '.wait_for_build' do
    it 'returns true when build_status returns success on first check' do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1', state: 'errored'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'success'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.wait_for_build(pr_number, repo_owner, repo_name, api_token)

      expect(result).to be true
    end

    it 'returns false when build_status returns failed' do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1', state: 'errored'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'failed'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.wait_for_build(pr_number, repo_owner, repo_name, api_token)

      expect(result).to be false
    end
  end

  describe '.build_failures' do
    it "exits when api_token is missing" do
      expect(Wralph::Interfaces::Print).to receive(:error).with('CircleCI requires ci_api_token in .wralph/secrets.yaml')
      expect(Wralph::Interfaces::Print).to receive(:error).with('Please add your CircleCI API token to .wralph/secrets.yaml:')
      expect(Wralph::Interfaces::Print).to receive(:error).with('  ci_api_token: your-token-here')

      expect { described_class.build_failures(pr_number, repo_owner, repo_name, nil) }.to raise_error(SystemExit)
    end

    it "returns 'Could not fetch pipeline' when pipeline request fails" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(status: 500)

      result = described_class.build_failures(pr_number, repo_owner, repo_name, api_token)

      expect(result).to eq('Could not fetch pipeline')
    end

    it "returns 'No pipeline found' when pipeline has no items" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token})
                                      .to_return(status: 200, body: '{"items":[]}', headers: {'Content-Type' => 'application/json'})

      result = described_class.build_failures(pr_number, repo_owner, repo_name, api_token)

      expect(result).to eq('No pipeline found')
    end

    it "returns 'No workflow found' when workflow has no items" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token})
                                      .to_return(status: 200, body: '{"items":[]}', headers: {'Content-Type' => 'application/json'})

      result = described_class.build_failures(pr_number, repo_owner, repo_name, api_token)

      expect(result).to eq('No workflow found')
    end

    it "returns 'All jobs passed' when no failed jobs" do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'
      jobs_url = 'https://circleci.com/api/v2/workflow/wf-1/job'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'wf-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, jobs_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'success', name: 'build', job_number: 1}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.build_failures(pr_number, repo_owner, repo_name, api_token)

      expect(result).to eq("All jobs passed for branch #{branch_name}.")
    end

    it 'returns failure details when jobs have failed' do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'
      jobs_url = 'https://circleci.com/api/v2/workflow/wf-1/job'
      v1_url = "https://circleci.com/api/v1.1/project/github/#{repo_owner}/#{repo_name}/123"

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'wf-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, jobs_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'failed', name: 'rspec', job_number: 123}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, v1_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {steps: [{name: 'run-tests', actions: [{failed: true, output_url: nil}]}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.build_failures(pr_number, repo_owner, repo_name, api_token)

      expect(result).to include('Job: rspec (#123) failed.')
      # FAILED STEP and LOG TAIL are only added when output_url is present
    end

    it 'includes log tail when failed step has output_url' do
      pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
      workflow_url = 'https://circleci.com/api/v2/pipeline/pipeline-1/workflow'
      jobs_url = 'https://circleci.com/api/v2/workflow/wf-1/job'
      v1_url = "https://circleci.com/api/v1.1/project/github/#{repo_owner}/#{repo_name}/456"
      output_url = 'https://output.circleci.com/some-log-id'

      stub_request(:get, pipeline_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'pipeline-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, workflow_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{id: 'wf-1'}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, jobs_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {items: [{status: 'failed', name: 'build', job_number: 456}]}.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, v1_url).with(headers: {'Circle-Token' => api_token}).to_return(
        status: 200,
        body: {
          steps: [{name: 'run-build', actions: [{failed: true, output_url: output_url}]}]
        }.to_json,
        headers: {'Content-Type' => 'application/json'}
      )
      stub_request(:get, output_url).to_return(
        status: 200,
        body: [{'message' => 'line 1'}, {'message' => 'line 2'}, {'message' => 'line 3'}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

      result = described_class.build_failures(pr_number, repo_owner, repo_name, api_token)

      expect(result).to include('Job: build (#456) failed.')
      expect(result).to include('FAILED STEP: run-build')
      expect(result).to include('LOG TAIL:')
      expect(result).to include("line 1\nline 2\nline 3")
    end
  end
end
