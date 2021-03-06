require 'spec_helper'
require 'coworkers/interactors/coworker_adder'
require 'coworkers/entities/member'
require 'coworkers/entities/company'
require 'coworkers/helpers/coworker_params'

module Coworkers
  describe CoworkerAdder do
    let(:member_repo) { Repository.for(:member) }
    let(:company_repo) { Repository.for(:company) }
    let(:default_space) { ::Spaces::Space.new id: 1, name: "Factory" }

    after :each do
      member_repo.clear
      company_repo.clear
    end

    context "#add" do
      it "associates the coworkers with the space" do
        adder = default_coworker_adder

        adder.add

        member = member_repo.last
        expect(member.space_id).to eq default_space.id
        expect(company_repo.find_by_id(member.company_id).space_id).to eq default_space.id
      end

      context "invalid member" do
        it "does not save the member" do
          adder = default_coworker_adder member_params: { name: "Mr. Invalid" }

          expect {
            adder.add
          }.not_to change{member_repo.all.size}
        end

        it "does not save the company" do
          adder = default_coworker_adder member_params: { name: "Mr. Invalid" }

          expect {
            adder.add
          }.not_to change{company_repo.all.size}
        end
      end

      context "the company does not exist" do
        it "creates a member" do
          adder = default_coworker_adder

          expect {
            adder.add
          }.to change{member_repo.all.size}.by(1)
        end

        it "creates the company" do
          adder = default_coworker_adder

          expect {
            adder.add
          }.to change{company_repo.all.size}.by(1)
        end

        it "associates the company with the member" do
          company_params = { name: "GB" }
          adder = default_coworker_adder company_params: company_params

          adder.add

          new_company = company_repo.find_by_id(member_repo.last.company_id)
          expect(new_company.name).to eq company_params[:name]
        end

        it "sets the member as the boss" do
          adder = default_coworker_adder

          adder.add

          member_repo.first.should be_boss
        end
      end

      context "the company exists" do
        it "does not create the company" do
          company = company_repo.save Company.new(name: "Group Buddies", space_id: default_space.id)
          adder = default_coworker_adder company_params: { name: company.name, space_id: default_space.id }

          expect {
            adder.add
          }.not_to change{company_repo.all.size}
        end

        it "creates a member" do
          company = company_repo.save Company.new(name: "Group Buddies", space_id: default_space.id)
          adder = default_coworker_adder company_params: { name: company.name, space_id: default_space.id }

          expect {
            adder.add
          }.to change{member_repo.all.size}.by(1)
        end

        it "associates the company with the member" do
          company = company_repo.save Company.new(name: "Group Buddies", space_id: default_space.id)
          adder = default_coworker_adder company_params: { name: company.name, space_id: default_space.id }

          adder.add

          last_member_company = company_repo.find_by_id(member_repo.last.company_id)
          expect(last_member_company.name).to eq company.name
        end

        it "does not set a new boss" do
          company = company_repo.save Company.new(name: "Group Buddies", space_id: default_space.id)
          adder = default_coworker_adder company_params: { name: company.name, space_id: default_space.id }

          adder.add

          expect(member_repo.last).not_to be_boss
        end
      end

      context "a company with the same name exists in another space" do
        it "creates a new company" do
          other_space = ::Spaces::Space.new id: 2, name: "Cowork X"
          company = Company.new name: "Random name", space_id: other_space.id
          company_repo.save company
          adder = default_coworker_adder company_params: { name: company.name, space_id: default_space }

          expect{
            adder.add
          }.to change{company_repo.all.size}.by(1)
        end
      end
    end

    private

    def default_coworker_adder(member_params: nil, company_params: nil)
      member_params ||= { name: "John", phone_no: "1234", email: "random@example.com" }
      company_params ||= { name: "GB" }
      params = CoworkerParams.new(member: member_params, company: company_params)
      CoworkerAdder.new params: params, space: default_space
    end
  end
end
