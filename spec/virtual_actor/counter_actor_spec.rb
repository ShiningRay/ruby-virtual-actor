require 'spec_helper'
require_relative '../fixtures/counter_actor'

RSpec.describe CounterActor do
  let(:actor_id) { 'test_counter' }
  let(:actor) { described_class.new(actor_id) }

  before do
    # Mock Redis and other external dependencies
    allow(VirtualActor::Persistence.instance).to receive(:load_actor_state).and_return(nil)
    allow(VirtualActor::Persistence.instance).to receive(:save_actor_state)
    allow(VirtualActor::Metrics.instance).to receive(:observe_message_duration)
    allow(VirtualActor::Metrics.instance).to receive(:increment_message_counter)
    allow(VirtualActor::Metrics.instance).to receive(:set_actor_count)
  end

  describe 'class configuration' do
    it 'declares state attributes' do
      expect(described_class.state_attrs).to include(:count)
    end

    it 'exposes methods' do
      expect(described_class.exposed_methods).to include(:increment, :decrement)
    end
  end

  describe '.get' do
    it 'returns a proxy for the actor' do
      proxy = described_class.get(actor_id)
      expect(proxy).to be_a(VirtualActor::Proxy)
      expect(proxy.inspect).to include(actor_id)
      expect(proxy.inspect).to include('CounterActor')
    end
  end

  describe 'initialization' do
    it 'sets initial count to 0' do
      expect(actor.count).to eq(0)
    end

    context 'with persisted state' do
      let(:persisted_state) { { count: 5 } }

      before do
        allow(VirtualActor::Persistence.instance).to receive(:load_actor_state).and_return(persisted_state)
      end

      it 'restores state from persistence' do
        expect(described_class.new(actor_id).count).to eq(5)
      end
    end
  end

  describe 'message handling' do
    context 'when incrementing' do
      it 'increases the counter by 1' do
        expect {
          actor.send_message(method: :increment)
        }.to change { actor.count }.by(1)
      end

      it 'returns the new count' do
        expect(actor.send_message(method: :increment)).to eq(1)
      end
    end

    context 'when decrementing' do
      before { actor.send_message(method: :increment) }

      it 'decreases the counter by 1' do
        expect {
          actor.send_message(method: :decrement)
        }.to change { actor.count }.by(-1)
      end

      it 'returns the new count' do
        expect(actor.send_message(method: :decrement)).to eq(0)
      end
    end

    context 'with unexposed method' do
      it 'returns nil' do
        result = actor.send_message(method: :unknown_method)
        expect(result).to be_nil
      end

      it 'logs a warning' do
        expect(actor.logger).to receive(:warn).with(/Method unknown_method is not exposed/)
        actor.send_message(method: :unknown_method)
      end
    end
  end

  describe 'state persistence' do
    it 'saves state after each message' do
      expect(VirtualActor::Persistence.instance).to receive(:save_actor_state).with(actor_id, count: 1)
      actor.send_message(method: :increment)
    end
  end

  describe 'metrics' do
    it 'records message duration' do
      expect(VirtualActor::Metrics.instance).to receive(:observe_message_duration)
        .with(described_class.name, 'increment', kind_of(Float))
      actor.send_message(method: :increment)
    end

    it 'increments message counter' do
      expect(VirtualActor::Metrics.instance).to receive(:increment_message_counter)
        .with(described_class.name, 'increment')
      actor.send_message(method: :increment)
    end
  end
end
