#This file is part of SEQUENCESCAPE is distributed under the terms of GNU General Public License version 1 or later;
#Please refer to the LICENSE and README files for information on licensing and authorship of this file.
#Copyright (C) 2014 Genome Research Ltd.
class ::Endpoints::ReferenceGenomes < ::Core::Endpoint::Base
  model do
    action(:create, :to => :standard_create!)
  end

  instance do
    action(:update, :to => :standard_update!)
  end
end
