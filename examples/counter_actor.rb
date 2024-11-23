require_relative '../lib/virtual_actor/base_actor'
require_relative '../lib/virtual_actor/registry'
require_relative '../lib/virtual_actor/proxy'
require_relative '../lib/virtual_actor/metrics'
require_relative '../lib/virtual_actor/persistence'
require_relative '../lib/virtual_actor/logging'
require_relative '../lib/virtual_actor/configuration'
require_relative '../lib/virtual_actor/grpc_service'



class CounterActor < VirtualActor::BaseActor
  state :count

  expose :increment
  expose :decrement

  init do 
    @count = 0
  end

  def increment
    @count += 1
    logger.info "Counter incremented to #{@count}"
    @count
  end

  def decrement
    @count -= 1
    logger.info "Counter decremented to #{@count}"
    @count
  end
end
