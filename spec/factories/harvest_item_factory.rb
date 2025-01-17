# frozen_string_literal: true

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (uploader_id => users.id)
#
FactoryBot.define do
  factory :harvest_item do
    path { 'some/relative/path.mp3' }
    info { {} }
    status { :new }

    audio_recording
    uploader
  end
end
