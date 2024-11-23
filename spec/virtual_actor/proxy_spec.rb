require 'spec_helper'
require_relative '../../lib/virtual_actor/proxy'
require_relative '../fixtures/counter_actor'

RSpec.describe VirtualActor::Proxy do
  let(:actor_id) { 'test_proxy' }
  let(:proxy) { described_class.new(actor_id, CounterActor) }
  let(:actor) { instance_double(CounterActor) }
  let(:actor_class) { class_double(CounterActor, exposed_methods: [:increment, :decrement, :custom_method]) }

  before do
    # Mock external dependencies
    allow(VirtualActor::Registry.instance).to receive(:create_or_get_actor).and_return(actor)
    allow(VirtualActor::Registry.instance).to receive(:count_actors_of_type).and_return(1)
    allow(actor).to receive(:send_message).and_return(1)
    allow(actor).to receive(:class).and_return(actor_class)
  end

  describe '#method_missing' do
    context 'with exposed methods' do
      it 'forwards increment to actor' do
        expect(actor).to receive(:send_message).with(method: :increment, args: [])
        proxy.increment
      end

      it 'forwards decrement to actor' do
        expect(actor).to receive(:send_message).with(method: :decrement, args: [])
        proxy.decrement
      end
    end

    context 'with arguments' do
      it 'forwards arguments to actor' do
        expect(actor).to receive(:send_message).with(method: :custom_method, args: [1, 2])
        proxy.custom_method(1, 2)
      end
    end

    context 'with undefined methods' do
      it 'raises NoMethodError' do
        expect { proxy.undefined_method }.to raise_error(NoMethodError)
      end
    end
  end

  describe 'actor management' do
    it 'creates actor through registry' do
      expect(VirtualActor::Registry.instance).to receive(:create_or_get_actor).with(actor_id, CounterActor)
      proxy.increment
    end

    it 'reuses existing actor' do
      expect(VirtualActor::Registry.instance).to receive(:create_or_get_actor).once
      proxy.increment
      proxy.increment
    end
  end
end
