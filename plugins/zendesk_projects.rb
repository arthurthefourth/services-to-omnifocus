#
# Create OmniFocus *projects* for tickets assigned to you in Zendesk.
# When tickets change in Zendesk, those changes are reflected in OmniFocus. Changes
# to tasks in OmniFocus are *not* synced back to Zendesk at this point.
#
# This plugin works with Omnifocus 1. Not tested with Omnifocus 2.
# Code is mostly from zendesk.rb with a few tweaks to make it project-specific.
#
# Authentication data is taken from these environment variables:
#
#   ZENDESK_HOST: Contains the name of the virtual host of your Zendesk account
#   ZENDESK_USER: Contains the username (typically an email address) of your Zendesk user
#   ZENDESK_PASS: Contains your Zendesk password
#
# Additionally, the script needs the ID of a view in Zendesk that contains all of your tickets
# in every state (new, open, pending, on-hold, solved, closed) in the variable ZENDESK_VIEW.

require "zendesk_api"

ZENDESK_VIEW_ID = ENV['ZENDESK_VIEW']
ZENDESK_BASE_URI = ENV['ZENDESK_HOST']

@zendesk = ZendeskAPI::Client.new do |config|
  config.url = File.join(ENV['ZENDESK_HOST'], '/api/v2')
  config.username = ENV['ZENDESK_USER']
  config.password = ENV['ZENDESK_PASS']
end

folder = $omnifocus.flattened_folders["Zendesk"].get

def ticket_name(row)
  if row.organization_id
    organization = @zendesk.organization.find(:id => row.organization.id)
  end
  "#{organization ? organization.name + ': ' : ''}#{row.subject} (##{row.ticket.id}):"
end


def set_project_status(project, row)
  case row.ticket.status.downcase
  when 'open' then
    if project.status && project.status.get == :on_hold
      puts "Setting Project ##{row.ticket.id} as Active"
      project.status.set :active
    end
  when 'solved', 'closed' then
    unless project.completed.get
      puts "Completing Project ##{row.ticket.id} in OmniFocus"
      project.completed.set true
    end
  when 'pending', 'hold' then
    unless project.status.get == :on_hold
      puts "Marking Project ##{row.ticket.id} as On Hold"
      project.status.set :on_hold
    end
  end
end


@zendesk.views.find(:id => ZENDESK_VIEW_ID).rows.each do |row|
  project = folder.projects[its.name.contains(row.ticket.id)].first.get rescue nil

  unless project
    puts "Adding Project ##{row.ticket.id}"
    project = folder.make :new => :project, :with_properties => {
      :name => ticket_name(row),
      :note => ZENDESK_BASE_URI + '/tickets/' + row.ticket.id.to_s
    }
  end

  set_project_status(project, row)
end
