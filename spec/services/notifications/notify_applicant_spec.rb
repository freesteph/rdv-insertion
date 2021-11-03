class TestService < Notifications::NotifyApplicant
  def content
    "test"
  end
end

describe Notifications::NotifyApplicant, type: :service do
  subject do
    TestService.call(
      applicant: applicant, rdv_solidarites_rdv: rdv_solidarites_rdv, department: department
    )
  end

  let!(:phone_number) { "+33782605941" }
  let!(:rdv_solidarites_rdv) do
    OpenStruct.new(id: rdv_solidarites_rdv_id)
  end
  let!(:department) { create(:department) }
  let!(:rdv_solidarites_rdv_id) { 23 }
  let!(:applicant) { create(:applicant, phone_number_formatted: phone_number, departments: [department]) }
  let!(:notification) { create(:notification, applicant: applicant) }

  describe "#call" do
    before do
      allow(Notification).to receive(:find_or_initialize_by).and_return(notification)
      allow(notification).to receive(:save).and_return(true)
      allow(SendTransactionalSms).to receive(:call).and_return(OpenStruct.new(success?: true))
      allow(notification).to receive(:update).and_return(true)
    end

    context "when the phone number is missing" do
      let!(:applicant) { create(:applicant, departments: [department], phone_number_formatted: "") }

      it("is a failure") { is_a_failure }

      it "stores the errors message" do
        expect(subject.errors).to eq(["le téléphone n'est pas renseigné"])
      end
    end

    it "creates a notification" do
      expect(Notification).to receive(:find_or_initialize_by)
        .with(event: "test_service", applicant: applicant, rdv_solidarites_rdv_id: rdv_solidarites_rdv_id)
      expect(notification).to receive(:save)
      subject
    end

    it "sends the sms" do
      expect(SendTransactionalSms).to receive(:call)
        .with(phone_number: phone_number, content: "test")
      subject
    end

    it "updates the notification" do
      expect(notification).to receive(:update)
      subject
    end

    context "when the applicants does not belong to the organisation" do
      let!(:another_department) { create(:department) }
      let!(:applicant) { create(:applicant, departments: [another_department]) }

      it("is a failure") { is_a_failure }

      it "stores the error message" do
        expect(subject.errors).to eq(["l'allocataire ne peut être invité car il n'appartient pas à l'organisation."])
      end
    end

    context "when the notification cannot be saved" do
      before do
        allow(notification).to receive(:save).and_return(false)
        allow(notification).to receive_message_chain(:errors, :full_messages, :to_sentence)
          .and_return("some error")
      end

      it "does not send the sms" do
        expect(SendTransactionalSms).not_to receive(:call)
      end

      it("is a failure") { is_a_failure }

      it "stores the error message" do
        expect(subject.errors).to eq(["some error"])
      end
    end

    context "when the sms service fails" do
      before do
        allow(SendTransactionalSms).to receive(:call)
          .and_return(OpenStruct.new(success?: false, errors: ["bad request"]))
      end

      it("is a failure") { is_a_failure }

      it "stores the error message" do
        expect(subject.errors).to eq(["bad request"])
      end

      it "does not update the notification" do
        expect(notification).not_to receive(:update)
        subject
      end
    end

    context "when the notification cannot be updated" do
      before do
        allow(notification).to receive(:update)
          .and_return(false)
        allow(notification).to receive_message_chain(:errors, :full_messages, :to_sentence)
          .and_return("some error")
      end

      it("is a failure") { is_a_failure }

      it "stores the error message" do
        expect(subject.errors).to eq(["some error"])
      end
    end
  end
end
