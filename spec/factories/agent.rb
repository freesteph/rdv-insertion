FactoryBot.define do
  factory :agent do
    sequence(:email) { |n| "johndoe#{n}@example.com" }
    department { create(:department) }
  end
end
