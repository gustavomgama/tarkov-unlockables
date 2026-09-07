require "rake"

namespace :tasks do
  desc "Sync task chains from officialwiki/tasks.wiki to populate PreviousTask and LeadsTo FKs"
  task sync_task_chains_from_wiki: :environment do
    wiki_path = Rails.root.join("offlinedata/officialwiki/tasks.wiki")
    wiki_content = File.read(wiki_path)

    name_to_task = Task.all.index_by { |t| t.full_name.downcase }

    def slugify(name)
      name.strip.downcase.gsub(" ", "-").gsub(/[^a-z0-9\-]/, "")
    end

    def extract_wikilinks(text)
      return [] unless text
      text.scan(/\[\[([^\]]+)\]\]/).flatten.map(&:strip)
    end

    stats = { processed: 0, leads_to_created: 0, previous_created: 0, not_found: [] }

    current_task_name = nil
    current_task = nil
    current_req = nil

    wiki_content.each_line do |line|
      line = line.rstrip

      if line.start_with?("= ") && line.end_with?(" =")
        current_task_name = line[2..-3].strip
        current_task = name_to_task[current_task_name.downcase]

        if current_task
          current_req = current_task.requirements.first_or_create
          stats[:processed] += 1
        else
          stats[:not_found] << current_task_name if current_task_name
          current_task = nil
          current_req = nil
        end

      elsif current_task
        if line.start_with?(" previous     = ")
          value = line.sub(" previous     = ", "")
          previous_names = extract_wikilinks(value)

          previous_names.each do |pt_name|
            pt_name_clean = pt_name.sub(/\AFail /i, "").strip

            prev_task = name_to_task[pt_name_clean.downcase] || Task.find_by(name: slugify(pt_name_clean))

            existing = PreviousTask.find_by(requirement_id: current_req.id, task_name: pt_name)
            unless existing
              PreviousTask.create!(
                requirement_id: current_req.id,
                task_id: prev_task&.id,
                task_name: pt_name
              )
              stats[:previous_created] += 1
            end
          end

        elsif line.start_with?(" leads to     = ")
          value = line.sub(" leads to     = ", "")
          leads_to_names = extract_wikilinks(value).map { |n| n.sub(/\(\+24hr\)\z/, "").strip }

          leads_to_names.each do |lt_name|
            lt_name_clean = lt_name.sub(/\(\+24hr\)\z/, "").strip

            follow_task = name_to_task[lt_name_clean.downcase] || Task.find_by(name: slugify(lt_name_clean))

            existing = LeadsTo.find_by(task_id: current_task.id, follow_up_task_name: lt_name)
            unless existing
              LeadsTo.create!(
                task_id: current_task.id,
                follow_up_task_id: follow_task&.id,
                follow_up_task_name: lt_name
              )
              stats[:leads_to_created] += 1
            end
          end
        end
      end
    end

    puts "\n=== Task Chain Sync Results ==="
    puts "Tasks processed: #{stats[:processed]}"
    puts "PreviousTask records created: #{stats[:previous_created]}"
    puts "LeadsTo records created: #{stats[:leads_to_created]}"
    puts "Tasks not found in DB: #{stats[:not_found].count}"

    if stats[:not_found].any?
      puts "\nTasks not found (first 20):"
      stats[:not_found].first(20).each { |n| puts "  - #{n}" }
    end

    puts "\nDone!"
  end
end
