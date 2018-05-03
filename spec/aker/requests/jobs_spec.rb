# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Aker::JobsController, type: :request, aker: true do
  let!(:job) { create(:aker_job) }
  let(:url) { "#{Rails.configuration.aker['urls']['work_orders']}/jobs/#{job.aker_job_id}" }
  let(:request) { RestClient::Request.new(method: :put, url: url) }

  scenario 'start a job' do
    allow(RestClient::Request).to receive(:execute).with(
      verify_ssl: false,
      method: :put,
      url: "#{url}/start",
      headers: { content_type: :json },
      proxy: nil
    ).and_return(
      RestClient::Response.create({ job: { id: job.aker_job_id } }.to_json,
                                  Net::HTTPResponse.new('1.1', 200, ''), request)
    )

    put start_aker_job_path(job.aker_job_id)

    expect(response).to have_http_status :ok
  end

  scenario 'complete a job' do
    allow(RestClient::Request).to receive(:execute).with(
      verify_ssl: false,
      method: :put,
      url: "#{url}/complete",
      payload: {
        job: { job_id: job.aker_job_id, comment: 'Complete it' }
      }.to_json,
      headers: { content_type: :json },
      proxy: nil
    ).and_return(
      RestClient::Response.create({ job: { id: job.aker_job_id, comment: 'Complete it' } }.to_json,
                                  Net::HTTPResponse.new('1.1', 200, ''), request)
    )

    put complete_aker_job_path(job.aker_job_id), params: { comment: 'Complete it' }

    expect(response).to have_http_status :ok
  end

  scenario 'cancel a job' do
    allow(RestClient::Request).to receive(:execute).with(
      verify_ssl: false,
      method: :put,
      url: "#{url}/cancel",
      payload: {
        job: { job_id: job.aker_job_id, comment: 'Cancel it' }
      }.to_json,
      headers: { content_type: :json },
      proxy: nil
    ).and_return(RestClient::Response.create({
      job: { id: job.aker_job_id, comment: 'Cancel it' }
    }.to_json,
                                             Net::HTTPResponse.new('1.1', 200, ''), request))

    put cancel_aker_job_path(job.aker_job_id), params: { comment: 'Cancel it' }

    expect(response).to have_http_status :ok
  end
end
