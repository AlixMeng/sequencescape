class AssignTagsTask < Task
  def included_for_render_task
    [{ requests: [{ asset: [:asset_groups, { primary_aliquot: :sample }] }, :target_asset, :batch_request] }, :pipeline]
  end

  class AssignTagsData < Task::RenderElement
    alias_attribute :well, :asset
    def initialize(request)
      super(request)
    end
  end

  def create_render_element(request)
    request.asset && AssignTagsData.new(request)
  end

  def partial
    'assign_tags_batches'
  end

  def render_task(workflow, params)
    super
    workflow.render_assign_tags_task(self, params)
  end

  def do_task(workflow, params)
    workflow.do_assign_tags_task(self, params)
  end
end
