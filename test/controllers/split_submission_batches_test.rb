require 'test_helper'
require 'submissions_controller'

class SplitSubmissionBatchesTest < ActionController::TestCase
  context 'when I have a submission' do
    setup do
      @user = FactoryBot.create :user
      @controller = SubmissionsController.new
      @request    = ActionController::TestRequest.create(@controller)
      @plate_purpose = PlatePurpose.find_by(name: 'Stock plate')
      @controller.stubs(:logged_in?).returns(@user)
      session[:user] = @user.id
      @project = FactoryBot.create :project
      @study = FactoryBot.create :study
      @asset1 = FactoryBot.create :sample_tube
      @asset2 = FactoryBot.create :sample_tube
      @asset3 = FactoryBot.create :sample_tube
      @asset4 = FactoryBot.create :sample_tube
      @asset_group = FactoryBot.create :asset_group
      @asset_group.assets << @asset1 << @asset2 << @asset3 << @asset4
      @sequencing_pipeline = Pipeline.find_by(name: 'Cluster formation SE')
    end

    context 'which is single plexed' do
      setup do
        # We're using the submissions controller as things are a bit screwy if we go to the plate creator (PlateCreater) directly
        # However, as this seems to relate to the multiplier, it may be related to out problem.
        submission_template_hash = { name: 'Illumina-C - Library creation - Single ended sequencing',
                                     submission_class_name: 'LinearSubmission',
                                     product_catalogue: 'Generic',
                                     submission_parameters: { info_differential: 5,
                                                              request_types: %w[illumina_c_library_creation
                                                                                illumina_c_single_ended_sequencing] } }

        @submission_template = SubmissionSerializer.construct!(submission_template_hash)

        post(:create, params: {
               submission: {
                 is_a_sequencing_order: 'true',
                 comments: '',
                 template_id: @submission_template.id,
                 order_params: {
                   'read_length' => '37',
                   'fragment_size_required_to' => '400',
                   'bait_library_name' => 'Human all exon 50MB',
                   'fragment_size_required_from' => '100',
                   'library_type' => 'Agilent Pulldown'
                 },
                 asset_group_id: @asset_group.id,
                 study_id: @study.id,
                 sample_names_text: '',
                 plate_purpose_id: @plate_purpose.id,
                 project_name: @project.name,
                 lanes_of_sequencing_required: '5',
                 priority: 1
               }
             })

        Submission.last.built!
        Submission.last.build_batch
      end

      context 'and I batch up the library creation requests seperately' do
        setup do
          @requests_group_a = LibraryCreationRequest.all[0..1]
          @requests_group_b = LibraryCreationRequest.all[2..3]
          @pipeline = LibraryCreationRequest.first.request_type.pipelines.first
          @batch_a = Batch.create!(requests: @requests_group_a, pipeline: @pipeline)
          @batch_a.start!(user: @user)
          @batch_a.complete!(@user)
          @batch_a.release!(@user)
        end

        should 'before failing any sequencing requests' do
          assert_equal LibraryCreationRequest.first.id + 4, LibraryCreationRequest.first.next_requests.first.id
          assert_equal LibraryCreationRequest.all[2].id + 12, LibraryCreationRequest.all[2].next_requests.first.id
        end
      end
    end

    context 'which is multiplexed' do
      setup do
        # We're using the submissions controller as things are a bit screwy if we go to the plate creator (PlateCreater) directly
        # However, as this seems to relate to the multiplier, it may be related to out problem.
        # @asset_group.assets.each_with_index {|a,i| tag=FactoryBot.create :tag; a.aliquots.first.update!(:tag=>tag)}
        submission_template_hash = { name: 'Illumina-C - Multiplexed Library Creation - Single ended sequencing',
                                     submission_class_name: 'LinearSubmission',
                                     product_catalogue: 'Generic',
                                     submission_parameters: { info_differential: 5,
                                                              request_types: %w[illumina_c_multiplexed_library_creation
                                                                                illumina_c_single_ended_sequencing] } }

        @submission_template = SubmissionSerializer.construct!(submission_template_hash)
        @library_pipeline = Pipeline.find_by!(name: 'Illumina-B MX Library Preparation')

        post(:create, params: { submission: {
               is_a_sequencing_order: 'true',
               comments: '',
               template_id: @submission_template.id.to_s,
               order_params: {
                 'read_length' => '37', 'fragment_size_required_to' => '400', 'bait_library_name' => 'Human all exon 50MB',
                 'fragment_size_required_from' => '100', 'library_type' => 'Standard'
               },
               asset_group_id: @asset_group.id.to_s,
               study_id: @study.id.to_s,
               sample_names_text: '',
               plate_purpose_id: @plate_purpose.id.to_s,
               project_name: @project.name,
               lanes_of_sequencing_required: '5',
               priority: 1
             } })

        Submission.last.built!
        Delayed::Worker.new.work_off
      end

      should 'report correct groupings from the start' do
        assert_equal MultiplexedLibraryCreationRequest.first.id + 4, MultiplexedLibraryCreationRequest.first.next_requests.first.id
        assert_equal MultiplexedLibraryCreationRequest.first.id + 4, MultiplexedLibraryCreationRequest.all[2].next_requests.first.id
        assert_equal 5, MultiplexedLibraryCreationRequest.first.next_requests.size
        assert_equal MultiplexedLibraryCreationRequest.first.id + 8, MultiplexedLibraryCreationRequest.first.next_requests.last.id
      end
    end
  end
end
