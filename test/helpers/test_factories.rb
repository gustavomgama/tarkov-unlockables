# Shared record factories for tests. Tests state only the values they assert
# on; the required columns (random bsg_id, derived name/short_name) are filled
# in here so the same call shape is not repeated in every test.
module TestFactories
  def create_task(full_name, name = full_name.parameterize, **attrs)
    Task.create!(bsg_id: "#{SecureRandom.hex(6)}", full_name: full_name, name: name, **attrs)
  end

  def create_item(full_name, klass: Item, **attrs)
    klass.create!(
      bsg_id: "#{SecureRandom.hex(6)}",
      full_name: full_name,
      short_name: full_name[0, 2].upcase,
      **attrs
    )
  end
end
