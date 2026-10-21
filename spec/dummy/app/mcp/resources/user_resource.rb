class UserResource < ApplicationResource
  uri "users://{id}"

  def read(id:)
    raise ActionModelContext::Error, "Unknown user" if id == "0"

    { id:, viewer: context[:user] }
  end
end
