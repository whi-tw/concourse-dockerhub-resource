# frozen_string_literal: true
require 'spec_helper'
require 'concourse/resource/rss/errors'

describe Concourse::Resource::RSS::Check do
  let(:feed_body) { File.read(fixture('feed/postgres-versions.rss')) }

  before do
    stub_request(:get, 'https://www.postgresql.org/versions.rss').to_return(
      status: 200,
      body: feed_body
    )
  end

  context 'there is no newer version than the current one' do
    let(:current_version_pub_date) { 'Thu, 27 Oct 2016 00:00 +0000' }

    context 'first request (without a current version)' do
      let(:source) { { 'url' => 'https://www.postgresql.org/versions.rss' } }
      let(:version) { nil }

      it 'responds with just the current version' do
        output = subject.call(source, version)
        expect(output).to eq([{ 'pubDate' => Time.parse(current_version_pub_date) }])
      end
    end

    context 'consecutive request (including the current version)' do
      let(:source) { { 'url' => 'https://www.postgresql.org/versions.rss' } }
      let(:version) { { 'pubDate' => current_version_pub_date } }

      it 'responds with just the current version' do
        output = subject.call(source, version)
        expect(output).to eq([{ 'pubDate' => Time.parse(current_version_pub_date) }])
      end
    end
  end

  context 'there are newer versions than the current one' do
    context 'first request (without a current version)' do
      let(:source) { { 'url' => 'https://www.postgresql.org/versions.rss' } }
      let(:version) { nil }

      it 'responds with just the current version' do
        output = subject.call(source, version)
        expect(output).to eq([{ 'pubDate' => Time.parse('2016-10-27 00:00 +0000') }])
      end
    end

    context 'consecutive request (including the current version)' do
      let(:current_version_pub_date) { 'Thu, 24 Jul 2014 00:00 +0000' }
      let(:source) { { 'url' => 'https://www.postgresql.org/versions.rss' } }
      let(:version) { { 'pubDate' => current_version_pub_date } }

      it 'responds with all versions since the requested one' do
        output = subject.call(source, version)

        #
        # 2016-10-27 is a bit special because multiple versions were released
        # on this day. The resource acually collapses all of them and returns
        # only the latest.
        #
        expect(output).to eq([
          { 'pubDate' => Time.parse('2014-07-24 00:00 +0000') },  # 8.4.22
          { 'pubDate' => Time.parse('2015-10-08 00:00 +0000') },  # 9.0.23
          { 'pubDate' => Time.parse('2016-10-27 00:00 +0000') },  # 9.6.1
        ])
      end
    end
  end

  shared_examples 'unavailable' do
    let(:current_version_pub_date) { 'Thu, 27 Oct 2016 00:00 +0000' }

    context 'first request (without a current version)' do
      let(:source) { { 'url' => 'https://www.postgresql.org/versions.rss' } }
      let(:version) { nil }

      it 'responds with an empty list' do
        output = subject.call(source, version)
        expect(output).to be_empty
      end
    end

    context 'consecutive request (including the current version)' do
      let(:source) { { 'url' => 'https://www.postgresql.org/versions.rss' } }
      let(:version) { { 'pubDate' => current_version_pub_date } }

      it 'responds with an empty list' do
        output = subject.call(source, version)
        expect(output).to be_empty
      end
    end
  end

  context 'the feed is not invalid' do
    before do
      allow(Concourse::Resource::RSS::Feed).to receive(:new).
        and_raise Concourse::Resource::RSS::FeedInvalid.new('example.com')
    end

    include_examples 'unavailable'
  end

  context 'the feed is not available' do
    before do
      allow(Concourse::Resource::RSS::Feed).to receive(:new).
        and_raise Concourse::Resource::RSS::FeedUnavailable.new(StandardError.new('not there'))
    end

    include_examples 'unavailable'
  end

  context 'the channel has no items' do
    let(:feed_body) { File.read(fixture('feed/empty.rss')) }
    include_examples 'unavailable'
  end
end
