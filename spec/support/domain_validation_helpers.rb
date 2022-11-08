module DomainValidationHelpers
  def domain_validation(domain, state, errors)
    {
      :domain => domain,
      :draft => {
        :validation => {
          :state => state,
          :errors => errors
        }
      }
    }
  end
end
