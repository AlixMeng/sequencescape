require "test_helper"

class RequestTest < ActiveSupport::TestCase
  include AASM
  context "A Request" do
    should_belong_to :user, :request_type, :item
    should_have_many :events
    should_have_instance_methods :pending?, :start, :started?, :fail, :failed?, :pass, :passed?, :reset, :workflow_id

    context "#next_request" do
      setup do
        @sample = Factory :sample

        @genotyping_request_type = Factory :request_type, :name => "genotyping"
        @cherrypick_request_type = Factory :request_type, :name => "cherrypick", :target_asset_type => nil
        @submission  = Factory::submission(:request_types => [@cherrypick_request_type, @genotyping_request_type].map(&:id), :asset_group_name => 'to avoid asset errors')
        @item = Factory :item, :submission => @submission

        @genotype_pipeline = Factory :pipeline, :name =>"genotyping pipeline", :request_types => [ @genotyping_request_type ]
        @cherrypick_pipeline = Factory :pipeline, :name => "cherrypick pipeline", :request_types => [ @cherrypick_request_type ], :next_pipeline_id => @genotype_pipeline.id, :asset_type => 'LibraryTube'

        @request1 = Factory(
          :request_without_assets,
          :item         => @item,
          :asset        => Factory(:empty_sample_tube).tap { |sample_tube| sample_tube.aliquots.create!(:sample => @sample) },
          :target_asset => nil,
          :submission   => @submission,
          :request_type => @cherrypick_request_type,
          :pipeline     => @cherrypick_pipeline
        )
      end
      context "with valid input" do
        setup do
          @request2 = Factory :request, :item => @item, :submission => @submission, :request_type => @genotyping_request_type, :pipeline => @genotype_pipeline
        end
        should "return the correct next request" do
          assert_equal [@request2], @request1.next_requests(@cherrypick_pipeline)
        end
      end

      context "where asset hasnt been created for second request" do
        setup do
          @request2 = Factory :request, :asset => nil, :item => @item, :submission => @submission,:request_type => @genotyping_request_type, :pipeline => @genotype_pipeline
        end
        should "return the correct next request" do
          assert_equal [@request2], @request1.next_requests(@cherrypick_pipeline)
        end
      end

      context "#associate_pending_requests_for_downstream_pipeline" do
        setup do
          @request2 = Factory :request_without_assets, :asset => nil, :item => @item, :submission => @submission, :request_type => @genotyping_request_type, :pipeline => @genotype_pipeline
          @request3 = Factory :request_without_assets, :asset => nil, :item => @item, :submission => @submission, :request_type => @genotyping_request_type, :pipeline => @genotype_pipeline

          @batch = @cherrypick_pipeline.batches.create!(:requests => [ @request1 ])

          @request1.reload
          @request2.reload
        end
        should "set the target asset of request 1 to be the asset of request 2" do
          assert_equal @request1.target_asset, @request2.asset
        end
      end

    end

    context "#copy" do
       setup do
         @study = Factory :study
         @workflow = Factory :submission_workflow
         @request_type = Factory :request_type
         @item         = Factory :item
         @request = Factory :request, :request_type => @request_type, :study => @study, :workflow => @workflow, :item => @item
         @new_request = @request.copy
       end

       should "return same properties" do
         @request.reload
         @new_request.reload
         original_attributes = @request.request_metadata.attributes.merge('id' => nil, 'request_id' => nil, 'updated_at'=>nil)
         copied_attributes   = @new_request.request_metadata.attributes.merge('id' => nil, 'request_id' => nil, 'updated_at'=>nil)
         assert_equal original_attributes, copied_attributes
       end

       should "return same item_id" do
         assert_equal @request.item_id, @new_request.item_id
       end

       should "remove target_asset" do
         assert_equal @new_request.target_asset_id, nil
       end

       should "be pending" do
         assert @new_request.pending?
       end
     end

    context "#workflow" do
      setup do
        @study = Factory :study
        @workflow = Factory :submission_workflow
        @request_type = Factory :request_type
        @item         = Factory :item
        @request = Factory :request, :request_type => @request_type, :study => @study, :workflow => @workflow, :item => @item
      end

      should "return a workflow id on request" do
        assert_kind_of Integer, @request.workflow_id
      end

      should "return a valid value if workflow exists" do
        assert_equal @workflow.id, @request.workflow_id
      end

    end

    context "#after_create" do
      context "successful" do
        setup do
          @workflow = Factory :submission_workflow
          @study = Factory :study
          # Create a new request
          assert_nothing_raised do
            @request = Factory :request, :study => @study
          end
        end

        should "not have ActiveRecord errors" do
          assert_equal 0, @request.errors.size
        end

        should "have request as valid" do
          assert_valid @request
        end
      end

      context "failure" do
        setup do
          @workflow = Factory :submission_workflow
          @user = Factory :user
          @study = Factory :study
        end

        should "not return an AR error" do
          assert_nothing_raised do
            @request = Factory :request, :study => @study
          end
        end

        should "fail to create a new request" do
          begin
            @requests = Request.all
            @request = Factory :request, :study => @study
          rescue
            assert_equal @requests, Request.all
          end
        end

      end
    end


    context "#state" do
      setup do
        @study = Factory :study
        @item  = Factory :item
        @request = Factory :request_suitable_for_starting, :study => @study, :item => @item
        @user = Factory :admin
        @user.has_role 'owner', @study
      end

      context "when a new request is created" do
        should "return the default state 'pending'" do
          assert_equal "pending", @request.state
        end
      end

      context "when started" do
        setup do
          @request.start!
        end

        should "return 'Started'" do
          assert_equal "started", @request.state
        end

        should 'not be pending' do
          assert_equal false, @request.pending?
        end

        should 'not be passed' do
          assert_equal false, @request.passed?
        end

        should 'not be failed' do
          assert_equal false, @request.failed?
        end

        should 'be started' do
          assert @request.started?
        end

        context 'allow transition' do
          should 'to pass' do
            @request.state = 'started'
            @request.pass!
          end

          should 'to fail' do
            @request.state = 'started'
            @request.fail!
          end

        end
      end

      context "when passed" do
        setup do
          @request.state = "started"
          @request.pass!
        end

        should "return status of 'passed'" do
          assert_equal "passed", @request.state
        end

        should "not be pending" do
          assert_equal false, @request.pending?
        end

        should "not be failed" do
          assert_equal false, @request.failed?
        end

        should "not be started" do
          assert_equal false, @request.started?
        end

        should "be passed" do
          assert @request.passed?
        end

        context "do not allow the transition" do
          setup do
            @request.state = "passed"
          end

          should "to started" do
            # At least we'll know when and where it's blowing up.
            assert_raise(AASM::InvalidTransition) { @request.start! }
          end
        end
      end

      context "when failed" do
        setup do
          @request.state = "started"
          @request.fail!
        end

        should "return status of 'failed'" do
          assert_equal "failed", @request.state
        end

        should "not be pending" do
          assert_equal false, @request.pending?
        end

        should "not be passed" do
          assert_equal false, @request.passed?
        end

        should "not be started" do
          assert_equal false, @request.started?
        end

        should "be failed" do
          assert @request.failed?
        end

        should "not allow transition to passed" do
          assert_raise(AASM::InvalidTransition) do
            @request.pass!
          end
          assert_nothing_raised do
            @request.change_decision!
          end
        end
      end

    end

    context "#open and #closed" do
      setup do

        @open_states = ["pending", "started"]
        @closed_states = ["passed", "failed", "cancelled", "aborted"]

        @all_states = @open_states + @closed_states

        assert_equal 6, @all_states.size

        @all_states.each do |state|
          Factory :request, :state => state
        end

        assert_equal 6, Request.count
      end
      context "open requests" do
        should "total right number" do
          assert_equal @open_states.size, Request.open.count
        end
      end
      context "closed requests" do
        should "total right number" do
          assert_equal @closed_states.size, Request.closed.count
        end
      end
    end
    
    context "#ready?" do
      setup do
        @library_creation_request = Factory(:library_creation_request_for_testing)
        @library_creation_request.asset.aliquots.each { |a| a.update_attributes!(:project => Factory(:project)) }
        @library_tube = @library_creation_request.target_asset
        
        @library_creation_request_2 = Factory(:library_creation_request_for_testing, :target_asset => @library_tube)
        @library_creation_request_2.asset.aliquots.each { |a| a.update_attributes!(:project => Factory(:project)) }
        
        
        # The sequencing request will be created with a 76 read length (Standard sequencing), so the request 
        # type needs to include this value in its read_length validation list (for example, single_ended_sequencing) 
        @request_type = RequestType.find_by_key("single_ended_sequencing")
        
        @sequencing_request = Factory(:sequencing_request, { :asset => @library_tube, :request_type => @request_type })
      end

      should "check any non-sequencing request is always ready" do
        assert_equal true, @library_creation_request.ready?
      end
      
      should "check a sequencing request is not ready if any of the library creation requests is not in a closed status type (passed, failed, aborted, cancelled)" do
        assert_equal false, @sequencing_request.ready?
      end
      
      should "check a sequencing request is ready if at least one library creation request is in passed status while the others are closed" do
        @library_creation_request.start
        @library_creation_request.pass
        @library_creation_request.save!
        
        @library_creation_request_2.start
        @library_creation_request_2.cancel
        @library_creation_request_2.save!

        assert_equal true, @sequencing_request.ready?
      end
      
      should "check a sequencing request is not ready if any of the library creation requests is not closed, although one of them is in passed status" do
        @library_creation_request.start
        @library_creation_request.pass
        @library_creation_request.save!

        assert_equal false, @sequencing_request.ready?     
      end
      
      should "check a sequencing request is not ready if none of the library creation requests are in passed status" do
        @library_creation_request.start
        @library_creation_request.fail
        @library_creation_request.save!
        
        @library_creation_request_2.start
        @library_creation_request_2.cancel
        @library_creation_request_2.save!        

        assert_equal false, @sequencing_request.ready?
      end

    end

    context "#customer_responsible" do

      setup do
        @request = Factory :library_creation_request
        @request.state = 'started'
      end

      should "update when request is started" do
        @request.request_metadata.update_attributes!(:customer_accepts_responsibility=>true)
        assert @request.request_metadata.customer_accepts_responsibility?
      end

      should "not update once a request is failed" do
        @request.fail!
        assert_raise ActiveRecord::RecordInvalid do
          @request.request_metadata.update_attributes!(:customer_accepts_responsibility=>true)
        end
      end

    end
  end
end
