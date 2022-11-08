module FilterValidationResultHelper
  def filter_validation_result(domain, state, errors)
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
