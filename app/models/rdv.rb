class Rdv < ApplicationRecord
  SHARED_ATTRIBUTES_WITH_RDV_SOLIDARITES = (
    RdvSolidarites::Rdv::RECORD_ATTRIBUTES - [:id]
  ).freeze

  PENDING_STATUSES = %w[unknown waiting].freeze
  CANCELLED_STATUSES = %w[excused revoked noshow].freeze
  RDV_SOLIDARITES_CLASS_NAME = "Rdv".freeze

  belongs_to :organisation

  has_and_belongs_to_many :applicants
  after_commit :refresh_applicant_statuses, on: [:create, :update]

  enum created_by: { agent: 0, user: 1, file_attente: 2 }, _prefix: :created_by
  enum status: { unknown: 0, waiting: 1, seen: 2, excused: 3, revoked: 4, noshow: 5 }
  validates :applicants, :rdv_solidarites_motif_id, :starts_at, :duration_in_min, presence: true
  validates :rdv_solidarites_rdv_id, uniqueness: true, presence: true

  def pending?
    in_the_future? && status.in?(PENDING_STATUSES)
  end

  def in_the_future?
    starts_at > Time.zone.now
  end

  def cancelled?
    status.in?(CANCELLED_STATUSES)
  end

  private

  def refresh_applicant_statuses
    RefreshApplicantStatusesJob.perform_async(applicant_ids)
  end
end
