
Transform /^the plate purpose "([^\"]+)"$/ do |name|
  PlatePurpose.find_by_name(name) or raise StandardError, "Cannot find plate purpose #{name.inspect}"
end

Transform /^the purpose "([^\"]+)"$/ do |name|
  Purpose.find_by_name(name) or raise StandardError, "Cannot find purpose #{name.inspect}"
end

Given /^(the plate purpose "[^"]+") is a parent of (the plate purpose "[^"]+")$/ do |parent, child|
  parent.child_relationships.create!(:child => child, :transfer_request_type => RequestType.transfer)
end

Given /^(the purpose "[^"]+") is a parent of (the purpose "[^"]+")$/ do |parent, child|
  parent.child_relationships.create!(:child => child, :transfer_request_type => RequestType.transfer)
end

When /^"(.*?)" plate purpose picks with "(.*?)"$/ do |name, filter|
  purpose = PlatePurpose.find_by_name(name)
  purpose.cherrypick_filters << filter unless purpose.cherrypick_filters.include?(filter)
  purpose.save!
end
