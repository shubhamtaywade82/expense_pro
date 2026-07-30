class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  around_perform do |_job, block|
    block.call
  ensure
    Current.reset
  end
end
