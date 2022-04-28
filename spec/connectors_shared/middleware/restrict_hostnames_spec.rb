#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

describe ConnectorsShared::Middleware::RestrictHostnames do
  let(:localhost_ipv4_url) do
    { :url => Addressable::URI.parse('http://127.0.0.1') }
  end
  let(:localhost_url) do
    { :url => Addressable::URI.parse('http://localhost:8080') }
  end
  let(:localhost_ipv6_url) do
    { :url => Addressable::URI.parse('http://[::1]') }
  end
  let(:external_url) do
    { :url => Addressable::URI.parse('https://google.com') }
  end

  class StubbedApp
    def call(_)
      'it worked'
    end
  end

  subject do
    described_class.new(StubbedApp.new, :allowed_hosts => hosts)
  end

  shared_examples_for 'a blocked call' do
    it 'raises because the address is not allowed' do
      expect { subject.call(env) }.to raise_error(ConnectorsShared::Middleware::RestrictHostnames::AddressNotAllowed)
    end
  end

  shared_examples_for 'an allowed call' do
    it '' do
      expect(subject.call(env)).to eq('it worked')
    end
  end

  context 'by default' do
    let(:hosts) { [] }
    context 'localhost ip4' do
      let(:env) { localhost_ipv4_url }
      it_behaves_like 'a blocked call'
    end

    context 'localhost ipv6' do
      let(:env) { localhost_ipv6_url }
      it_behaves_like 'a blocked call'
    end

    context 'localhost domain' do
      let(:env) { localhost_url }
      it_behaves_like 'a blocked call'
    end

    context 'external domain' do
      let(:env) { external_url }
      it_behaves_like 'a blocked call'
    end
  end

  context 'when localhost URLs are allowed by hostname' do
    let(:hosts) { ['localhost'] }

    context 'localhost ipv4' do
      let(:env) { localhost_ipv4_url }
      it_behaves_like 'an allowed call'
    end

    context 'localhost ipv6' do
      let(:env) { localhost_ipv6_url }
      skip 'jenkins docker does not bind localhost to ipv6' do
        it_behaves_like 'an allowed call'
      end
    end

    context 'localhost domain' do
      let(:env) { localhost_url }
      it_behaves_like 'an allowed call'
    end

    context 'external domain' do
      let(:env) { external_url }
      it_behaves_like 'a blocked call'
    end
  end

  context 'when localhost URLs are allowed by IP' do
    let(:hosts) { ['127.0.0.1'] }

    context 'localhost ipv4' do
      let(:env) { localhost_ipv4_url }
      it_behaves_like 'an allowed call'
    end

    context 'localhost ipv6' do
      let(:env) { localhost_ipv6_url }
      it_behaves_like 'a blocked call'
    end

    context 'localhost domain' do
      let(:env) { localhost_url }
      it_behaves_like 'an allowed call'
    end

    context 'external domain' do
      let(:env) { external_url }
      it_behaves_like 'a blocked call'
    end
  end

  context 'when localhost IPV6 URLs are allowed' do
    let(:hosts) { ['::1'] }

    context 'localhost ipv4' do
      let(:env) { localhost_ipv4_url }
      it_behaves_like 'a blocked call'
    end

    context 'localhost ipv6' do
      let(:env) { localhost_ipv6_url }
      it_behaves_like 'an allowed call'
    end

    context 'localhost domain' do
      let(:env) { localhost_url }
      skip 'jenkins docker does not bind localhost to ipv6' do
        it_behaves_like 'an allowed call'
      end
    end

    context 'external domain' do
      let(:env) { external_url }
      it_behaves_like 'a blocked call'
    end
  end

  context 'when external URLs are allowed by URL' do
    let(:hosts) { ['https://google.com'] }

    context 'localhost ipv4' do
      let(:env) { localhost_ipv4_url }
      it_behaves_like 'a blocked call'
    end

    context 'localhost ipv6' do
      let(:env) { localhost_ipv6_url }
      it_behaves_like 'a blocked call'
    end

    context 'localhost domain' do
      let(:env) { localhost_url }
      it_behaves_like 'a blocked call'
    end

    context 'external domain' do
      let(:env) { external_url }
      it_behaves_like 'an allowed call'

      context 'when DNS lookup changes between initialization and request' do
        let(:fake_ip) { double('bad ip', :ip_address => '203.0.113.0') } # TEST-NET-3
        let(:actual_ip) { double('good ip', :ip_address => '203.0.113.1') }

        before(:each) do
          allow(Addrinfo).to receive(:getaddrinfo).with(external_url[:url].host, nil, :UNSPEC, :STREAM).and_return(
            [fake_ip],
            [actual_ip]
          )
          expect(ConnectorsShared::Logger).to receive(:warn).with('Requested url https://google.com with resolved ip addresses [#<IPAddr: IPv4:203.0.113.1/255.255.255.255>] does not match allowed hosts ["https://google.com"] with resolved ip addresses [#<IPAddr: IPv4:203.0.113.0/255.255.255.255>]. Retrying.').and_call_original
          expect(ConnectorsShared::Logger).to_not receive(:error)
        end

        it_behaves_like 'an allowed call'
      end
    end
  end
end
