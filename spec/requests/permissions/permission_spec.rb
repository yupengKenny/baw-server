
describe 'Permission permissions' do
  create_entire_hierarchy

  given_the_route '/projects/{project_id}/permissions' do
    {
      id: reader_permission.id,
      project_id: project.id
    }
  end

  using_the_factory :permission, traits: [:owner], factory_args: -> { { project_id: project.id } }

  for_lists_expects do |user, _action|
    case user
    when :admin, :owner
      project.permissions
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything, and_cannot_do: nothing

  # permissions to change the permission for the project, only owners can do it
  the_users :writer, :reader, :no_access, :harvester,
    can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: [:new], and_cannot_do: everything_but_new, fails_with: :unauthorized
  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized

  #the_users :anonymous, :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
